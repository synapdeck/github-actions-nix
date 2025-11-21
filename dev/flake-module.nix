{inputs, ...}: {
  perSystem = {
    system,
    pkgs,
    ...
  }: {
    devShells.default = pkgs.mkShell {
      packages = with pkgs; [
        # Core tools
        yq-go
        inputs.hk.packages.${system}.default

        # Nix formatters and linters
        alejandra
        deadnix
        statix

        # GitHub Actions linter
        actionlint

        # Configuration formatters
        pkl

        # Commit message linters
        gitlint
      ];

      shellHook = ''
        # Ensure git hooks are installed (skip in worktrees)
        if [ -d .git ]; then
          if ! output=$(hk install 2>&1); then
            exit_code=$?
            echo "$output" >&2
            exit $exit_code
          fi
        fi
      '';
    };
  };
}
