{
  description = "Advanced example with matrix builds and complex workflows";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    github-actions-nix.url = "github:synapdeck/github-actions-nix";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];

      imports = [
        inputs.github-actions-nix.flakeModules.default
      ];

      perSystem = {
        config,
        pkgs,
        ...
      }: {
        githubActions = {
          enable = true;

          workflows = {
            # Matrix build example
            matrix-build = {
              name = "Matrix Build";

              on = {
                push.branches = ["main" "develop"];
                pullRequest = {};
              };

              permissions = {
                contents = "read";
                pull-requests = "write";
              };

              jobs = {
                test = {
                  name = "Test on \${{ matrix.os }} with Node \${{ matrix.node-version }}";
                  runsOn = "\${{ matrix.os }}";

                  strategy = {
                    matrix = {
                      os = ["ubuntu-latest" "macos-latest" "windows-latest"];
                      node-version = ["18" "20" "22"];
                    };
                    failFast = false;
                    maxParallel = 6;
                  };

                  steps = [
                    {
                      uses = "actions/checkout@v4";
                    }
                    {
                      name = "Setup Node.js";
                      uses = "actions/setup-node@v4";
                      with_ = {
                        node-version = "\${{ matrix.node-version }}";
                        cache = "npm";
                      };
                    }
                    {
                      name = "Install dependencies";
                      run = "npm ci";
                    }
                    {
                      name = "Run tests";
                      run = "npm test";
                    }
                  ];
                };
              };
            };

            # Release workflow example
            release = {
              name = "Release";

              on = {
                push.tags = ["v*"];
                workflowDispatch = {
                  inputs = {
                    version = {
                      description = "Version to release";
                      required = true;
                      type = "string";
                    };
                    dry-run = {
                      description = "Perform a dry run";
                      required = false;
                      type = "boolean";
                      default = "false";
                    };
                  };
                };
              };

              permissions = {
                contents = "write";
                packages = "write";
              };

              concurrency = {
                group = "release-\${{ github.ref }}";
                cancelInProgress = false;
              };

              jobs = {
                build = {
                  name = "Build Release Artifacts";
                  runsOn = "ubuntu-latest";

                  outputs = {
                    version = "\${{ steps.get-version.outputs.version }}";
                    artifact-name = "\${{ steps.create-artifact.outputs.name }}";
                  };

                  steps = [
                    {
                      uses = "actions/checkout@v4";
                      with_ = {
                        fetch-depth = 0;
                      };
                    }
                    {
                      id = "get-version";
                      name = "Get version";
                      run = ''
                        if [ -n "''${{ github.event.inputs.version }}" ]; then
                          echo "version=''${{ github.event.inputs.version }}" >> $GITHUB_OUTPUT
                        else
                          echo "version=''${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT
                        fi
                      '';
                    }
                    {
                      name = "Build artifacts";
                      run = "make build";
                      env = {
                        VERSION = "\${{ steps.get-version.outputs.version }}";
                      };
                    }
                    {
                      id = "create-artifact";
                      name = "Upload artifacts";
                      uses = "actions/upload-artifact@v4";
                      with_ = {
                        name = "release-\${{ steps.get-version.outputs.version }}";
                        path = "dist/";
                        retention-days = 5;
                      };
                    }
                  ];
                };

                publish = {
                  name = "Publish Release";
                  runsOn = "ubuntu-latest";
                  needs = "build";

                  if_ = "\${{ github.event.inputs.dry-run != 'true' }}";

                  steps = [
                    {
                      uses = "actions/checkout@v4";
                    }
                    {
                      name = "Download artifacts";
                      uses = "actions/download-artifact@v4";
                      with_ = {
                        name = "\${{ needs.build.outputs.artifact-name }}";
                        path = "dist/";
                      };
                    }
                    {
                      name = "Create GitHub Release";
                      uses = "softprops/action-gh-release@v1";
                      with_ = {
                        tag_name = "v\${{ needs.build.outputs.version }}";
                        files = "dist/*";
                        draft = false;
                        prerelease = false;
                      };
                      env = {
                        GITHUB_TOKEN = "\${{ secrets.GITHUB_TOKEN }}";
                      };
                    }
                  ];
                };
              };
            };

            # Scheduled workflow example
            nightly = {
              name = "Nightly Build";

              on = {
                schedule = [
                  {cron = "0 2 * * *";} # Run at 2 AM UTC daily
                ];
                workflowDispatch = {};
              };

              jobs = {
                build = {
                  name = "Nightly Build";
                  runsOn = "ubuntu-latest";

                  timeoutMinutes = 30;

                  steps = [
                    {
                      uses = "actions/checkout@v4";
                    }
                    {
                      name = "Run nightly build";
                      run = "make nightly";
                      continueOnError = true;
                    }
                    {
                      name = "Notify on failure";
                      if_ = "failure()";
                      run = ''
                        echo "Nightly build failed!"
                        # Add notification logic here
                      '';
                    }
                  ];
                };
              };
            };
          };
        };

        packages.workflows = pkgs.runCommand "copy-workflows" {} ''
          mkdir -p $out/.github/workflows
          cp -r ${config.githubActions.workflowsDir}/* $out/.github/workflows/
        '';
      };
    };
}
