{
  description = "My personal website";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    haskell-flake.url = "github:srid/haskell-flake";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [ inputs.haskell-flake.flakeModule ];

      perSystem =
        {
          self',
          pkgs,
          config,
          ...
        }:
        {
          formatter = pkgs.nixfmt-tree;

          haskellProjects.default = {
            basePackages = pkgs.haskell.packages.ghc910;
            autoWire = [ "packages" ];
            devShell = {
              enable = true;
              hlsCheck.enable = true;

              tools = hp: {
                inherit (pkgs)
                  nixpkgs-fmt
                  vscode-langservers-extracted
                  ;

                inherit (hp)
                  cabal-fmt
                  fourmolu
                  ;

                texlive =
                  with pkgs;
                  texlive.combine {
                    inherit (texlive)
                      scheme-small
                      fontspec
                      enumitem
                      parskip
                      hyperref
                      standalone
                      relsize
                      titlesec
                      ;
                  };
              };
            };
          };
          packages.default = self'.packages.nattopages;
          devShells.default = pkgs.mkShell {
            inputsFrom = [ config.haskellProjects.default.outputs.devShell ];
            packages = [ self'.packages.default ];
          };
        };
    };
}
