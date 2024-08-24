{ lib, beamPackages, overrides ? (x: y: { }) }:

let
  buildMix = lib.makeOverridable beamPackages.buildMix;
  buildRebar3 = lib.makeOverridable beamPackages.buildRebar3;

  defaultOverrides = (final: prev:

    let
      apps = { };

      workarounds = { };

      applyOverrides =
        appName: drv:
        let
          allOverridesForApp = builtins.foldl'
            (
              acc: workaround: acc // workarounds.${workaround} drv
            )
            { }
            apps.${appName};

        in
        if builtins.hasAttr appName apps then drv.override allOverridesForApp else drv;

    in
    builtins.mapAttrs applyOverrides prev);

  self = packages // (defaultOverrides self packages) // (overrides self packages);

  packages = with beamPackages; with self; {
    conv_case =
      let
        version = "0.2.3";
      in
      buildMix {
        inherit version;
        name = "conv_case";

        src = fetchHex {
          inherit version;
          pkg = "conv_case";
          sha256 = "88f29a3d97d1742f9865f7e394ed3da011abb7c5e8cc104e676fdef6270d4b4a";
        };
      };

    cowboy =
      let
        version = "2.12.0";
      in
      buildRebar3 {
        inherit version;
        name = "cowboy";

        src = fetchHex {
          inherit version;
          pkg = "cowboy";
          sha256 = "8a7abe6d183372ceb21caa2709bec928ab2b72e18a3911aa1771639bef82651e";
        };

        beamDeps = [ cowlib ranch ];
      };

    cowboy_telemetry =
      let
        version = "0.4.0";
      in
      buildRebar3 {
        inherit version;
        name = "cowboy_telemetry";

        src = fetchHex {
          inherit version;
          pkg = "cowboy_telemetry";
          sha256 = "7d98bac1ee4565d31b62d59f8823dfd8356a169e7fcbb83831b8a5397404c9de";
        };

        beamDeps = [ cowboy telemetry ];
      };

    cowlib =
      let
        version = "2.13.0";
      in
      buildRebar3 {
        inherit version;
        name = "cowlib";

        src = fetchHex {
          inherit version;
          pkg = "cowlib";
          sha256 = "e1e1284dc3fc030a64b1ad0d8382ae7e99da46c3246b815318a4b848873800a4";
        };
      };

    deep_merge =
      let
        version = "1.0.0";
      in
      buildMix {
        inherit version;
        name = "deep_merge";

        src = fetchHex {
          inherit version;
          pkg = "deep_merge";
          sha256 = "ce708e5f094b9cd4e8f2be4f00d2f4250c4095be93f8cd6d018c753894885430";
        };
      };

    envoy_xds =
      let
        version = "f1a248273ad2703790cd5b5e739c17aaaea92ae3";
      in
      buildMix {
        inherit version;
        name = "envoy_xds";

        src = builtins.fetchGit {
          url = "https://github.com/proxyconf/envoy_xds_ex.git";
          rev = "f1a248273ad2703790cd5b5e739c17aaaea92ae3";
          allRefs = true;
        };

        beamDeps = [ grpc protobuf google_protos ];
      };

    file_system =
      let
        version = "1.0.1";
      in
      buildMix {
        inherit version;
        name = "file_system";

        src = fetchHex {
          inherit version;
          pkg = "file_system";
          sha256 = "4414d1f38863ddf9120720cd976fce5bdde8e91d8283353f0e31850fa89feb9e";
        };
      };

    floki =
      let
        version = "0.36.2";
      in
      buildMix {
        inherit version;
        name = "floki";

        src = fetchHex {
          inherit version;
          pkg = "floki";
          sha256 = "a8766c0bc92f074e5cb36c4f9961982eda84c5d2b8e979ca67f5c268ec8ed580";
        };
      };

    google_protos =
      let
        version = "0.4.0";
      in
      buildMix {
        inherit version;
        name = "google_protos";

        src = fetchHex {
          inherit version;
          pkg = "google_protos";
          sha256 = "4c54983d78761a3643e2198adf0f5d40a5a8b08162f3fc91c50faa257f3fa19f";
        };

        beamDeps = [ protobuf ];
      };

    grpc =
      let
        version = "0.8.1";
      in
      buildMix {
        inherit version;
        name = "grpc";

        src = fetchHex {
          inherit version;
          pkg = "grpc";
          sha256 = "1cccd9fd83547a562f315cc0e1ee1879546f0a44193b5c8eb8d68dae0bb2065b";
        };

        beamDeps = [ cowboy cowlib gun jason mint protobuf telemetry ];
      };

    gun =
      let
        version = "2.1.0";
      in
      buildRebar3 {
        inherit version;
        name = "gun";

        src = fetchHex {
          inherit version;
          pkg = "gun";
          sha256 = "52fc7fc246bfc3b00e01aea1c2854c70a366348574ab50c57dfe796d24a0101d";
        };

        beamDeps = [ cowlib ];
      };

    hpax =
      let
        version = "1.0.0";
      in
      buildMix {
        inherit version;
        name = "hpax";

        src = fetchHex {
          inherit version;
          pkg = "hpax";
          sha256 = "7f1314731d711e2ca5fdc7fd361296593fc2542570b3105595bb0bc6d0fad601";
        };
      };

    jason =
      let
        version = "1.4.4";
      in
      buildMix {
        inherit version;
        name = "jason";

        src = fetchHex {
          inherit version;
          pkg = "jason";
          sha256 = "c5eb0cab91f094599f94d55bc63409236a8ec69a21a67814529e8d5f6cc90b3b";
        };
      };

    json_xema =
      let
        version = "0.6.2";
      in
      buildMix {
        inherit version;
        name = "json_xema";

        src = fetchHex {
          inherit version;
          pkg = "json_xema";
          sha256 = "50c84c537c95fcc76677f1f030af4aed188f538820fc488aeaa3f7dfe04d0edf";
        };

        beamDeps = [ conv_case xema ];
      };

    mime =
      let
        version = "2.0.6";
      in
      buildMix {
        inherit version;
        name = "mime";

        src = fetchHex {
          inherit version;
          pkg = "mime";
          sha256 = "c9945363a6b26d747389aac3643f8e0e09d30499a138ad64fe8fd1d13d9b153e";
        };
      };

    mint =
      let
        version = "1.6.2";
      in
      buildMix {
        inherit version;
        name = "mint";

        src = fetchHex {
          inherit version;
          pkg = "mint";
          sha256 = "5ee441dffc1892f1ae59127f74afe8fd82fda6587794278d924e4d90ea3d63f9";
        };

        beamDeps = [ hpax ];
      };

    plug =
      let
        version = "1.16.1";
      in
      buildMix {
        inherit version;
        name = "plug";

        src = fetchHex {
          inherit version;
          pkg = "plug";
          sha256 = "a13ff6b9006b03d7e33874945b2755253841b238c34071ed85b0e86057f8cddc";
        };

        beamDeps = [ mime plug_crypto telemetry ];
      };

    plug_cowboy =
      let
        version = "2.7.1";
      in
      buildMix {
        inherit version;
        name = "plug_cowboy";

        src = fetchHex {
          inherit version;
          pkg = "plug_cowboy";
          sha256 = "02dbd5f9ab571b864ae39418db7811618506256f6d13b4a45037e5fe78dc5de3";
        };

        beamDeps = [ cowboy cowboy_telemetry plug ];
      };

    plug_crypto =
      let
        version = "2.1.0";
      in
      buildMix {
        inherit version;
        name = "plug_crypto";

        src = fetchHex {
          inherit version;
          pkg = "plug_crypto";
          sha256 = "131216a4b030b8f8ce0f26038bc4421ae60e4bb95c5cf5395e1421437824c4fa";
        };
      };

    protobuf =
      let
        version = "0.12.0";
      in
      buildMix {
        inherit version;
        name = "protobuf";

        src = fetchHex {
          inherit version;
          pkg = "protobuf";
          sha256 = "75fa6cbf262062073dd51be44dd0ab940500e18386a6c4e87d5819a58964dc45";
        };

        beamDeps = [ jason ];
      };

    ranch =
      let
        version = "1.8.0";
      in
      buildRebar3 {
        inherit version;
        name = "ranch";

        src = fetchHex {
          inherit version;
          pkg = "ranch";
          sha256 = "49fbcfd3682fab1f5d109351b61257676da1a2fdbe295904176d5e521a2ddfe5";
        };
      };

    telemetry =
      let
        version = "1.3.0";
      in
      buildRebar3 {
        inherit version;
        name = "telemetry";

        src = fetchHex {
          inherit version;
          pkg = "telemetry";
          sha256 = "7015fc8919dbe63764f4b4b87a95b7c0996bd539e0d499be6ec9d7f3875b79e6";
        };
      };

    x509 =
      let
        version = "0.8.9";
      in
      buildMix {
        inherit version;
        name = "x509";

        src = fetchHex {
          inherit version;
          pkg = "x509";
          sha256 = "ea3fb16a870a199cb2c45908a2c3e89cc934f0434173dc0c828136f878f11661";
        };
      };

    xema =
      let
        version = "0.17.4";
      in
      buildMix {
        inherit version;
        name = "xema";

        src = fetchHex {
          inherit version;
          pkg = "xema";
          sha256 = "faf638de7c424326f089475db8077c86506af971537eb2097e06124c5e0e4240";
        };

        beamDeps = [ conv_case ];
      };

    yamerl =
      let
        version = "0.10.0";
      in
      buildRebar3 {
        inherit version;
        name = "yamerl";

        src = fetchHex {
          inherit version;
          pkg = "yamerl";
          sha256 = "346adb2963f1051dc837a2364e4acf6eb7d80097c0f53cbdc3046ec8ec4b4e6e";
        };
      };

    yaml_elixir =
      let
        version = "2.11.0";
      in
      buildMix {
        inherit version;
        name = "yaml_elixir";

        src = fetchHex {
          inherit version;
          pkg = "yaml_elixir";
          sha256 = "53cc28357ee7eb952344995787f4bb8cc3cecbf189652236e9b163e8ce1bc242";
        };

        beamDeps = [ yamerl ];
      };
  };
in
self
