{lib, ...}: let
  inherit (lib) mkOption types;
  jobTypes = import ./job.nix {inherit lib;};
  inherit (jobTypes) jobType permissionsType;
  triggerTypes = import ./triggers.nix {inherit lib;};
  inherit (triggerTypes) onType;
in {
  # Workflow type - represents a complete workflow
  workflowType = types.submodule (_: {
    options = {
      name = mkOption {
        type = types.str;
        description = "Workflow name.";
        example = "CI";
      };

      runName = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          The name for workflow runs generated from the workflow.
          Can include expressions and reference github and inputs contexts.
        '';
        example = "Deploy to \${{ inputs.deploy_target }} by @\${{ github.actor }}";
      };

      on = mkOption {
        type =
          types.either
          (types.listOf types.str)
          onType;
        description = ''
          Events that trigger the workflow. Can be a list of event names
          or a detailed configuration object.
        '';
        example = ["push" "pull_request"];
      };

      jobs = mkOption {
        type = types.attrsOf jobType;
        description = ''
          Jobs to run in the workflow. Keys are job IDs.
        '';
      };

      env = mkOption {
        type = types.nullOr (types.attrsOf types.str);
        default = null;
        description = ''
          Environment variables for all jobs in the workflow.
        '';
        example = {
          NODE_ENV = "production";
        };
      };

      permissions = mkOption {
        type = types.nullOr permissionsType;
        default = null;
        description = ''
          Default permissions for all jobs in the workflow.
        '';
      };

      concurrency = mkOption {
        type = types.nullOr (types.either types.str (types.submodule {
          options = {
            group = mkOption {
              type = types.str;
              description = "Concurrency group name.";
            };
            cancelInProgress = mkOption {
              type = types.bool;
              default = false;
              description = "Whether to cancel in-progress runs.";
            };
          };
        }));
        default = null;
        description = ''
          Concurrency control for the workflow.
        '';
      };

      defaults = mkOption {
        type = types.nullOr (types.submodule {
          options = {
            run = mkOption {
              type = types.nullOr (types.submodule {
                options = {
                  shell = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "Default shell for run steps.";
                  };
                  workingDirectory = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "Default working directory.";
                  };
                };
              });
              default = null;
              description = "Default run configuration.";
            };

            job = mkOption {
              type = types.nullOr (types.submodule {
                options = {
                  runsOn = mkOption {
                    type = types.nullOr (types.either types.str (types.listOf types.str));
                    default = null;
                    description = "Default runner for all jobs.";
                    example = "ubuntu-latest";
                  };

                  env = mkOption {
                    type = types.nullOr (types.attrsOf types.str);
                    default = null;
                    description = "Default environment variables for all jobs.";
                    example = {
                      NODE_ENV = "production";
                    };
                  };

                  permissions = mkOption {
                    type = types.nullOr permissionsType;
                    default = null;
                    description = "Default permissions for all jobs.";
                  };

                  timeoutMinutes = mkOption {
                    type = types.nullOr types.int;
                    default = null;
                    description = "Default timeout in minutes for all jobs.";
                    example = 60;
                  };

                  continueOnError = mkOption {
                    type = types.nullOr types.bool;
                    default = null;
                    description = "Default continue-on-error setting for all jobs.";
                  };
                };
              });
              default = null;
              description = "Default job configuration.";
            };
          };
        });
        default = null;
        description = ''
          Default settings for all jobs in the workflow.
        '';
      };
    };
  });
}
