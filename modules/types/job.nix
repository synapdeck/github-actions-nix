{lib, ...}: let
  inherit (lib) mkOption types;
  stepTypes = import ./step.nix {inherit lib;};
  inherit (stepTypes) stepType;
in rec {
  # Strategy type for matrix builds
  strategyType = types.submodule {
    options = {
      matrix = mkOption {
        type = types.nullOr (types.submodule {
          freeformType = types.attrsOf (types.listOf types.anything);
          options = {
            include = mkOption {
              type = types.nullOr (types.listOf (types.attrsOf types.anything));
              default = null;
              description = ''
                Additional matrix configurations to include.
                Each item adds or expands matrix combinations.
              '';
              example = [
                {
                  os = "windows-latest";
                  node = 16;
                  npm = 6;
                }
              ];
            };

            exclude = mkOption {
              type = types.nullOr (types.listOf (types.attrsOf types.anything));
              default = null;
              description = ''
                Matrix configurations to exclude.
                Partial matches will be excluded from the matrix.
              '';
              example = [
                {
                  os = "macos-latest";
                  node = 14;
                }
              ];
            };
          };
        });
        default = null;
        description = ''
          Matrix strategy for running the job with different configurations.
        '';
        example = {
          node-version = ["18" "20"];
          os = ["ubuntu-latest" "windows-latest"];
        };
      };

      failFast = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = ''
          Whether to cancel all in-progress jobs if any matrix job fails.
        '';
      };

      maxParallel = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = ''
          Maximum number of jobs that can run simultaneously when using a matrix.
        '';
      };
    };
  };

  # Permissions type
  permissionsType =
    types.either
    (types.enum ["read-all" "write-all"])
    (types.attrsOf (types.enum ["read" "write" "none"]));

  # Runner selection type (supports group and labels)
  runsOnType =
    types.either
    types.str
    (types.either
      (types.listOf types.str)
      (types.submodule {
        options = {
          group = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Runner group name.";
          };
          labels = mkOption {
            type = types.nullOr (types.either types.str (types.listOf types.str));
            default = null;
            description = "Runner labels.";
          };
        };
      }));

  # Environment type for deployments
  environmentType =
    types.either
    types.str
    (types.submodule {
      options = {
        name = mkOption {
          type = types.str;
          description = "Environment name.";
          example = "production";
        };
        url = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Environment URL (can be an expression).";
          example = "https://github.com";
        };
      };
    });

  # Defaults type for job-level defaults
  jobDefaultsType = types.submodule {
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
    };
  };

  # Container credentials type
  containerCredentialsType = types.submodule {
    options = {
      username = mkOption {
        type = types.str;
        description = "Username for container registry.";
      };
      password = mkOption {
        type = types.str;
        description = "Password for container registry.";
      };
    };
  };

  # Container configuration type
  containerType =
    types.either
    types.str
    (types.submodule {
      options = {
        image = mkOption {
          type = types.str;
          description = "Container image to use.";
          example = "node:18";
        };
        credentials = mkOption {
          type = types.nullOr containerCredentialsType;
          default = null;
          description = "Credentials for private container registry.";
        };
        env = mkOption {
          type = types.nullOr (types.attrsOf types.str);
          default = null;
          description = "Environment variables for the container.";
        };
        ports = mkOption {
          type = types.nullOr (types.listOf (types.either types.int types.str));
          default = null;
          description = "Ports to expose on the container.";
          example = [80 "8080:80"];
        };
        volumes = mkOption {
          type = types.nullOr (types.listOf types.str);
          default = null;
          description = "Volumes for the container to use.";
          example = ["my_docker_volume:/volume_mount" "/data/my_data"];
        };
        options = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Additional Docker container resource options.";
          example = "--cpus 1";
        };
      };
    });

  # Service container type
  serviceContainerType =
    types.either
    types.str
    (types.submodule {
      options = {
        image = mkOption {
          type = types.str;
          description = "Container image to use.";
          example = "redis:latest";
        };
        credentials = mkOption {
          type = types.nullOr containerCredentialsType;
          default = null;
          description = "Credentials for private container registry.";
        };
        env = mkOption {
          type = types.nullOr (types.attrsOf types.str);
          default = null;
          description = "Environment variables for the service container.";
        };
        ports = mkOption {
          type = types.nullOr (types.listOf (types.either types.int types.str));
          default = null;
          description = "Ports to expose on the service container.";
        };
        volumes = mkOption {
          type = types.nullOr (types.listOf types.str);
          default = null;
          description = "Volumes for the service container to use.";
        };
        options = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Additional Docker container resource options.";
        };
      };
    });

  # Job type - represents a job in a workflow
  jobType = types.submodule {
    options = {
      name = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Display name for the job.
        '';
        example = "Build and Test";
      };

      runsOn = mkOption {
        type = types.nullOr runsOnType;
        default = null;
        description = ''
          The type of runner to use. Can be:
          - A single string: "ubuntu-latest"
          - A list: ["self-hosted", "linux"]
          - An object with group/labels: { group = "my-group"; labels = "ubuntu-latest"; }
        '';
        example = "ubuntu-latest";
      };

      needs = mkOption {
        type = types.nullOr (types.either types.str (types.listOf types.str));
        default = null;
        description = ''
          Jobs that must complete successfully before this job runs.
        '';
        example = ["build" "lint"];
      };

      if_ = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Conditional expression to determine if the job should run.
        '';
        example = "github.event_name == 'push'";
      };

      steps = mkOption {
        type = types.listOf stepType;
        default = [];
        description = ''
          List of steps to run in the job.
        '';
      };

      env = mkOption {
        type = types.nullOr (types.attrsOf types.str);
        default = null;
        description = ''
          Environment variables for all steps in the job.
        '';
        example = {
          NODE_ENV = "production";
        };
      };

      strategy = mkOption {
        type = types.nullOr strategyType;
        default = null;
        description = ''
          Strategy for running the job with different configurations.
        '';
      };

      continueOnError = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = ''
          Whether to allow the workflow to continue if this job fails.
        '';
      };

      timeoutMinutes = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = ''
          Maximum time in minutes to run the job before killing it.
        '';
        example = 60;
      };

      permissions = mkOption {
        type = types.nullOr permissionsType;
        default = null;
        description = ''
          Permissions for the GITHUB_TOKEN in this job.
        '';
        example = {
          contents = "read";
          pull-requests = "write";
        };
      };

      outputs = mkOption {
        type = types.nullOr (types.attrsOf types.str);
        default = null;
        description = ''
          Output variables that can be used by dependent jobs.
        '';
        example = {
          version = "\${{ steps.get-version.outputs.version }}";
        };
      };

      container = mkOption {
        type = types.nullOr containerType;
        default = null;
        description = ''
          Container to run the job in. Can be a string image name or detailed configuration.
        '';
        example = "node:20";
      };

      services = mkOption {
        type = types.nullOr (types.attrsOf serviceContainerType);
        default = null;
        description = ''
          Service containers to run alongside the job.
        '';
        example = {
          redis = {
            image = "redis:latest";
            ports = ["6379"];
          };
        };
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
          Concurrency control for the job.
        '';
      };

      snapshot = mkOption {
        type = types.nullOr (types.either types.str (types.attrsOf types.anything));
        default = null;
        description = ''
          Generate a custom runner image. Can be a string or configuration object.
        '';
        example = "my-custom-image";
      };

      environment = mkOption {
        type = types.nullOr environmentType;
        default = null;
        description = ''
          Environment that the job references. Can be a string name or object with name and url.
        '';
        example = "production";
      };

      uses = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Location and version of a reusable workflow file to run as a job.
          Format: {owner}/{repo}/.github/workflows/{filename}@{ref}
        '';
        example = "octo-org/example-repo/.github/workflows/deploy.yml@main";
      };

      with_ = mkOption {
        type = types.nullOr (types.attrsOf (types.oneOf [types.str types.int types.bool]));
        default = null;
        description = ''
          Map of inputs to pass to a reusable workflow (when using 'uses').
        '';
        example = {
          username = "mona";
          environment = "production";
        };
      };

      secrets = mkOption {
        type = types.nullOr (types.either
          (types.enum ["inherit"])
          (types.attrsOf types.str));
        default = null;
        description = ''
          Secrets to pass to a reusable workflow. Can be:
          - "inherit" to pass all secrets
          - An attribute set mapping secret names to values
        '';
        example = {
          access-token = "\${{ secrets.PERSONAL_ACCESS_TOKEN }}";
        };
      };

      defaults = mkOption {
        type = types.nullOr jobDefaultsType;
        default = null;
        description = ''
          Default settings for all steps in the job.
        '';
      };
    };
  };
}
