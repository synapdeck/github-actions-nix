# Composite Actions Generation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `githubActions.actions` option that generates GitHub composite actions to `.github/actions/<name>/action.yml`, with a discriminated `runs.using` enum (composite-only for now), reusing the existing `stepType`.

**Architecture:** Mirror the existing `workflows` pipeline. A new `actionType` (in `modules/types/action.nix`) discriminates on `runs.using` (enum `["composite"]`). A new `actionToYaml` converter (in `modules/converters.nix`) dispatches on `using` and reuses `stepToYaml`, defaulting `shell: bash` on composite run-steps. New `actions`/`actionFiles`/`actionsDir` options in `modules/github-ci.nix` emit one `action.yml` per action (directory-per-action). Non-breaking: `workflows` is untouched.

**Tech Stack:** Nix, flake-parts, `lib.mkOption`/`types`, `yq-go` for YAML emission.

**Spec:** `docs/specs/2026-06-03-composite-actions-design.md`

**Critical constraints:**
- Additive and non-breaking: existing `workflows`/`workflowFiles`/`workflowsDir` output must be byte-identical after this change (Task 6 verifies).
- Composite actions live at `.github/actions/<name>/action.yml` (directory per action), unlike workflows' flat files.
- GitHub requires `shell` on composite `run` steps and requires `description` on the action.

---

## Task 1: Define the `actionType`

**Files:**
- Create: `modules/types/action.nix`
- Test: `examples/composite-action/flake.nix` (created in Task 5; type is exercised end-to-end there)

- [ ] **Step 1: Write the action type**

Create `modules/types/action.nix`:
```nix
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
```

- [ ] **Step 2: Verify the type file evaluates standalone**

Run:
```bash
nix eval --impure --expr '(import ./modules/types/action.nix { lib = (import <nixpkgs> {}).lib; }).actionType._type'
```
Expected: prints `"option-type"` (or evaluates without error), confirming the submodule type builds.

- [ ] **Step 3: Commit**

```bash
git add modules/types/action.nix
git commit -m "feat: add actionType for composite action generation"
```

---

## Task 2: Add `actionToYaml` + `compositeStepToYaml` converters

**Files:**
- Modify: `modules/converters.nix` (add two functions to the returned attrset)

- [ ] **Step 1: Add the composite-step converter (defaults shell: bash)**

In `modules/converters.nix`, inside the returned attrset (alongside `stepToYaml`), add:
```nix
  # Convert a composite-action step. Same as a workflow step, but GitHub
  # requires `shell` on `run` steps in composite actions, so default to bash.
  compositeStepToYaml = step: let
    converters = import ./converters.nix {inherit lib;};
    base = converters.stepToYaml step;
  in
    if step.run != null && step.shell == null
    then base // {shell = "bash";}
    else base;
```

- [ ] **Step 2: Add the action converter (dispatches on runs.using)**

In the same attrset, add:
```nix
  # Convert a composite action to YAML-compatible format.
  actionToYaml = action: let
    filterNulls = lib.filterAttrs (_name: value: value != null);
    converters = import ./converters.nix {inherit lib;};

    runsYaml =
      if action.runs.using == "composite"
      then {
        using = "composite";
        steps = map converters.compositeStepToYaml action.runs.steps;
      }
      else throw "actionToYaml: unsupported runs.using '${action.runs.using}'";

    inputsYaml =
      if action.inputs == {}
      then null
      else
        lib.mapAttrs (_name: input:
          filterNulls {
            inherit (input) description required default;
          })
        action.inputs;

    outputsYaml =
      if action.outputs == {}
      then null
      else
        lib.mapAttrs (_name: output: {
          inherit (output) description value;
        })
        action.outputs;
  in
    filterNulls {
      inherit (action) name description;
      inputs = inputsYaml;
      outputs = outputsYaml;
      runs = runsYaml;
    };
```

- [ ] **Step 3: Verify the converter produces correct composite YAML structure**

Run:
```bash
nix eval --impure --json --expr '
  let
    lib = (import <nixpkgs> {}).lib;
    c = import ./modules/converters.nix { inherit lib; };
  in c.actionToYaml {
    name = "Test";
    description = "d";
    inputs = {};
    outputs = {};
    runs = { using = "composite"; steps = [
      { name = "hi"; run = "echo hi"; id = null; if_ = null; uses = null; with_ = null; env = null; workingDirectory = null; shell = null; continueOnError = null; timeoutMinutes = null; }
    ]; };
  }'
```
Expected JSON: `runs.using == "composite"`, `runs.steps[0].shell == "bash"` (defaulted), `runs.steps[0].run == "echo hi"`, and `name`/`description` present.

- [ ] **Step 4: Commit**

```bash
git add modules/converters.nix
git commit -m "feat: add actionToYaml converter with shell:bash default for composite steps"
```

---

## Task 3: Add `actions` option + `actionFiles`/`actionsDir` to the module

**Files:**
- Modify: `modules/github-ci.nix`

- [ ] **Step 1: Import the action type**

