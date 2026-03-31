{
  description = "Eyes — break reminder app";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        isLinux = pkgs.stdenv.isLinux;
        isDarwin = pkgs.stdenv.isDarwin;

        linuxBuildInputs = with pkgs; [
          gtk3
          libappindicator-gtk3
          libnotify
          libcanberra
          xorg.libXScrnSaver
          xorg.libX11
          pkg-config
        ];

        darwinBuildInputs = with pkgs; [
          darwin.apple_sdk.frameworks.AppKit
          darwin.apple_sdk.frameworks.CoreGraphics
          darwin.apple_sdk.frameworks.CoreFoundation
          darwin.apple_sdk.frameworks.QuartzCore
          darwin.apple_sdk.frameworks.Foundation
          darwin.apple_sdk.frameworks.CoreAudio
          darwin.apple_sdk.frameworks.IOKit
        ];

      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            zig
          ] ++ (if isLinux then linuxBuildInputs else [])
            ++ (if isDarwin then darwinBuildInputs else []);

          # Help zig find pkg-config paths on Linux
          shellHook = if isLinux then ''
            echo "Eyes dev shell (Linux) — run: zig build"
          '' else ''
            echo "Eyes dev shell (macOS) — run: zig build"
          '';
        };

        packages.default = pkgs.stdenv.mkDerivation {
          pname = "eyes";
          version = "0.1.0";
          src = ./.;

          nativeBuildInputs = [ pkgs.zig pkgs.pkg-config ];
          buildInputs = if isLinux then linuxBuildInputs else darwinBuildInputs;

          buildPhase = ''
            export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d)
            zig build --release=fast
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp zig-out/bin/eyes $out/bin/
          '';
        };
      }
    );
}
