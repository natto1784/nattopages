{
  description = "My personal website";

  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/release-22.05;
    utils.url = github:numtide/flake-utils;
  };

  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };
          
          vars = pkgs.lib.mapAttrsToList (n: v: "export ${n}=${v}") {
            LANG = "en_US.UTF-8";
          };
          
          site = pkgs.haskellPackages.callCabal2nix "nattopages" ./src { };
          nattopages = pkgs.stdenv.mkDerivation {
            name = "nattopages";
            src = ./.;
            phases = "unpackPhase buildPhase";
            nativeBuildInputs = [ site ];
            buildPhase = (pkgs.lib.concatStringsSep "\n" vars ) + ''
              mkdir -p $out
              cp -r \_site/* $out
            '';
          };
        in
        rec {
          devShell = with pkgs.haskellPackages; shellFor {
            packages = _: [ site ];
            withHoogle = true;
            buildInputs = [
              cabal-install
              haskell-language-server
              ghcid
            ];
            nativeBuildInputs = with pkgs; [
              zlib
            ];
          };
          packages = {
            inherit nattopages site;
          };
          defaultPackage = packages.nattopages;
        }
      );
}