In `modules/github-ci.nix`, after the workflow-type import (line 9-10), add:
```nix
  actionTypes = import ./types/action.nix {inherit lib;};
  inherit (actionTypes) actionType;
```
And add the converter to the existing `inherit (converters) ...` (line 14):
```nix
  inherit (converters) workflowToYaml actionToYaml;
```

- [ ] **Step 2: Add the `actions`, `actionFiles`, `actionsDir` options**

In the `options.githubActions` block (after `workflowFiles`, around line 77), add:
```nix
          actions = mkOption {
            type = types.attrsOf actionType;
            default = {};
            description = ''
              GitHub actions to generate. Keys are action names;
              each emits .github/actions/<name>/action.yml.
            '';
            example = literalExpression ''
              {
                setup-ci = {
                  name = "Setup CI";
                  description = "Checkout + toolchain setup";
                  runs.steps = [
                    { uses = "actions/checkout@v4"; }
                    { name = "Install"; run = "npm ci"; }
                  ];
                };
              }
            '';
          };

          actionFiles = mkOption {
            type = types.attrsOf types.package;
            readOnly = true;
            description = ''
              Individual composite action files as derivations.
              Keys are "<name>/action.yml". Only populated when enable = true.
            '';
          };

          actionsDir = mkOption {
            type = types.package;
            readOnly = true;
            description = ''
              Generated .github/actions directory as a derivation, containing
              <name>/action.yml subdirectories. Only populated when enable = true.
            '';
          };
```

- [ ] **Step 3: Generate the action files in the `config` block**

In the `config` `let` block (alongside `workflowFiles`, around line 82-100), add:
```nix
        actionFiles =
          lib.mapAttrs' (
            name: action:
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
              )
          )
          cfg.actions;
```

- [ ] **Step 4: Wire the readOnly outputs in the `config` return**

In the `config` return attrset (alongside `githubActions.workflowFiles`/`workflowsDir`, around line 102-113), add:
```nix
        githubActions.actionFiles = lib.mkIf cfg.enable actionFiles;

        githubActions.actionsDir = lib.mkIf cfg.enable (
          pkgs.runCommandLocal "github-actions-composite" {} ''
            mkdir -p $out
            ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: file: ''
                mkdir -p "$out/$(dirname ${name})"
                cp ${file} $out/${name}
              '')
              actionFiles)}
          ''
        );
```

- [ ] **Step 5: Verify the module evaluates and options exist**

Run:
```bash
nix flake check 2>&1 | tail -10
```
Expected: passes (no eval errors; new options accepted by the module system).

- [ ] **Step 6: Commit**

```bash
git add modules/github-ci.nix
git commit -m "feat: add actions option emitting composite action.yml files"
```

---

## Task 4: Non-breaking guard — capture baseline workflow output

Before exercising the new feature in an example, prove existing workflow output is unchanged.

**Files:** none (verification only)

- [ ] **Step 1: Build the basic example's workflow output BEFORE wiring actions into it**

Run:
```bash
cd examples/basic
nix build .#packages.x86_64-linux 2>/dev/null || true
# Build the generated workflows dir derivation:
nix eval --raw .#githubActions 2>/dev/null || true
cd -
```
If the examples expose `workflowsDir`, capture its hash:
```bash
nix build "$(pwd)/examples/basic#workflowsDir" --no-link --print-out-paths 2>/dev/null | tee /tmp/ghan-baseline.txt || echo "capture via example build in Task 5 instead"
```
Expected: a store path recorded as the baseline (used in Task 6 Step 2). If the basic example doesn't expose `workflowsDir` directly, defer the baseline capture to Task 6 using `git stash` of Tasks 1-3 — note that fallback in Task 6.

- [ ] **Step 2: Commit (no-op marker)**

No commit; this is a recorded baseline only.

---

## Task 5: Add a composite-action example (end-to-end exercise)

**Files:**
- Create: `examples/composite-action/flake.nix`

- [ ] **Step 1: Write the example flake**

Create `examples/composite-action/flake.nix`:
```nix
{
  description = "Composite action generation example";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    github-actions-nix.url = "path:../..";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];

      imports = [inputs.github-actions-nix.flakeModules.default];

      perSystem = {config, ...}: {
        githubActions = {
          enable = true;

          actions = {
            setup-ci = {
              name = "Setup CI";
              description = "Checkout and toolchain setup";
              inputs = {
                node-version = {
                  description = "Node version to install";
                  default = "20";
                };
              };
              outputs = {
                cache-hit = {
                  description = "Whether the cache was hit";
                  value = "\${{ steps.cache.outputs.cache-hit }}";
                };
              };
              runs.steps = [
                {uses = "actions/checkout@v4";}
                {
                  name = "Install Node";
                  uses = "actions/setup-node@v4";
                  with_.node-version = "\${{ inputs.node-version }}";
                }
                {
                  name = "Install deps";
                  id = "cache";
                  run = "npm ci";
                }
              ];
            };
          };
        };

        # Expose the generated files for inspection/build.
        packages.action-files = config.githubActions.actionsDir;
      };
    };
}
```

- [ ] **Step 2: Build the example and inspect the generated action.yml**

