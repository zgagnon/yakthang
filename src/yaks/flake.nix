{
  description = "Yaks - A non-linear TODO list for humans and robots";

  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, devenv, ... }@inputs:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          # Use pkgsStatic for Linux to get static musl binaries
          buildPkgs = if pkgs.stdenv.isLinux
            then pkgs.pkgsStatic
            else pkgs;

          yx-binary = buildPkgs.rustPlatform.buildRustPackage {
            pname = "yx";
            version = "0.1.0";
            src = ./.;
            cargoLock.lockFile = ./Cargo.lock;

            nativeBuildInputs = [ pkgs.pkg-config ];
            buildInputs = [ buildPkgs.openssl buildPkgs.zlib ]
              ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [ pkgs.libiconv ];

            doCheck = false;
          };
        in
        {
          # Package as zip for installer
          default = pkgs.stdenv.mkDerivation {
            pname = "yaks-release";
            version = "0.1.0";

            # Don't include src - we only need specific files
            dontUnpack = true;

            nativeBuildInputs = [ pkgs.zip ];

            buildPhase = ''
              mkdir -p release-bundle/bin
              mkdir -p release-bundle/completions

              # Copy the Rust binary from rustPlatform build
              cp -L ${yx-binary}/bin/yx release-bundle/bin/yx
              chmod +x release-bundle/bin/yx

              # Copy completions from source tree
              cp -r ${./.}/completions/* release-bundle/completions/

              cd release-bundle
              zip -r ../yx.zip .
              cd ..
            '';

            installPhase = ''
              mkdir -p $out
              cp yx.zip $out/
            '';

            meta = with pkgs.lib; {
              description = "A non-linear TODO list for humans and robots";
              homepage = "https://github.com/mattwynne/yaks";
              license = licenses.mit;
              platforms = platforms.unix;
            };
          };

          # Also expose the binary directly
          yaks-binary = yx-binary;
        });

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = devenv.lib.mkShell {
            inherit inputs pkgs;
            modules = [
              ./devenv.nix
            ];
          };
        });
    };
}
