{lib, ...}: let
  inherit (lib) mkOption types;
in rec {
  # Push trigger type
  pushTriggerType = types.submodule {
    freeformType = types.attrsOf types.anything;
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

  # Pull request trigger type
  pullRequestTriggerType = types.submodule {
    freeformType = types.attrsOf types.anything;
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

  # Workflow run trigger type
  workflowRunTriggerType = types.submodule {
    freeformType = types.attrsOf types.anything;
    options = {
      workflows = mkOption {
        type = types.listOf types.str;
        description = "List of workflow names or file paths to trigger on.";
        example = ["Build" "Test"];
      };

      types = mkOption {
        type = types.nullOr (types.listOf (types.enum ["completed" "requested" "in_progress"]));
        default = null;
        description = "Workflow run activity types.";
        example = ["completed"];
      };

      branches = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Branch patterns to trigger on.";
      };

      branchesIgnore = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Branch patterns to ignore.";
      };
    };
  };

  # Generic event type with activity types
  activityTypeTriggerType = activityTypes:
    types.submodule {
      freeformType = types.attrsOf types.anything;
      options = {
        types = mkOption {
          type = types.nullOr (types.listOf (types.enum activityTypes));
          default = null;
          description = "Activity types to trigger on.";
        };
      };
    };

  # Simple event type (no known configuration options)
  simpleEventTriggerType = types.submodule {
    freeformType = types.attrsOf types.anything;
    options = {};
  };

  # Schedule trigger type
  scheduleTriggerType = types.submodule {
    freeformType = types.attrsOf types.anything;
    options = {
      cron = mkOption {
        type = types.str;
        description = "Cron expression for schedule.";
        example = "0 0 * * *";
      };
    };
  };

  # Workflow dispatch input type
  workflowDispatchInputType = types.submodule {
    options = {
      description = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Input description.";
      };
      required = mkOption {
        type = types.bool;
        default = false;
        description = "Whether the input is required.";
      };
      default = mkOption {
        type = types.nullOr (types.oneOf [types.str types.int types.bool]);
        default = null;
        description = "Default value.";
      };
      type = mkOption {
        type = types.nullOr (types.enum ["string" "boolean" "choice" "environment" "number"]);
        default = null;
        description = "Input type.";
      };
      options = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Options for choice type.";
      };
    };
  };

  # Workflow dispatch trigger type
  workflowDispatchType = types.submodule {
    freeformType = types.attrsOf types.anything;
    options = {
      inputs = mkOption {
        type = types.nullOr (types.attrsOf workflowDispatchInputType);
        default = null;
        description = "Workflow dispatch inputs.";
      };
    };
  };

  # Workflow call input type
  workflowCallInputType = types.submodule {
    options = {
      description = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Input description.";
      };
      required = mkOption {
        type = types.bool;
        default = false;
        description = "Whether the input is required.";
      };
      default = mkOption {
        type = types.nullOr (types.oneOf [types.str types.int types.bool]);
        default = null;
        description = "Default value.";
      };
      type = mkOption {
        type = types.enum ["string" "boolean" "number"];
        description = "Input type (required for workflow_call).";
      };
    };
  };

  # Workflow call output type
  workflowCallOutputType = types.submodule {
    options = {
      description = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Output description.";
      };
      value = mkOption {
        type = types.str;
        description = "The value of the output (typically references job outputs).";
        example = "\${{ jobs.my_job.outputs.job_output1 }}";
      };
    };
  };

  # Workflow call secret type
  workflowCallSecretType = types.submodule {
    options = {
      description = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Secret description.";
      };
      required = mkOption {
        type = types.bool;
        default = false;
        description = "Whether the secret is required.";
      };
    };
  };

  # Workflow call trigger type
  workflowCallType = types.submodule {
    freeformType = types.attrsOf types.anything;
    options = {
      inputs = mkOption {
        type = types.nullOr (types.attrsOf workflowCallInputType);
        default = null;
        description = "Inputs for the reusable workflow.";
      };
      outputs = mkOption {
        type = types.nullOr (types.attrsOf workflowCallOutputType);
        default = null;
        description = "Outputs for the reusable workflow.";
      };
      secrets = mkOption {
        type = types.nullOr (types.attrsOf workflowCallSecretType);
        default = null;
        description = "Secrets for the reusable workflow.";
      };
    };
  };

  # Repository dispatch trigger type
  repositoryDispatchType = types.submodule {
    freeformType = types.attrsOf types.anything;
    options = {
      types = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Custom event types.";
      };
    };
  };

  # Complete trigger configuration type (on)
  onType =
    types.either
    (types.listOf types.str)
    (types.submodule {
      options = {
        push = mkOption {
          type = types.nullOr pushTriggerType;
          default = null;
          description = "Push trigger configuration.";
        };

        pullRequest = mkOption {
          type = types.nullOr pullRequestTriggerType;
          default = null;
          description = "Pull request trigger configuration.";
        };

        pullRequestTarget = mkOption {
          type = types.nullOr pullRequestTriggerType;
          default = null;
          description = "Pull request target trigger configuration.";
        };

        workflowRun = mkOption {
          type = types.nullOr workflowRunTriggerType;
          default = null;
          description = "Workflow run trigger configuration.";
        };

        schedule = mkOption {
          type = types.nullOr (types.listOf scheduleTriggerType);
          default = null;
          description = "Schedule trigger configuration.";
        };

        workflowDispatch = mkOption {
          type = types.nullOr workflowDispatchType;
          default = null;
          description = "Manual workflow dispatch configuration.";
        };

        workflowCall = mkOption {
          type = types.nullOr workflowCallType;
          default = null;
          description = "Workflow call trigger configuration.";
        };

        # Events with activity types
        issues = mkOption {
          type = types.nullOr (activityTypeTriggerType [
            "opened"
            "edited"
            "deleted"
            "transferred"
            "pinned"
            "unpinned"
            "closed"
            "reopened"
            "assigned"
            "unassigned"
            "labeled"
            "unlabeled"
            "locked"
            "unlocked"
            "milestoned"
            "demilestoned"
          ]);
          default = null;
          description = "Issues event trigger configuration.";
        };

        issueComment = mkOption {
          type = types.nullOr (activityTypeTriggerType ["created" "edited" "deleted"]);
          default = null;
          description = "Issue comment event trigger configuration.";
        };

        release = mkOption {
          type = types.nullOr (activityTypeTriggerType [
            "published"
            "unpublished"
            "created"
            "edited"
            "deleted"
            "prereleased"
            "released"
          ]);
          default = null;
          description = "Release event trigger configuration.";
        };

        checkRun = mkOption {
          type = types.nullOr (activityTypeTriggerType [
            "created"
            "rerequested"
            "completed"
            "requested_action"
          ]);
          default = null;
          description = "Check run event trigger configuration.";
        };

        checkSuite = mkOption {
          type = types.nullOr (activityTypeTriggerType ["completed"]);
          default = null;
          description = "Check suite event trigger configuration.";
        };

        deployment = mkOption {
          type = types.nullOr simpleEventTriggerType;
          default = null;
          description = "Deployment event trigger configuration.";
        };

        deploymentStatus = mkOption {
          type = types.nullOr simpleEventTriggerType;
          default = null;
          description = "Deployment status event trigger configuration.";
        };

        discussion = mkOption {
          type = types.nullOr (activityTypeTriggerType [
            "created"
            "edited"
            "deleted"
            "transferred"
            "pinned"
            "unpinned"
            "labeled"
            "unlabeled"
            "locked"
            "unlocked"
            "category_changed"
            "answered"
            "unanswered"
          ]);
          default = null;
          description = "Discussion event trigger configuration.";
        };

        discussionComment = mkOption {
          type = types.nullOr (activityTypeTriggerType ["created" "edited" "deleted"]);
          default = null;
          description = "Discussion comment event trigger configuration.";
        };

        # Simple events (no configuration)
        fork = mkOption {
          type = types.nullOr simpleEventTriggerType;
          default = null;
          description = "Fork event trigger.";
        };

        create = mkOption {
          type = types.nullOr simpleEventTriggerType;
          default = null;
          description = "Create event trigger.";
        };

        delete = mkOption {
          type = types.nullOr simpleEventTriggerType;
          default = null;
          description = "Delete event trigger.";
        };

        gollum = mkOption {
          type = types.nullOr simpleEventTriggerType;
          default = null;
          description = "Gollum (wiki) event trigger.";
        };

        pageBuild = mkOption {
          type = types.nullOr simpleEventTriggerType;
          default = null;
          description = "Page build event trigger.";
        };

        public = mkOption {
          type = types.nullOr simpleEventTriggerType;
          default = null;
          description = "Public event trigger.";
        };

        watch = mkOption {
          type = types.nullOr (activityTypeTriggerType ["started"]);
          default = null;
          description = "Watch event trigger.";
        };

        status = mkOption {
          type = types.nullOr simpleEventTriggerType;
          default = null;
          description = "Status event trigger.";
        };

        mergeGroup = mkOption {
          type = types.nullOr (activityTypeTriggerType ["checks_requested"]);
          default = null;
          description = "Merge group event trigger.";
        };

        milestone = mkOption {
          type = types.nullOr (activityTypeTriggerType [
            "created"
            "closed"
            "opened"
            "edited"
            "deleted"
          ]);
          default = null;
          description = "Milestone event trigger.";
        };

        label = mkOption {
          type = types.nullOr (activityTypeTriggerType ["created" "edited" "deleted"]);
          default = null;
          description = "Label event trigger.";
        };

        repositoryDispatch = mkOption {
          type = types.nullOr repositoryDispatchType;
          default = null;
          description = "Repository dispatch event trigger.";
        };

        branchProtectionRule = mkOption {
          type = types.nullOr (activityTypeTriggerType ["created" "edited" "deleted"]);
          default = null;
          description = "Branch protection rule event trigger.";
        };
      };
    });
}
