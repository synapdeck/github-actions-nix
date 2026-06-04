{
  description = "Composite action generation example";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    github-actions-nix.url = "github:synapdeck/github-actions-nix";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];

      imports = [inputs.github-actions-nix.flakeModules.default];

      perSystem = {config, ...}: {
        githubActions = {
          enable = true;

          actions = {
            setup-ci = {
              name = "Setup CI";
              description = "Checkout and toolchain setup";
              inputs = {
                node-version = {
                  description = "Node version to install";
                  default = "20";
                };
              };
              outputs = {
                cache-hit = {
                  description = "Whether the cache was hit";
                  value = "\${{ steps.cache.outputs.cache-hit }}";
                };
              };
              runs.steps = [
                {uses = "actions/checkout@v4";}
                {
                  name = "Install Node";
                  uses = "actions/setup-node@v4";
                  with_.node-version = "\${{ inputs.node-version }}";
                }
                {
                  name = "Install deps";
                  id = "cache";
                  run = "npm ci";
                }
              ];
            };
          };
        };

        # Expose the generated files for inspection/build.
        packages.action-files = config.githubActions.actionsDir;
      };
    };
}
