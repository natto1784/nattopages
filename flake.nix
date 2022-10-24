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

          inherit (pkgs.lib.sources) cleanSourceWith cleanSource;

          filterCI = name: type:
            !((type == "directory") && (baseNameOf name == ".woodpecker"));

          cleanSrc = cleanSourceWith {
            filter = filterCI;
            src = cleanSource ./.;
          };

          vars = pkgs.lib.mapAttrsToList (n: v: "export ${n}=${v}") {
            LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";
            LANG = "en_US.UTF-8";
          };

          site = pkgs.haskellPackages.callCabal2nix "nattopages" ./src { };
          nattopages = pkgs.stdenv.mkDerivation {
            name = "nattopages";
            src = cleanSrc;
            phases = "unpackPhase patchPhase buildPhase";
            nativeBuildInputs = [ site ];
            patchPhase =
              let
                cachix = "pain";
              in
              ''
                substituteInPlace templates/default.html \
                  --replace '{+nixstorepath+}' $out \
                  --replace '{+cachix+}' ${cachix}
              '';
            buildPhase = (pkgs.lib.concatStringsSep "\n" vars) + "\n" +
              ''
                site build
                mkdir -p $out
                cp -r _site/* $out
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
