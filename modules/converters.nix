{lib, ...}: {
  # Helper functions for converting Nix structures to YAML-compatible format

  # Remove null values from attribute sets
  filterNulls = attrs:
    lib.filterAttrs (_name: value: value != null) attrs;

  # Convert a step to YAML-compatible format
  stepToYaml = step: let
    filterNulls = lib.filterAttrs (_name: value: value != null);

    # Handle with_ which may be a submodule with freeform type
    withValue =
      if step.with_ != null
      then
        # Remove null values from with_ attrs
        filterNulls step.with_
      else null;

    base = filterNulls {
      inherit (step) name;
      inherit (step) id;
      "if" = step.if_;
      inherit (step) run;
      inherit (step) uses;
      "with" = withValue;
      inherit (step) env;
      inherit (step) shell;
      "continue-on-error" = step.continueOnError;
      "timeout-minutes" = step.timeoutMinutes;
    };
    withWorkingDir =
      if step.workingDirectory != null
      then base // {"working-directory" = step.workingDirectory;}
      else base;
  in
    withWorkingDir;

  # Convert a job to YAML-compatible format
  jobToYaml = job: let
    filterNulls = lib.filterAttrs (_name: value: value != null);
    converters = import ./converters.nix {inherit lib;};

    # Convert runs-on to proper format (string, list, or object with group/labels)
    runsOnValue =
      if job.runsOn != null
      then
        if builtins.isAttrs job.runsOn && (job.runsOn ? group || job.runsOn ? labels)
        then filterNulls {inherit (job.runsOn) group labels;}
        else job.runsOn
      else null;

    # Convert environment to proper format
    environmentValue =
      if job.environment != null
      then
        if builtins.isString job.environment
        then job.environment
        else filterNulls {inherit (job.environment) name url;}
      else null;

    # Convert container to proper format
    containerValue =
      if job.container != null
      then
        if builtins.isString job.container
        then job.container
        else
          filterNulls {
            inherit (job.container) image env ports volumes options;
            credentials =
              if job.container.credentials != null
              then filterNulls {inherit (job.container.credentials) username password;}
              else null;
          }
      else null;

    # Convert services to proper format
    servicesValue =
      if job.services != null
      then
        lib.mapAttrs (
          _name: service:
            if builtins.isString service
            then service
            else
              filterNulls {
                inherit (service) image env ports volumes options;
                credentials =
                  if service.credentials != null
                  then filterNulls {inherit (service.credentials) username password;}
                  else null;
              }
        )
        job.services
      else null;

    # Convert concurrency to proper format
    concurrencyValue =
      if job.concurrency != null
      then
        if builtins.isString job.concurrency
        then job.concurrency
        else
          filterNulls {
            inherit (job.concurrency) group;
            "cancel-in-progress" = job.concurrency.cancelInProgress;
          }
      else null;

    # Convert job defaults to proper format
    defaultsValue =
      if job.defaults != null && job.defaults.run != null
      then {
        run = filterNulls {
          inherit (job.defaults.run) shell;
          "working-directory" = job.defaults.run.workingDirectory;
        };
      }
      else null;

    # Convert with_ for reusable workflows
    withValue =
      if job.with_ != null
      then filterNulls job.with_
      else null;

    # Convert secrets - handle both "inherit" and attribute sets
    secretsValue =
      if job.secrets != null
      then
        if job.secrets == "inherit"
        then "inherit"
        else job.secrets
      else null;

    base = filterNulls {
      inherit (job) name;
      "runs-on" = runsOnValue;
      inherit (job) needs;
      "if" = job.if_;
      steps =
        if job.steps != []
        then map converters.stepToYaml job.steps
        else null;
      inherit (job) env;
      strategy =
        if job.strategy != null
        then
          filterNulls {
            matrix =
              if job.strategy.matrix != null
              then
                # Extract all attrs except include/exclude, then add them back
                let
                  matrixBase = removeAttrs job.strategy.matrix ["include" "exclude"];
                  matrixWithSpecial = filterNulls {
                    inherit (job.strategy.matrix) include exclude;
                  };
                in
                  matrixBase // matrixWithSpecial
              else null;
            "fail-fast" = job.strategy.failFast;
            "max-parallel" = job.strategy.maxParallel;
          }
        else null;
      "continue-on-error" = job.continueOnError;
      "timeout-minutes" = job.timeoutMinutes;
      inherit (job) permissions;
      inherit (job) outputs;
      container = containerValue;
      services = servicesValue;
      concurrency = concurrencyValue;
      inherit (job) snapshot;
      environment = environmentValue;
      inherit (job) uses;
      "with" = withValue;
      secrets = secretsValue;
      defaults = defaultsValue;
    };
  in
    base;

  # Convert trigger configuration to YAML-compatible format
  triggerToYaml = on: let
    filterNulls = lib.filterAttrs (_name: value: value != null);

    # Helper to convert event with branches/paths filters
    convertBranchPathEvent = event:
      if event != null
      then
        filterNulls {
          branches = event.branches or null;
          "branches-ignore" = event.branchesIgnore or null;
          paths = event.paths or null;
          "paths-ignore" = event.pathsIgnore or null;
          types = event.types or null;
        }
      else null;

    # Helper to convert simple activity type events
    convertActivityTypeEvent = event:
      if event != null
      then
        if builtins.isAttrs event && event ? types
        then filterNulls {inherit (event) types;}
        else event
      else null;
  in
    if builtins.isList on
    then on
    else let
      push =
        if on.push != null
        then
          filterNulls {
            branches = on.push.branches or null;
            "branches-ignore" = on.push.branchesIgnore or null;
            tags = on.push.tags or null;
            "tags-ignore" = on.push.tagsIgnore or null;
            paths = on.push.paths or null;
            "paths-ignore" = on.push.pathsIgnore or null;
          }
        else null;

      pullRequest = convertBranchPathEvent on.pullRequest;
      pullRequestTarget = convertBranchPathEvent on.pullRequestTarget;

      workflowRun =
        if on.workflowRun != null
        then
          filterNulls {
            inherit (on.workflowRun) workflows;
            types = on.workflowRun.types or null;
            branches = on.workflowRun.branches or null;
            "branches-ignore" = on.workflowRun.branchesIgnore or null;
          }
        else null;

      workflowDispatch =
        if on.workflowDispatch != null
        then
          filterNulls {
            inputs = on.workflowDispatch.inputs or null;
          }
        else null;

      workflowCall =
        if on.workflowCall != null
        then
          if builtins.isAttrs on.workflowCall && (on.workflowCall ? inputs || on.workflowCall ? outputs || on.workflowCall ? secrets)
          then
            filterNulls {
              inherit (on.workflowCall) inputs outputs secrets;
            }
          else on.workflowCall
        else null;

      repositoryDispatch = convertActivityTypeEvent on.repositoryDispatch;
    in
      filterNulls {
        inherit push;
        pull_request = pullRequest;
        pull_request_target = pullRequestTarget;
        workflow_run = workflowRun;
        inherit (on) schedule;
        workflow_dispatch = workflowDispatch;
        workflow_call = workflowCall;

        # Events with activity types
        inherit (on) issues;
        issue_comment = convertActivityTypeEvent on.issueComment;
        inherit (on) release;
        check_run = convertActivityTypeEvent on.checkRun;
        check_suite = convertActivityTypeEvent on.checkSuite;
        inherit (on) deployment;
        deployment_status = on.deploymentStatus;
        inherit (on) discussion;
        discussion_comment = convertActivityTypeEvent on.discussionComment;

        # Simple events
        inherit (on) fork create delete gollum;
        page_build = on.pageBuild;
        inherit (on) public watch status;
        merge_group = convertActivityTypeEvent on.mergeGroup;
        inherit (on) milestone label;
        repository_dispatch = repositoryDispatch;
        branch_protection_rule = convertActivityTypeEvent on.branchProtectionRule;
      };

  # Apply job defaults from workflow defaults to a job
  applyJobDefaults = jobDefaults: job: let
    # Helper to merge env vars, with job values taking precedence
    mergeEnv =
      if jobDefaults != null && jobDefaults.env != null
      then
        if job.env != null
        then jobDefaults.env // job.env
        else jobDefaults.env
      else job.env;

    # Apply defaults with job values taking precedence (null means use default)
    withDefaults =
      job
      // (
        if jobDefaults != null
        then {
          runsOn =
            if job.runsOn != null
            then job.runsOn
            else if jobDefaults.runsOn != null
            then jobDefaults.runsOn
            else "ubuntu-latest"; # Final fallback

          env = mergeEnv;

          permissions =
            if job.permissions != null
            then job.permissions
            else jobDefaults.permissions;

          timeoutMinutes =
            if job.timeoutMinutes != null
            then job.timeoutMinutes
            else jobDefaults.timeoutMinutes;

          continueOnError =
            if job.continueOnError != null
            then job.continueOnError
            else jobDefaults.continueOnError;
        }
        else {
          # No defaults, just ensure runsOn has fallback
          runsOn =
            if job.runsOn != null
            then job.runsOn
            else "ubuntu-latest";
        }
      );
  in
    withDefaults;

  # Convert a workflow to YAML-compatible format
  workflowToYaml = workflow: let
    filterNulls = lib.filterAttrs (_name: value: value != null);
    converters = import ./converters.nix {inherit lib;};

    # Extract job defaults if present
    jobDefaults =
      if workflow.defaults != null && workflow.defaults.job != null
      then workflow.defaults.job
      else null;

    # Apply job defaults to each job before converting
    jobsWithDefaults =
      lib.mapAttrs (
        _name: job: converters.applyJobDefaults jobDefaults job
      )
      workflow.jobs;

    concurrency =
      if workflow.concurrency != null
      then
        (
          if builtins.isString workflow.concurrency
          then workflow.concurrency
          else
            filterNulls {
              inherit (workflow.concurrency) group;
              "cancel-in-progress" = workflow.concurrency.cancelInProgress;
            }
        )
      else null;

    defaults =
      if workflow.defaults != null && workflow.defaults.run != null
      then {
        run = filterNulls {
          inherit (workflow.defaults.run) shell;
          "working-directory" = workflow.defaults.run.workingDirectory;
        };
      }
      else null;
  in
    filterNulls {
      inherit (workflow) name;
      "run-name" = workflow.runName;
      "on" = converters.triggerToYaml workflow.on;
      jobs = lib.mapAttrs (_name: converters.jobToYaml) jobsWithDefaults;
      inherit (workflow) env;
      inherit (workflow) permissions;
      inherit concurrency;
      inherit defaults;
    };
}