Run:
```bash
cd examples/composite-action
nix build .#action-files --no-link --print-out-paths
OUT=$(nix build .#action-files --no-link --print-out-paths)
cat "$OUT/setup-ci/action.yml"
cd -
```
Expected: `$OUT/setup-ci/action.yml` exists and contains:
- `runs:` with `using: composite`
- the three steps, with the `npm ci` step having `shell: bash` (defaulted)
- `inputs.node-version.default: "20"`
- `outputs.cache-hit.value: ${{ steps.cache.outputs.cache-hit }}`

- [ ] **Step 3: Assert structure with yq**

Run:
```bash
OUT=$(nix build "$(pwd)/examples/composite-action#action-files" --no-link --print-out-paths)
yq '.runs.using' "$OUT/setup-ci/action.yml"          # -> composite
yq '.runs.steps[2].shell' "$OUT/setup-ci/action.yml" # -> bash
yq '.inputs."node-version".default' "$OUT/setup-ci/action.yml" # -> "20"
yq '.outputs."cache-hit".value' "$OUT/setup-ci/action.yml"
```
Expected: `composite`, `bash`, `20`, and the output value expression.

- [ ] **Step 4: Commit**

```bash
git add examples/composite-action/flake.nix
git commit -m "docs: add composite-action generation example"
```

---

## Task 6: Verify non-breaking + finalize

**Files:**
- Modify: `README.md` (document the `actions` option)

- [ ] **Step 1: Confirm existing examples still build unchanged**

Run:
```bash
cd examples/basic && nix flake check 2>&1 | tail -5; cd -
cd examples/advanced && nix flake check 2>&1 | tail -5; cd -
```
Expected: both pass.

- [ ] **Step 2: Confirm workflow YAML output is byte-identical to baseline**

If a baseline store path was captured in Task 4:
```bash
NEW=$(nix build "$(pwd)/examples/basic#workflowsDir" --no-link --print-out-paths 2>/dev/null)
diff -r "$(cat /tmp/ghan-baseline.txt)" "$NEW" && echo "IDENTICAL"
```
Fallback if no baseline derivation was available: `git stash` the working tree, build the basic example's workflow output on `master`, `git stash pop`, rebuild, and `diff` the two `action.yml`-free workflow outputs.
Expected: `IDENTICAL` — proves `workflows` generation is unaffected (non-breaking).

- [ ] **Step 3: Document the `actions` option in README**

Add a section to `README.md` after the workflows documentation:
```markdown
## Composite Actions

Generate reusable composite actions to `.github/actions/<name>/action.yml`:

\`\`\`nix
githubActions.actions.setup-ci = {
  name = "Setup CI";
  description = "Checkout and toolchain setup";
  inputs.node-version = { description = "Node version"; default = "20"; };
  outputs.cache-hit = { description = "Cache hit"; value = "\${{ steps.cache.outputs.cache-hit }}"; };
  runs.steps = [
    { uses = "actions/checkout@v4"; }
    { name = "Install"; id = "cache"; run = "npm ci"; }  # shell defaults to bash
  ];
};
\`\`\`

`runs.using` is an enum currently supporting only `"composite"`; the discriminated
type is designed so docker / node / Nix-derivation-script kinds can be added
additively. Wire `config.githubActions.actionFiles` into your `files.files`
(the `files` flake module) so `nix run .#write-files` writes the action files.
```

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: document the actions (composite) option in README"
```

- [ ] **Step 5: Version bump + publish (minor, non-breaking)**

Confirm the publish mechanism (tag-push → FlakeHub, per `.github/workflows/ci.yml`). Determine the current version and bump the minor:
```bash
git tag --list 'v*' | sort -V | tail -3
```
Tag the next minor (e.g. if latest is `v0.3.x`, tag `v0.4.0`) on `master` after merge:
```bash
# After this branch merges to master:
git checkout master && git pull
git tag v<next-minor> && git push origin v<next-minor>
```
Expected: the FlakeHub publish CI runs on the tag; the new version appears at `https://flakehub.com/f/synapdeck/github-actions-nix`.

---

## Self-review notes

- **Spec coverage:** `actions` option → Task 3; discriminated `actionType`/enum → Task 1; `actionToYaml` + shell-default → Task 2; directory-per-action emission → Task 3; example/verification → Tasks 5-6; non-breaking guarantee → Tasks 4 + 6 Step 2; README → Task 6; extensibility (enum + dispatch) → realized in Tasks 1-2 structure. All spec sections covered.
- **Name consistency:** `actionType`, `actionToYaml`, `compositeStepToYaml`, `actions`/`actionFiles`/`actionsDir`, `runs.using`/`runs.steps` — consistent across tasks and match the spec.
- **Open item:** Task 4/6 baseline-capture has a documented fallback (`git stash` diff) in case the example doesn't expose `workflowsDir` directly — the executor picks whichever applies; either way the non-breaking diff is performed.
- **Consumer handoff:** the synapdeck cost-reduction plan consumes this via `githubActions.actions.setup-ci` + a `report-checks` action, after bumping the input to the published minor.
