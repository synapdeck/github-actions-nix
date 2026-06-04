{lib, ...}: let
  inherit (lib) mkOption types;

  stepTypes = import ./step.nix {inherit lib;};
  inherit (stepTypes) stepType;

  inputType = types.submodule {
    options = {
      description = mkOption {
        type = types.str;
        description = "Description of the input.";
      };
      required = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Whether the input is required.";
      };
      default = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Default value for the input.";
      };
    };
  };

  outputType = types.submodule {
    options = {
      description = mkOption {
        type = types.str;
        description = "Description of the output.";
      };
      value = mkOption {
        type = types.str;
        description = ''
          Value expression for the output, e.g.
          "''${{ steps.my-step.outputs.result }}".
        '';
      };
    };
  };

  runsType = types.submodule {
    options = {
      using = mkOption {
        # Extend this enum to add action kinds (docker, node20, ...).
        type = types.enum ["composite"];
        default = "composite";
        description = "The action runner kind. Only composite is supported.";
      };
      steps = mkOption {
        type = types.listOf stepType;
        default = [];
        description = ''
          Steps for a composite action. Required (non-empty) when
          using = "composite".
        '';
      };
    };
  };
in {
  actionType = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "Display name of the action.";
      };
      description = mkOption {
        type = types.str;
        description = "Description of the action (required by GitHub).";
      };
      inputs = mkOption {
        type = types.attrsOf inputType;
        default = {};
        description = "Input parameters for the action.";
      };
      outputs = mkOption {
        type = types.attrsOf outputType;
        default = {};
        description = "Outputs the action exposes.";
      };
      runs = mkOption {
        type = runsType;
        description = "How the action runs (discriminated on runs.using).";
      };
    };
  };
}
