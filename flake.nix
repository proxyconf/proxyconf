{
  description = "ProxyConf";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nix2container.url = "github:nlewo/nix2container";
    flake-utils.url = "github:numtide/flake-utils";
    devenv.url = "github:cachix/devenv";

  };

  outputs =
    { self
    , nixpkgs
    , nix2container
    , flake-utils
    , devenv
    , ...
    } @ inputs:
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
        hash = "sha256-FbkScSYFPn50WW8K0ztHUrRrfksjZPETB7QuWGvL+J8=";
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



        devenvShell = devenv.lib.mkShell {
          inherit inputs pkgs;
          modules = [
            ({ pkgs, config, ...}: {
              packages = [
                pkgs.elixir
                pkgs.elixir_ls
                pkgs.envoy
                pkgs.jq
                pkgs.hurl
                pkgs.docker-compose
                pkgs.python312Packages.mkdocs-material
                pkgs.python312Packages.pillow
                pkgs.python312Packages.cairosvg
                pkgs.python312Packages.mkdocs-rss-plugin
                pkgs.python312Packages.filelock
                run_ci
              ] ++ optional pkgs.stdenv.isLinux pkgs.inotify-tools
                ++ optional pkgs.stdenv.isDarwin pkgs.terminal-notifier;

              process.managers.process-compose = {
                tui.enable = false;
              };

              services.postgres = {
                enable = true;
                package = pkgs.postgresql_16;
                initialDatabases = [{ 
                  name = "proxyconf_dev"; 
                  pass = "postgres"; 
                  user = "postgres";
                }
                { 
                  name = "proxyconf_test"; 
                  pass = "postgres"; 
                  user = "postgres";
                }
                ];
                initialScript = ''
                  CREATE ROLE postgres SUPERUSER;
                '';
              };

              enterShell = ''
                echo "hello from devenv shell"
              '';
              enterTest = ''
                wait_for_port 5432 6u
                run-ci
              '';
            })
          ];

        };


        devShell = pkgs.mkShell {
        buildInputs = [
          pkgs.elixir
          pkgs.elixir_ls
          pkgs.envoy
          pkgs.hurl
          pkgs.docker-compose
          pkgs.python312Packages.mkdocs-material
          pkgs.python312Packages.pillow
          pkgs.python312Packages.cairosvg
          pkgs.python312Packages.mkdocs-rss-plugin
          pkgs.python312Packages.filelock
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
        devenv-up = devenvShell.config.procfileScript;
        devenv-test = devenvShell.config.test;
      };
      devShells = {
        default = devenvShell;
          #default = devShell;
      };
    }
    );
}
