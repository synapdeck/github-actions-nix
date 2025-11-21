# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Nix flake that provides a flake-parts module for generating GitHub Actions workflow files from type-safe Nix configuration. It converts Nix attribute sets into YAML workflow files that can be committed to `.github/workflows/`.

## Development Commands

### Formatting
```bash
nix fmt
```
Formats all Nix files using alejandra formatter.

### Development Shell
```bash
nix develop
```
Provides a shell with development tools and automatically installs git hooks via `hk`.

Available tools:
- Core: `yq-go`, `hk`
- Nix formatters/linters: `alejandra`, `deadnix`, `statix`
- GitHub Actions linter: `actionlint`
- Configuration formatters: `pkl`, `prettier`

Git hooks are automatically installed on shell entry and will run:
- **pre-commit**: Auto-format and lint with stashing of unstaged changes
- **pre-push**: Check-only mode for all linters
- Manual commands: `hk check`, `hk fix`

### Testing Workflow Generation
```bash
# Evaluate the workflows directory to see generated files
nix eval .#githubActions.workflowsDir --raw

# Build example workflows
cd examples/basic
nix build .#workflows
# Generated workflows will be in result/.github/workflows/
```

## Architecture

The module system is split into multiple focused files for better organization:

### Main Module (`modules/github-ci.nix`)

Entry point that ties everything together:
- Imports type definitions from `modules/types/workflow.nix`
- Imports conversion functions from `modules/converters.nix`
- Defines flake-parts perSystem options:
  - `githubActions.enable`: Enable/disable workflow generation
  - `githubActions.workflows`: Attribute set of workflow definitions
  - `githubActions.workflowsDir`: Read-only output containing all generated workflow files
  - `githubActions.workflowFiles`: Read-only output with individual workflow files
- Uses `yq-go` to convert JSON to pretty-printed YAML with automatic header comment

### Type Definitions (`modules/types/`)

Comprehensive type system that mirrors GitHub Actions YAML schema:

**`step.nix`** - Individual workflow steps:
- `stepType`: Defines step options (name, id, run, uses, with_, env, etc.)
- Handles both action-based steps (`uses`) and shell command steps (`run`)

**`job.nix`** - Job configurations:
- `jobType`: Job definitions with steps, strategy, permissions, container, services, etc.
- `strategyType`: Matrix build configurations with fail-fast and max-parallel options
- `permissionsType`: GITHUB_TOKEN permissions (either "read-all"/"write-all" or granular)

**`workflow.nix`** - Complete workflows and triggers:
- `workflowType`: Top-level workflow with name, triggers, jobs, and global settings
- Trigger types: `pushTriggerType`, `pullRequestTriggerType`, `scheduleTriggerType`, `workflowDispatchType`
- Supports workflow defaults for both run commands and job settings

### Conversion Functions (`modules/converters.nix`)

Transforms Nix structures to YAML-compatible format:
- `filterNulls`: Removes null values from attribute sets
- `stepToYaml`: Converts step configuration, handling special fields like `if_` → `if`, `with_` → `with`
- `jobToYaml`: Converts job configuration with strategy and permissions
- `triggerToYaml`: Handles both simple list format and detailed trigger configuration
- `applyJobDefaults`: Applies workflow-level defaults to individual jobs
- `workflowToYaml`: Top-level workflow conversion that orchestrates all other converters

### Flake Structure (`flake.nix`)

- Exports two module paths: `flakeModules.default` and `flakeModules.githubActions` (both point to same module)
- Supports four system architectures: x86_64-linux, aarch64-linux, x86_64-darwin, aarch64-darwin
- Uses **flake-parts partitions** to isolate development dependencies:
  - Main flake has minimal inputs: `nixpkgs`, `flake-parts`
  - Development tools (`hk` and linters) are in `dev/` partition
  - Consumers won't see development dependencies in their lock files

### Development Partition (`dev/`)

Development inputs and configuration are isolated in a separate partition to avoid polluting consumers' lock files:

**`dev/flake.nix`**: Contains development-only inputs
- `hk` for git hooks management
- `nixpkgs` (follows main flake's nixpkgs)

**`dev/flake-module.nix`**: Defines the development shell
- All development tools (formatters, linters, etc.)
- `shellHook` that automatically runs `hk install` on shell entry

**`hk.pkl`**: Git hooks configuration
- Configures pre-commit, pre-push, check, and fix hooks
- Defines which linters to run and in what mode

This partition setup ensures that when other projects use this flake as an input, they only get the essential dependencies (nixpkgs, flake-parts) in their lock file, not the ~400+ development dependencies from `hk` and Rust toolchain.

## Important Implementation Details

### Nix-to-YAML Field Mapping

Several Nix field names differ from their YAML equivalents to avoid conflicts with Nix keywords:
- `if_` → `if`
- `with_` → `with`
- `pull_request` uses `pullRequest` in Nix
- `workflow_dispatch` uses `workflowDispatch` in Nix
- Hyphenated YAML fields use camelCase in Nix (e.g., `runsOn` → `runs-on`, `continueOnError` → `continue-on-error`)

### Workflow Generation Process

1. User defines workflows in `githubActions.workflows` attribute set
2. Each workflow is validated against `workflowType`
3. `workflowToYaml` converts Nix structure to JSON-compatible format
4. `runCommand` derivations execute `yq-go` to convert JSON to formatted YAML
5. Individual files are combined into `workflowsDir` derivation
6. Users copy from `workflowsDir` to `.github/workflows/` in their repository

### Examples

Two complete examples in `examples/`:
- `basic/`: Simple CI workflow with build and lint jobs
- `advanced/`: Matrix builds, release workflows with job dependencies and outputs, scheduled workflows

Both examples create a `packages.workflows` derivation that can be built with `nix build .#workflows` to generate the workflow files.

## Common Workflows

When modifying development tools or shell configuration:
1. Edit `dev/flake-module.nix` to add/remove packages or modify shellHook
2. Edit `hk.pkl` to configure git hooks behavior
3. Update `dev/flake.nix` only if adding new development inputs
4. After modifying `dev/flake.nix`, run `cd dev && nix flake lock` to update the dev lock file
5. Test with `nix develop` to ensure hooks install correctly

When adding new workflow features:
1. Add type definition in the appropriate module under `modules/types/`:
   - Step-level options → `modules/types/step.nix`
   - Job-level options → `modules/types/job.nix`
   - Workflow-level options or triggers → `modules/types/workflow.nix`
2. Update corresponding `*ToYaml` conversion function in `modules/converters.nix` to handle the new field
3. Ensure proper null filtering with `filterNulls`
4. If adding a new type file, import it in the appropriate dependent module
5. Test with both basic and advanced examples

When debugging workflow generation:
1. Check the JSON output: `nix eval .#githubActions.workflows.<name> --json`
2. Verify the YAML conversion manually with yq-go
3. Compare against examples/ for working patterns
4. If types aren't being recognized, check the import chain:
   - `step.nix` ← imported by `job.nix`
   - `job.nix` ← imported by `workflow.nix`
   - `workflow.nix` and `converters.nix` ← imported by `github-ci.nix`
