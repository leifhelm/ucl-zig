{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default =
          with pkgs;
          mkShell {
            name = "dev-shell";
            version = "1.0.0";
            buildInputs = with llvmPackages_21; [
              ucl
              zig
              aflplusplus
              # libubsan
              # libllvm
              # llvm
              pkg-config
            ];
          };
      }
    );
}
