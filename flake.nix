{
  description = "Nix flake for Zed (prebuilt Linux x86_64)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      overlay = final: prev: {
        zed = final.callPackage ./package.nix {};
      };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ overlay ];
        };
      in
      {
        packages = {
          default = pkgs.zed;
          zed = pkgs.zed;
        };

        apps = {
          default = {
            type = "app";
            program = "${pkgs.zed}/bin/zed";
          };
          zed = {
            type = "app";
            program = "${pkgs.zed}/bin/zed";
          };
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            nixpkgs-fmt
          ];
        };
      }) // {
        overlays.default = overlay;
      };
}
