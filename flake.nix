{
  description = "ProxyConf";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nix2container.url = "github:nlewo/nix2container";
    flake-utils.url = "github:numtide/flake-utils";

  };

  outputs =
    inputs@{ self
    , nixpkgs
    , nix2container
    , flake-utils
    }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      inherit (pkgs.lib) optional optionals;
      pkgs = import nixpkgs { inherit system; };

      elixir = pkgs.elixir_1_16;
      beamPackages = pkgs.beam.packagesWith pkgs.beam.interpreters.erlang;
      nix2containerPkgs = nix2container.packages.${system};

      src = ./.;
      version = builtins.readFile ./VERSION;
      pname = "proxyconf";

      mixFodDeps = beamPackages.fetchMixDeps {
        TOP_SRC = src;
        pname = "${pname}-mix-deps";
        inherit src version;
        hash = "sha256-A43S14c86TJurcusrfpsBElAAt2lX8znYWVpnBpiJ/s=";
        # hash = pkgs.lib.fakeHash;
      };

      cldr = pkgs.fetchFromGitHub {
        owner = "elixir-cldr";
        repo = "cldr";
        rev = "v2.37.5";
        sha256 = "sha256-T5Qvuo+xPwpgBsqHNZYnTCA4loToeBn1LKTMsDcCdYs=";
        # sha256 = pkgs.lib.fakeHash;
      };

      pkg = beamPackages.mixRelease {
        TOP_SRC = src;
        inherit pname version elixir src mixFodDeps;

        LOCALES = "${cldr}/priv/cldr";

        postBuild = ''
          ln -sf ${mixFodDeps}/deps deps
        '';

        meta = {
          mainProgram = "proxyconf";
        };
      };

      run_ci = pkgs.writeShellScriptBin "run-ci" ''
        set -euxo pipefail
        export MIX_ENV=test
        mix deps.get
        mix format --check-formatted
        mix compile --warnings-as-errors
        mix test
      '';

      devShell = pkgs.mkShell {
        buildInputs = [
          pkgs.elixir
          pkgs.elixir_ls
          pkgs.envoy
          pkgs.sops
          pkgs.docker-compose
          run_ci
        ] ++ optional pkgs.stdenv.isLinux pkgs.inotify-tools
        ++ optional pkgs.stdenv.isDarwin pkgs.terminal-notifier;
        shellHook = ''
                          export LOCALES="${cldr}/priv/cldr";
          # this allows mix to work on the local directory
              mkdir -p .nix-mix .nix-hex
              export MIX_HOME=$PWD/.nix-mix
              export HEX_HOME=$PWD/.nix-mix
              # make hex from Nixpkgs available
              # `mix local.hex` will install hex into MIX_HOME and should take precedence
              export MIX_PATH="${pkgs.beam.packages.erlang.hex}/lib/erlang/lib/hex/ebin"
              export PATH=$MIX_HOME/bin:$HEX_HOME/bin:$PATH
              mix local.hex --force
              mix local.rebar --force
              export LANG=C.UTF-8
              # keep your shell history in iex
              export ERL_AFLAGS="-kernel shell_history enabled"
              export ENVOY_BIN=${pkgs.envoy}/bin/envoy
        '';

      };

      image = nix2containerPkgs.nix2container.buildImage {
        name = "proxyconf";
        tag = "latest";
        config = {
          entrypoint = [ "${pkg}/bin/${pname}" ];
        };
        copyToRoot = pkgs.buildEnv {
          name = "root";
          paths = [ pkg pkgs.bashInteractive pkgs.coreutils pkgs.inotify-tools ];
          pathsToLink = [ "/bin" ];
        };
      };
    in
    {
      formatter = pkgs.nixpkgs-fmt;
      packages = {
        default = pkg;
        image = image;
        run_ci = run_ci;
      };
      devShells = {
        default = devShell;
      };
    }
    );
}
