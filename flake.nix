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
          lib,
          ...
        }:
        {
          formatter = pkgs.nixfmt-tree;

          haskellProjects.default = {
            projectRoot = builtins.toString (
              lib.fileset.toSource {
                root = ./.;
                fileset = lib.fileset.unions [
                  ./src
                  ./nattopages.cabal
                ];
              }
            );

            basePackages = pkgs.haskell.packages.ghc910;
            autoWire = [ "packages" ];
            devShell = {
              enable = true;
              hlsCheck.enable = true;

              tools = hp: {
                inherit (pkgs)
                  nixpkgs-fmt
                  vscode-langservers-extracted
                  terser
                  typst
                  ;

                inherit (hp)
                  cabal-fmt
                  fourmolu
                  ;
              };
            };
          };
          packages.default = self'.packages.nattopages;
          devShells.default = pkgs.mkShell {
            inputsFrom = [ config.haskellProjects.default.outputs.devShell ];
            packages = [ self'.packages.default ];
            SSHTARGET = "bat@weirdnatto.in:/var/lib/site/";
            SSHTARGETPORT = 22002;
            FONTCONFIG_FILE =
              with pkgs;
              makeFontsConf {
                fontDirectories = [ libertine ];
              };
          };
        };
    };
}
