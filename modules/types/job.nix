{lib, ...}: let
  inherit (lib) mkOption types;
  stepTypes = import ./step.nix {inherit lib;};
  inherit (stepTypes) stepType;
in rec {
  # Strategy type for matrix builds
  strategyType = types.submodule {
    options = {
      matrix = mkOption {
        type = types.nullOr (types.attrsOf (types.either (types.listOf types.str) (types.attrsOf types.anything)));
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
        type = types.nullOr (types.either types.str (types.listOf types.str));
        default = null;
        description = ''
          The type of runner to use. Can be a single string or a list for matrix builds.
          Defaults to "ubuntu-latest" if not set via job or workflow defaults.
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
        type = types.nullOr (types.either types.str (types.attrsOf types.anything));
        default = null;
        description = ''
          Container to run the job in.
        '';
        example = "node:20";
      };

      services = mkOption {
        type = types.nullOr (types.attrsOf (types.attrsOf types.anything));
        default = null;
        description = ''
          Service containers to run alongside the job.
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
          Concurrency control for the job.
        '';
      };
    };
  };
}
