# gh-coda build recipes
# Read version from VERSION file

version := `cat VERSION`

# Build the single-file gh-coda extension
build:
    #!/usr/bin/env bash
    set -euo pipefail
    VERSION="{{ version }}"
    {
      echo '#!/usr/bin/env bash'
      echo 'set -e'
      echo ''
      echo '# gh-coda - built from lib/*.sh'
      echo "# Version: $VERSION"
      echo '# Do not edit directly; modify lib/*.sh and run: just build'
      echo ''
      cat lib/helpers.sh
      echo ''
      cat lib/repo.sh
      echo ''
      cat lib/config.sh
      echo ''
      cat lib/settings.sh
      echo ''
      cat lib/secrets.sh
      echo ''
      cat lib/commands.sh | sed "s/@@VERSION@@/$VERSION/g"
      echo ''
      echo 'main "$@"'
    } > gh-coda
    chmod +x gh-coda
    echo "built: gh-coda v$VERSION"

# Run tests
test:
    shellspec --no-kcov --format progress

# Coverage
cov:
    shellspec

# Lint shell scripts
lint:
    shellcheck lib/*.sh

# Run tests with verbose output
test-verbose:
    shellspec --no-kcov --format documentation

# Check dependencies
check-deps:
    @command -v yj >/dev/null || echo "missing: yj (brew install yj)"
    @command -v jq >/dev/null || echo "missing: jq (brew install jq)"
    @command -v gh >/dev/null || echo "missing: gh (brew install gh)"
    @command -v op >/dev/null || echo "missing: op (1Password CLI)"
    @command -v shellspec >/dev/null || echo "missing: shellspec (brew install shellspec)"
    @echo "dependency check complete"

# Install the extension locally
install: build
    mkdir -p ~/.local/bin
    cp gh-coda ~/.local/bin/
    @echo "installed to ~/.local/bin/gh-coda"

# Clean build artifacts
clean:
    rm -f gh-coda

# Show current version
show-version:
    @echo "{{ version }}"

# Verify conventional commits (useful before bump)
check-commits:
    cog check

# Preview what version bump would do
bump-dry-run:
    cog bump --auto --dry-run

# Bump version using conventional commits (auto-calculates from commit history)

# Use: just release (auto) or just release --minor (force minor bump)
release *args:
    cog bump {{ args }}
