{ pkgs }:

with pkgs;

mkShell {
  shellHook = ''
    export MIX_ENV=test
    export ENVOY_BIN=envoy
    '';
  packages =
    [
      beamPackages.hex
      elixir
      envoy
      nixpkgs-fmt
    ];
}
