{lib, ...}: {
  # Helper functions for converting Nix structures to YAML-compatible format

  # Remove null values from attribute sets
  filterNulls = attrs:
    lib.filterAttrs (_name: value: value != null) attrs;

  # Convert a step to YAML-compatible format
  stepToYaml = step: let
    filterNulls = lib.filterAttrs (_name: value: value != null);
    base = filterNulls {
      inherit (step) name;
      inherit (step) id;
      "if" = step.if_;
      inherit (step) run;
      inherit (step) uses;
      "with" = step.with_;
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
    base = filterNulls {
      inherit (job) name;
      "runs-on" = job.runsOn;
      inherit (job) needs;
      "if" = job.if_;
      steps = map converters.stepToYaml job.steps;
      inherit (job) env;
      strategy =
        if job.strategy != null
        then
          filterNulls {
            inherit (job.strategy) matrix;
            "fail-fast" = job.strategy.failFast;
            "max-parallel" = job.strategy.maxParallel;
          }
        else null;
      "continue-on-error" = job.continueOnError;
      "timeout-minutes" = job.timeoutMinutes;
      inherit (job) permissions;
      inherit (job) outputs;
      inherit (job) container;
      inherit (job) services;
      inherit (job) concurrency;
    };
  in
    base;

  # Convert trigger configuration to YAML-compatible format
  triggerToYaml = on: let
    filterNulls = lib.filterAttrs (_name: value: value != null);
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

      pullRequest =
        if on.pullRequest != null
        then
          filterNulls {
            branches = on.pullRequest.branches or null;
            "branches-ignore" = on.pullRequest.branchesIgnore or null;
            paths = on.pullRequest.paths or null;
            "paths-ignore" = on.pullRequest.pathsIgnore or null;
            types = on.pullRequest.types or null;
          }
        else null;

      workflowDispatch =
        if on.workflowDispatch != null
        then
          filterNulls {
            inputs = on.workflowDispatch.inputs or null;
          }
        else null;
    in
      filterNulls {
        inherit push;
        pull_request = pullRequest;
        inherit (on) schedule;
        workflow_dispatch = workflowDispatch;
        workflow_call = on.workflowCall;
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
    jobsWithDefaults = lib.mapAttrs (
      _name: job: converters.applyJobDefaults jobDefaults job
    ) workflow.jobs;

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
      "on" = converters.triggerToYaml workflow.on;
      jobs = lib.mapAttrs (_name: converters.jobToYaml) jobsWithDefaults;
      inherit (workflow) env;
      inherit (workflow) permissions;
      inherit concurrency;
      inherit defaults;
    };
}
