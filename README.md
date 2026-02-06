# zed-nix

This flake provides prebuilt Zed editor releases so you can use newer versions without compiling from source or waiting for nixpkgs. It is intended to track official releases (including nightlies) and package them for Nix and NixOS users.

## Usage

### flake.nix

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    zed-nix.url = "github:mert-kurttutan/zed-nix";
  };

  outputs = { self, nixpkgs, zed-nix }:
    let
      system = "x86_64-linux"; # or your system
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          zed-nix.packages.${system}.default
        ];
      };
    };
}
```

## Attribution

Zed is developed by Zed Industries. Nix and NixOS are part of the Nix ecosystem.

## Contributing

Contributions are welcome. Please review your changes before submitting.

## Development

```
# Clone the repository
git clone https://github.com/mert-kurttutan/zed-nix
cd zed-nix

# Build locally
nix build

# Test the build
./result/bin/zed --version

```
