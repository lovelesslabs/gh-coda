# Contributing to gh-coda

Thanks for your interest in contributing! This document will help you get started.

## Quick Links

- [Issue Templates](https://github.com/claylo/gh-coda/issues/new/choose)
- [Discussions](https://github.com/claylo/gh-coda/discussions)
- [Publishing Guide](.github/PUBLISHING.md)

## Development Setup

### Prerequisites

```bash
# Required
brew install yj jq gh

# For testing
brew install shellspec

# For releases
brew install cocogitto
```

### Clone and Test

```bash
git clone https://github.com/claylo/gh-coda.git
cd gh-coda
just test          # Run tests
just build         # Build the extension
just check-deps    # Verify all dependencies
```

### Project Structure

```
gh-coda/
├── lib/              # Source modules (edit these)
│   ├── helpers.sh    # Logging, error handling
│   ├── repo.sh       # Repo resolution, visibility
│   ├── config.sh     # Config discovery and loading
│   ├── settings.sh   # Apply repo settings
│   ├── secrets.sh    # 1Password integration
│   └── commands.sh   # Subcommands and main()
├── spec/             # ShellSpec tests
│   ├── spec_helper.sh
│   ├── support/mocks.sh
│   └── *_spec.sh
├── gh-coda           # Built executable (gitignored)
├── VERSION           # Current version
└── cog.toml          # Cocogitto config
```

## Making Changes

### 1. Create a branch

```bash
git checkout -b feat/my-feature
# or
git checkout -b fix/the-bug
```

### 2. Write code

Edit files in `lib/`. The `gh-coda` executable is built from these modules.

### 3. Add tests

Tests go in `spec/`. We use [ShellSpec](https://shellspec.info/) for BDD-style testing.

```bash
# Run all tests
just test

# Run specific test file
shellspec spec/config_spec.sh

# Verbose output
just test-verbose
```

### 4. Build and verify

```bash
just build
./gh-coda --version
./gh-coda --help
```

### 5. Commit with conventional commits

We use [Conventional Commits](https://www.conventionalcommits.org/). Your commit messages determine version bumps:

| Prefix | Version Bump | Example |
|--------|--------------|---------|
| `feat:` | Minor | `feat: add environment support` |
| `fix:` | Patch | `fix: handle missing config` |
| `docs:` | None | `docs: update README` |
| `refactor:` | None | `refactor: simplify config loading` |
| `test:` | None | `test: add branch protection specs` |
| `chore:` | None | `chore: update dependencies` |

For breaking changes, add `!` or a `BREAKING CHANGE:` footer:

```bash
feat!: change config format
```

Verify your commits:

```bash
just check-commits
```

### 6. Open a PR

- PR titles must also follow conventional commit format (enforced by CI)
- Fill out the PR template
- Ensure CI passes

## Code Style

- Follow existing patterns in the codebase
- Use `log` for user-facing output (to stderr)
- Use `die` for fatal errors
- Prefer `printf '%s'` over `echo` for portability
- Quote variables: `"$var"` not `$var`
- Use `[[ ]]` for conditionals (bash)

## Testing Guidelines

- Mock external commands (`gh`, `op`, `yj`) - see `spec/support/mocks.sh`
- Test both success and failure cases
- Use descriptive test names

Example:

```bash
Describe 'my_function()'
  It 'returns success when config exists'
    # setup
    When call my_function "arg"
    The status should be success
    The output should include "expected"
  End
End
```

## Questions?

- Open a [Discussion](https://github.com/claylo/gh-coda/discussions) for questions
- Check existing [Issues](https://github.com/claylo/gh-coda/issues) before filing a bug
- See [PUBLISHING.md](.github/PUBLISHING.md) for release process details
