{
  description = "My personal website";

  inputs = {
    nixpkgs.follows = "hnix/nixpkgs";
    hnix.url = github:input-output-hk/haskell.nix;
    utils.url = github:numtide/flake-utils;
  };

  outputs = { self, nixpkgs, utils, hnix }:
    utils.lib.eachDefaultSystem
      (system:
        let
          overlays = [
            hnix.overlay
          ];

          pkgs = import nixpkgs {
            inherit system overlays;
            inherit (hnix) config;
          };

          nattopages = pkgs.haskell-nix.hix.project {
            src = ./src;
            compiler-nix-name = "ghc928";
          };

          flake = nattopages.flake { };
        in
        flake // rec {
          packages.default = flake.packages."nattopages:exe:site";
          devShells.default = with pkgs; mkShell {
            buildInputs = with pkgs; [
              cabal-install
              haskellPackages.fourmolu

              (texlive.combine {
                inherit (texlive)
                  scheme-small
                  fontspec
                  enumitem
                  parskip
                  hyperref
                  standalone
                  relsize
                  titlesec;
              })

              packages.default
            ];
            SSHTARGET = "bat@weirdnatto.in:/var/lib/site/";
            SSHTARGETPORT = 22002;
          };
        });
}
