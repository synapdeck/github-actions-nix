{
  description = "Example using github-actions-nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    github-actions-nix.url = "github:synapdeck/github-actions-nix";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];

      # Import the github-actions-nix module
      imports = [
        inputs.github-actions-nix.flakeModules.default
      ];

      perSystem = {
        config,
        pkgs,
        ...
      }: {
        # Enable GitHub Actions generation
        githubActions = {
          enable = true;

          workflows = {
            ci = {
              name = "CI";

              on = {
                push.branches = ["main"];
                pullRequest.branches = ["main"];
                workflowDispatch = {};
              };

              # Set defaults for all jobs
              defaults.job = {
                runsOn = "ubuntu-latest";
                timeoutMinutes = 30;
              };

              jobs = {
                build = {
                  name = "Build and Test";
                  # No need to specify runsOn, it uses the default

                  steps = [
                    {
                      name = "Checkout code";
                      uses = "actions/checkout@v4";
                    }
                    {
                      name = "Install Nix";
                      uses = "cachix/install-nix-action@v24";
                      with_ = {
                        nix_path = "nixpkgs=channel:nixos-unstable";
                      };
                    }
                    {
                      name = "Build";
                      run = "nix build";
                    }
                    {
                      name = "Run tests";
                      run = "nix flake check";
                    }
                  ];
                };

                lint = {
                  name = "Lint";
                  # Override the default runner for this specific job
                  runsOn = "macos-latest";

                  steps = [
                    {
                      name = "Checkout code";
                      uses = "actions/checkout@v4";
                    }
                    {
                      name = "Install Nix";
                      uses = "cachix/install-nix-action@v24";
                    }
                    {
                      name = "Check formatting";
                      run = "nix fmt -- --check .";
                    }
                  ];
                };
              };
            };
          };
        };

        # Create a package that copies the workflows to .github/workflows
        packages.workflows = pkgs.runCommand "copy-workflows" {} ''
          mkdir -p $out/.github/workflows
          cp -r ${config.githubActions.workflowsDir}/* $out/.github/workflows/
        '';
      };
    };
}
