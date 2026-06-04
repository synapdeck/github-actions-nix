# Composite Actions Generation

Status: approved design (pending implementation plan)
Date: 2026-06-03
Branch: `typedrat/composite-actions`

## Problem

`github-actions-nix` generates workflow YAML from Nix but has no way to generate
**reusable actions**. Consumers (e.g. synapdeck's CI) repeat the same setup step
sequences (checkout → install Nix → FlakeHub cache → pnpm-store cache → install)
across many jobs. Today the only deduplication is splicing shared Nix step-lists
into every job, which produces verbose expanded YAML and is hard to debug — a
failure shows up as one of a dozen inlined steps repeated per job, with no named,
collapsible unit in the Actions UI.

A first-class "generate a composite action" feature lets consumers define a setup
sequence once, emit it as `.github/actions/<name>/action.yml`, and reference it
with `uses: ./.github/actions/<name>`. The action appears as a single named unit
in logs (one collapsible group), is independently debuggable, and is reusable
across workflows (and potentially repos).

## Goals

- Add an `actions` option to the `githubActions` module that generates GitHub
  **composite** actions to `.github/actions/<name>/action.yml`.
- Reuse the existing `stepType` for action steps (composite steps are workflow
  steps plus a required `shell` on `run` steps).
- Be **non-breaking and additive**: existing `workflows` behavior is unchanged;
  the feature ships on its own cadence and consumers opt in.
- Design the type so future action kinds (docker, javascript/node, and a
  Nix-derivation-backed script action) are **additive** — a new `runs.using`
  value plus a converter case, not a reshape.

Non-goals (now): docker and javascript action kinds; branding; Nix-derivation
script materialization (designed-for, not built — see "Extensibility").

## Design

### Option: `githubActions.actions`

Mirrors `githubActions.workflows`. Named `actions` (not `compositeActions`) so it
is the namespace for all action kinds; composite is the first.

```nix
actions = mkOption {
  type = types.attrsOf actionType;
  default = {};
  description = ''
    GitHub Actions composite actions to generate. Keys are action names;
    each emits .github/actions/<name>/action.yml.
  '';
};
```

### Type: `actionType` (discriminated on `runs.using`)

```nix
actionType = types.submodule {
  options = {
    name = mkOption { type = types.str; };                    # required
    description = mkOption { type = types.str; };             # required (GitHub requires it)
    inputs = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          description = mkOption { type = types.str; };
          required = mkOption { type = types.nullOr types.bool; default = null; };
          default = mkOption { type = types.nullOr types.str; default = null; };
        };
      });
      default = {};
    };
    outputs = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          description = mkOption { type = types.str; };
          value = mkOption { type = types.str; };             # e.g. "${{ steps.x.outputs.y }}"
        };
      });
      default = {};
    };
    runs = mkOption { type = runsType; };                     # discriminated below
  };
};
```

### Discriminated `runs` (enum, composite-only for now)

`runs.using` is an **enum currently containing only `"composite"`**. This makes
"composite is the only kind today" explicit at the type level; adding a kind is
`types.enum ["composite" "docker" ...]` + a converter case. Sub-options required
by a given `using` are keyed off the enum value (composite requires `steps`).

```nix
runsType = types.submodule {
  options = {
    using = mkOption {
      type = types.enum ["composite"];   # extend this list to add kinds
      default = "composite";
    };
    steps = mkOption {
      type = types.listOf stepType;      # reuse existing stepType
      default = [];
      description = "Steps for a composite action (required when using = composite).";
    };
  };
};
```

(Validation that `steps` is non-empty when `using == "composite"` can be a Nix
assertion in the converter; with a single-value enum it's currently trivially
satisfied.)

### Converter: `actionToYaml`

New function in `modules/converters.nix`, dispatching on `runs.using`:

```nix
actionToYaml = action: let
  filterNulls = lib.filterAttrs (_n: v: v != null);
  runsYaml =
    if action.runs.using == "composite"
    then {
      using = "composite";
      steps = map compositeStepToYaml action.runs.steps;
    }
    else throw "actionToYaml: unsupported runs.using '${action.runs.using}'";
in filterNulls {
  inherit (action) name description;
  inputs = if action.inputs == {} then null else lib.mapAttrs (_: i: filterNulls {
    inherit (i) description; required = i.required; default = i.default;
  }) action.inputs;
  outputs = if action.outputs == {} then null else lib.mapAttrs (_: o: {
    inherit (o) description value;
  }) action.outputs;
  runs = runsYaml;
};
```

`compositeStepToYaml` reuses `stepToYaml` but **defaults `shell = "bash"` on any
`run` step that omits it** (GitHub requires `shell` on composite run steps):

```nix
compositeStepToYaml = step:
  let base = stepToYaml step;
  in if (step.run or null) != null && (step.shell or null) == null
     then base // { shell = "bash"; }
     else base;
```

### Emission: directory-per-action

Unlike workflows (flat `.github/workflows/<name>.yml`), composite actions live at
`.github/actions/<name>/action.yml`. Add, mirroring `workflowFiles`/`workflowsDir`:

- `actionFiles` (readOnly `attrsOf package`): keys are `<name>/action.yml`.
- `actionsDir` (readOnly package): a derivation containing `<name>/action.yml`
  subdirectories.

```nix
actionFiles = lib.mapAttrs' (name: action:
  lib.nameValuePair "${name}/action.yml" (
    pkgs.runCommandLocal "${name}-action.yml" {
      nativeBuildInputs = [pkgs.yq-go];
      json = builtins.toJSON (actionToYaml action);
      passAsFile = ["json"];
    } ''
      {
        echo "# This file is automatically generated from Nix configuration. Do not edit directly."
        echo ""
        yq eval --prettyPrint '.' -P $jsonPath
      } > $out
    ''
  )) cfg.actions;
```

The consuming repo wires `actionFiles` into its `files.files` (the `files`
flake-module) so `nix run .#write-files` writes
`.github/actions/<name>/action.yml`, exactly as it does for workflows today.

### Extensibility (designed-for, not built)

The discriminated `runs.using` enum + converter dispatch is the extension axis:

- **docker**: add `"docker"` to the enum; `runs` gains `image`/`args`/`entrypoint`;
  converter emits `using: docker`.
- **node**: add `"node20"`; `runs` gains `main`/`pre`/`post`.
- **Nix-derivation script** (the interesting one): a `using` kind whose `runs`
  references a built derivation (e.g. `pkgs.writeShellApplication` or a compiled
  binary). At generation time the library **materializes the derivation into the
  action directory** alongside `action.yml`, and `action.yml`'s `runs` points at
  the vendored file. This makes "the action's logic is a typed, tested Nix build"
  possible while still emitting a standard local action. Out of scope now; the
  type/emission are structured so it slots in additively.

## Implementation notes

- New type file `modules/types/action.nix` (mirrors `types/step.nix`).
- `actionToYaml` + `compositeStepToYaml` in `modules/converters.nix` (reuse
  `stepToYaml`).
- `actions`/`actionFiles`/`actionsDir` options + config in `modules/github-ci.nix`.
- Export nothing new from `flake.nix` (the module already exports via
  `flakeModules`); just the new options.
- Add an `examples/composite-action/flake.nix` exercising `actions` with inputs,
  outputs, and a run step (verifies `shell: bash` defaulting).
- Version: this is additive/non-breaking → minor bump. Publish to FlakeHub via the
  existing tag-push CI.

## Verification

- `nix build .#...actionFiles` (via an example) produces
  `composite-action/action.yml` with `runs.using: composite` and `shell: bash` on
  run steps.
- An example action with `inputs`/`outputs` round-trips to valid action YAML
  (`yq` parses; `runs.steps` present).
- Existing `workflows` generation is byte-identical before/after (non-breaking):
  diff generated example workflow YAML against the pre-change output.

## Sequencing

Ships independently in this repo (non-breaking). synapdeck consumes it by bumping
the `github-actions-nix` flake input after publish; during development synapdeck
uses a local `path:`/git override on the input to iterate against this branch
before the FlakeHub release.
