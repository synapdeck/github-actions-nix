{lib, ...}: let
  inherit (lib) mkOption types;
in {
  # Step type - represents a single step in a job
  stepType = types.submodule {
    options = {
      name = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Display name for the step.
        '';
        example = "Build project";
      };

      id = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Unique identifier for the step. Can be used to reference the step
          in later steps via `steps.<id>.outputs.<name>`.
        '';
        example = "build-step";
      };

      if_ = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Conditional expression to determine if the step should run.
        '';
        example = "success()";
      };

      run = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Shell command to run. Mutually exclusive with `uses`.
        '';
        example = "npm run build";
      };

      uses = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Action to use. Mutually exclusive with `run`.
        '';
        example = "actions/checkout@v4";
      };

      with_ = mkOption {
        type = types.nullOr (types.attrsOf (types.oneOf [types.str types.int types.bool]));
        default = null;
        description = ''
          Input parameters for the action specified in `uses`.
        '';
        example = {
          node-version = "20";
          fetch-depth = 0;
        };
      };

      env = mkOption {
        type = types.nullOr (types.attrsOf types.str);
        default = null;
        description = ''
          Environment variables for the step.
        '';
        example = {
          NODE_ENV = "production";
        };
      };

      workingDirectory = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Working directory for the step.
        '';
        example = "./packages/web";
      };

      shell = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Shell to use for the step.
        '';
        example = "bash";
      };

      continueOnError = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = ''
          Whether to allow the job to continue if this step fails.
        '';
      };

      timeoutMinutes = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = ''
          Maximum time in minutes to run the step before killing it.
        '';
        example = 10;
      };
    };
  };
}
