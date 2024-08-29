{ pkgs }:

with pkgs;

mkShell {
  shellHook = ''
    export MIX_ENV=test
    export ENVOY_BIN=${pkgs.envoy}/bin/envoy
    '';
  packages =
    [
      inotify-tools
      beamPackages.hex
      elixir
      envoy
      nixpkgs-fmt
    ];
}
