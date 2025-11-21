{
  description = "Generate GitHub Actions workflows from Nix configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];

      imports = [
        inputs.flake-parts.flakeModules.partitions
      ];

      # Partition development tools to avoid polluting consumers' lockfiles
      partitionedAttrs.devShells = "dev";

      partitions.dev = {
        extraInputsFlake = ./dev;
        module.imports = [
          ./dev/flake-module.nix
        ];
      };

      flake = {
        flakeModules = rec {
          default = githubActions;
          githubActions = ./modules/github-ci.nix;
        };
      };
    };
}
