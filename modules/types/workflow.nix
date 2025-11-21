{lib, ...}: let
  inherit (lib) mkOption types;
  jobTypes = import ./job.nix {inherit lib;};
  inherit (jobTypes) jobType permissionsType;
in rec {
  # Trigger types
  pushTriggerType = types.submodule {
    options = {
      branches = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Branch patterns to trigger on.";
        example = ["main" "develop"];
      };

      branchesIgnore = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Branch patterns to ignore.";
        example = ["staging"];
      };

      tags = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Tag patterns to trigger on.";
        example = ["v*"];
      };

      tagsIgnore = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Tag patterns to ignore.";
      };

      paths = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "File path patterns to trigger on.";
        example = ["src/**" "package.json"];
      };

      pathsIgnore = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "File path patterns to ignore.";
        example = ["docs/**"];
      };
    };
  };

  pullRequestTriggerType = types.submodule {
    options = {
      branches = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Branch patterns to trigger on.";
        example = ["main"];
      };

      branchesIgnore = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Branch patterns to ignore.";
      };

      paths = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "File path patterns to trigger on.";
      };

      pathsIgnore = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "File path patterns to ignore.";
      };

      types = mkOption {
        type = types.nullOr (types.listOf (types.enum [
          "assigned"
          "unassigned"
          "labeled"
          "unlabeled"
          "opened"
          "edited"
          "closed"
          "reopened"
          "synchronize"
          "converted_to_draft"
          "ready_for_review"
          "locked"
          "unlocked"
          "review_requested"
          "review_request_removed"
          "auto_merge_enabled"
          "auto_merge_disabled"
        ]));
        default = null;
        description = "PR event types to trigger on.";
        example = ["opened" "synchronize"];
      };
    };
  };

  scheduleTriggerType = types.submodule {
    options = {
      cron = mkOption {
        type = types.str;
        description = "Cron expression for schedule.";
        example = "0 0 * * *";
      };
    };
  };

  workflowDispatchType = types.submodule {
    options = {
      inputs = mkOption {
        type = types.nullOr (types.attrsOf (types.submodule {
          options = {
            description = mkOption {
              type = types.str;
              description = "Input description.";
            };
            required = mkOption {
              type = types.bool;
              default = false;
              description = "Whether the input is required.";
            };
            default = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Default value.";
            };
            type = mkOption {
              type = types.nullOr (types.enum ["string" "boolean" "choice" "environment"]);
              default = null;
              description = "Input type.";
            };
            options = mkOption {
              type = types.nullOr (types.listOf types.str);
              default = null;
              description = "Options for choice type.";
            };
          };
        }));
        default = null;
        description = "Workflow dispatch inputs.";
      };
    };
  };

  # Workflow type - represents a complete workflow
  workflowType = types.submodule ({...}: {
    options = {
      name = mkOption {
        type = types.str;
        description = "Workflow name.";
        example = "CI";
      };

      on = mkOption {
        type =
          types.either
          (types.listOf types.str)
          (types.submodule {
            options = {
              push = mkOption {
                type = types.nullOr (types.either pushTriggerType (types.attrsOf types.anything));
                default = null;
                description = "Push trigger configuration.";
              };

              pullRequest = mkOption {
                type = types.nullOr (types.either pullRequestTriggerType (types.attrsOf types.anything));
                default = null;
                description = "Pull request trigger configuration.";
              };

              schedule = mkOption {
                type = types.nullOr (types.listOf scheduleTriggerType);
                default = null;
                description = "Schedule trigger configuration.";
              };

              workflowDispatch = mkOption {
                type = types.nullOr (types.either workflowDispatchType (types.attrsOf types.anything));
                default = null;
                description = "Manual workflow dispatch configuration.";
              };

              workflowCall = mkOption {
                type = types.nullOr (types.attrsOf types.anything);
                default = null;
                description = "Workflow call trigger configuration.";
              };
            };
          });
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
