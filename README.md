# github-actions-nix

Generate GitHub Actions workflows from Nix configuration using a type-safe, declarative approach.

## Features

- **Type-safe**: Full type checking for GitHub Actions workflow configuration
- **Declarative**: Define workflows in Nix alongside your project configuration
- **Composable**: Leverage Nix's powerful module system
- **Version controlled**: Workflows are generated from Nix, making changes reviewable
- **Flake-parts integration**: Works seamlessly with flake-parts-based projects

## Quick Start

### 1. Add to your flake inputs

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    github-actions-nix.url = "github:YOUR_USERNAME/github-actions-nix";
  };
}
```

### 2. Import the module

```nix
outputs = inputs @ {flake-parts, ...}:
  flake-parts.lib.mkFlake {inherit inputs;} {
    imports = [
      inputs.github-actions-nix.flakeModules.default
    ];

    perSystem = {config, ...}: {
      # Your configuration here
    };
  };
```

### 3. Define workflows

```nix
perSystem = {config, pkgs, ...}: {
  githubActions = {
    enable = true;

    workflows.ci = {
      name = "CI";

      on = {
        push.branches = ["main"];
        pullRequest = {};
      };

      jobs.build = {
        runsOn = "ubuntu-latest";

        steps = [
          {
            name = "Checkout";
            uses = "actions/checkout@v4";
          }
          {
            name = "Build";
            run = "nix build";
          }
        ];
      };
    };
  };
};
```

### 4. Generate workflows

The workflows are available in `config.githubActions.workflowsDir`. You can:

**Option A: Copy to your repository**

```bash
cp -r $(nix eval .#githubActions.workflowsDir --raw)/* .github/workflows/
```

**Option B: Create a package to copy workflows**

```nix
packages.workflows = pkgs.runCommand "copy-workflows" {} ''
  mkdir -p $out/.github/workflows
  cp -r ${config.githubActions.workflowsDir}/* $out/.github/workflows/
'';
```

Then run:
```bash
nix build .#workflows
cp -r result/.github/workflows .github/
```

## Configuration Reference

### Workflow Options

```nix
workflows.<name> = {
  name = "Workflow Name";              # Required: Display name

  on = [...];                          # Required: Trigger events (see below)

  jobs = {...};                        # Required: Jobs to run (see below)

  env = {...};                         # Optional: Environment variables

  permissions = {...};                 # Optional: GITHUB_TOKEN permissions

  concurrency = {...};                 # Optional: Concurrency control

  defaults = {...};                    # Optional: Default settings
};
```

### Trigger Events

**Simple list:**
```nix
on = ["push" "pull_request"];
```

**Detailed configuration:**
```nix
on = {
  push = {
    branches = ["main" "develop"];
    paths = ["src/**"];
  };

  pullRequest = {
    branches = ["main"];
    types = ["opened" "synchronize"];
  };

  schedule = [
    {cron = "0 0 * * *";}              # Daily at midnight
  ];

  workflowDispatch = {
    inputs = {
      version = {
        description = "Version to release";
        required = true;
        type = "string";
      };
    };
  };
};
```

### Job Configuration

```nix
jobs.<job-id> = {
  name = "Job Name";                   # Optional: Display name

  runsOn = "ubuntu-latest";            # Required: Runner type

  needs = ["other-job"];               # Optional: Job dependencies

  if_ = "github.event_name == 'push'"; # Optional: Conditional

  steps = [...];                       # Required: Steps to run

  env = {...};                         # Optional: Environment variables

  strategy = {...};                    # Optional: Matrix strategy

  permissions = {...};                 # Optional: Job-level permissions

  outputs = {...};                     # Optional: Job outputs

  timeoutMinutes = 30;                 # Optional: Job timeout

  continueOnError = false;             # Optional: Continue on error
};
```

### Step Configuration

```nix
steps = [
  # Action step
  {
    name = "Checkout";
    uses = "actions/checkout@v4";
    with_ = {
      fetch-depth = 0;
    };
  }

  # Command step
  {
    name = "Build";
    run = "npm run build";
    workingDirectory = "./packages/app";
    env = {
      NODE_ENV = "production";
    };
  }

  # Conditional step
  {
    name = "Deploy";
    run = "npm run deploy";
    if_ = "github.ref == 'refs/heads/main'";
  }

  # Step with ID for outputs
  {
    id = "version";
    name = "Get version";
    run = ''
      echo "version=$(cat VERSION)" >> $GITHUB_OUTPUT
    '';
  }
];
```

### Matrix Strategy

```nix
strategy = {
  matrix = {
    os = ["ubuntu-latest" "macos-latest" "windows-latest"];
    node-version = ["18" "20" "22"];
  };
  failFast = false;
  maxParallel = 6;
};
```

Use matrix values in your configuration with `${{ matrix.KEY }}`:
```nix
runsOn = "${{ matrix.os }}";
```

### Permissions

**Grant all permissions:**
```nix
permissions = "write-all";  # or "read-all"
```

**Granular permissions:**
```nix
permissions = {
  contents = "read";
  pull-requests = "write";
  issues = "write";
};
```

### Concurrency

**Simple group:**
```nix
concurrency = "ci-${{ github.ref }}";
```

**With cancel-in-progress:**
```nix
concurrency = {
  group = "ci-${{ github.ref }}";
  cancelInProgress = true;
};
```

## Examples

See the `examples/` directory for complete examples:

- [`examples/basic/`](examples/basic/) - Basic CI workflow
- [`examples/advanced/`](examples/advanced/) - Matrix builds, releases, and scheduled workflows

## Module Options

### `githubActions.enable`

Type: `bool`
Default: `false`

Whether to enable GitHub Actions workflow generation.

### `githubActions.workflows`

Type: `attrsOf workflowType`
Default: `{}`

GitHub Actions workflows to generate. Keys are workflow file names (without `.yml` extension).

### `githubActions.workflowsDir` (read-only)

Type: `package`

Generated `.github/workflows` directory as a derivation containing all workflow files.

### `githubActions.workflowFiles` (read-only)

Type: `attrsOf package`

Individual workflow files as derivations. Keys are workflow names (without `.yml` extension).

## Development

Enter the development shell:

```bash
nix develop
```

Format Nix files:

```bash
nix fmt
```

## License

MIT

## Contributing

Contributions welcome! Please open an issue or PR.
