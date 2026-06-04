{inputs, ...}: {
  imports = [
    inputs.files.flakeModules.default
  ];

  perSystem = {
    config,
    system,
    pkgs,
    lib,
    ...
  }: {
    devShells.default = pkgs.mkShell {
      packages = let
        hk = inputs.hk.packages.${system}.hk.overrideAttrs (_old: {
          doCheck = false;
        });
      in
        with pkgs; [
          # Core tools
          yq-go
          hk

          # Nix formatters and linters
          alejandra
          deadnix
          statix

          # GitHub Actions linter
          actionlint

          # Configuration formatters
          pkl

          # Commit message linters
          gitlint
        ];

      shellHook = ''
        # Ensure git hooks are installed (skip in worktrees)
        if [ -d .git ]; then
          if ! output=$(hk install 2>&1); then
            exit_code=$?
            echo "$output" >&2
            exit $exit_code
          fi
        fi
      '';
    };

    # Configure files module to sync generated workflows to .github/workflows/
    files.files =
      lib.mapAttrsToList (name: drv: {
        path_ = ".github/workflows/${name}";
        inherit drv;
      })
      config.githubActions.workflowFiles;

    # Expose the files writer as an app
    apps.write-files = {
      type = "app";
      program = lib.getExe config.files.writer.drv;
      meta.description = "Write generated files to the repository";
    };

    # CI workflow configuration - dogfooding the github-actions-nix module
    githubActions = {
      enable = true;

      workflows = {
        ci = {
          name = "CI";

          on = {
            pullRequest = {};
            workflowDispatch = {};
            push = {
              branches = ["master"];
              tags = ["v[0-9]+.[0-9]+.[0-9]+*"];
            };
          };

          concurrency = {
            group = "\${{ github.workflow }}-\${{ github.event.pull_request.number || github.ref }}";
            cancelInProgress = true;
          };

          jobs = {
            nix-ci = {
              uses = "DeterminateSystems/ci/.github/workflows/workflow.yml@main";
              permissions = {
                id-token = "write";
                contents = "read";
              };
              with_ = {
                # Publish to FlakeHub only on version tags. The reusable workflow
                # publishes whenever `visibility` is non-empty (on the default
                # branch or a tag); leaving it empty on master/PR runs keeps
                # build + check while suppressing rolling releases. Tagged pushes
                # set it to "public" so the tag's SemVer version is published.
                visibility = "\${{ startsWith(github.ref, 'refs/tags/') && 'public' || '' }}";
              };
            };
          };
        };

        flake-checker = {
          name = "Flake Checker";

          on = {
            pullRequest = {};
            workflowDispatch = {};
            push.branches = ["master"];
          };

          jobs = {
            check = {
              runsOn = "warp-ubuntu-latest-arm64-2x";

              permissions = {
                id-token = "write";
                contents = "read";
              };

              steps = [
                {
                  uses = "actions/checkout@v4";
                }
                {
                  uses = "DeterminateSystems/determinate-nix-action@v3";
                }
                {
                  uses = "DeterminateSystems/flakehub-cache-action@main";
                }
                {
                  uses = "DeterminateSystems/flake-checker-action@main";
                }
                {
                  run = "nix flake check";
                }
              ];
            };
          };
        };

        update-flake-lock = {
          name = "Update flake.lock";

          on = {
            workflowDispatch = {};
            schedule = [
              {cron = "0 0 * * 0";} # Weekly on Sunday at midnight
            ];
          };

          permissions = {
            id-token = "write";
            contents = "write";
            pull-requests = "write";
          };

          jobs = {
            update = {
              runsOn = "warp-ubuntu-latest-arm64-2x";

              steps = [
                {
                  uses = "actions/checkout@v4";
                }
                {
                  uses = "DeterminateSystems/determinate-nix-action@v3";
                }
                {
                  id = "update";
                  name = "Update flake.lock";
                  uses = "DeterminateSystems/update-flake-lock@main";
                  with_ = {
                    pr-title = "chore: update flake.lock";
                    pr-labels = "dependencies\nautomated";
                  };
                }
                {
                  name = "Enable automerge";
                  if_ = "steps.update.outputs.pull-request-number != ''";
                  run = "gh pr merge --auto --rebase \${{ steps.update.outputs.pull-request-number }}";
                  env = {
                    GH_TOKEN = "\${{ secrets.GH_TOKEN_FOR_UPDATES }}";
                  };
                }
              ];
            };
          };
        };
      };
    };
  };
}
