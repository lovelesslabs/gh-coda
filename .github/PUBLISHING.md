# Publishing Guide

This project uses [cocogitto](https://docs.cocogitto.io/) for versioning and releases.

## Prerequisites

```bash
# Install cocogitto
brew install cocogitto

# Or via cargo
cargo binstall cocogitto
```

## Conventional Commits

All commits must follow the [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Commit Types

| Type | Version Bump | Description |
|------|--------------|-------------|
| `feat` | MINOR | New feature |
| `fix` | PATCH | Bug fix |
| `docs` | - | Documentation only |
| `style` | - | Formatting, no code change |
| `refactor` | - | Code change that neither fixes a bug nor adds a feature |
| `perf` | PATCH | Performance improvement |
| `test` | - | Adding/updating tests |
| `build` | - | Build system or dependencies |
| `ci` | - | CI configuration |
| `chore` | - | Other changes |

### Breaking Changes

For MAJOR version bumps, add `BREAKING CHANGE:` in the footer or `!` after the type:

```bash
feat!: remove deprecated config option

# or

feat: change config format

BREAKING CHANGE: config files must now use YAML 1.2 syntax
```

## Daily Workflow

### 1. Write conventional commits

```bash
git commit -m "feat: add environment configuration support"
git commit -m "fix: handle missing config file gracefully"
git commit -m "docs: update README with new options"
```

### 2. Verify commits are valid

```bash
just check-commits
# or
cog check
```

### 3. Preview the next version

```bash
just bump-dry-run
# or
cog bump --auto --dry-run
```

## Creating a Release

### Auto-calculated version (recommended)

```bash
just release --auto
```

This will:
1. Calculate version from commits since last tag (feat→minor, fix→patch)
2. Update `VERSION` file
3. Run tests (`just test`)
4. Rebuild (`just build`)
5. Generate/update `CHANGELOG.md`
6. Create version commit with `[skip ci]`
7. Create git tag (e.g., `v0.2.0`)
8. Push commit and tag to origin
9. GitHub Actions creates the release with built artifact

### Force a specific bump

```bash
# Force minor bump regardless of commits
just release --minor

# Force major bump
just release --major

# Force patch bump
just release --patch
```

### Set a specific version

```bash
cog bump --version 1.0.0
```

## What Happens on Push

### On push to `main` or PR:
- CI runs tests
- CI runs ShellCheck on `lib/*.sh`
- CI verifies conventional commits

### On push of `v*` tag:
- Release workflow runs tests
- Builds `gh-coda` with embedded version
- Creates GitHub Release with the built script attached

## Troubleshooting

### "No commits to bump"

You haven't made any bumpable commits (feat/fix) since the last tag:

```bash
# Check what commits exist since last tag
cog log

# Force a patch bump anyway
just release --patch
```

### "Uncommitted changes"

Cocogitto won't bump with a dirty working tree:

```bash
git status
git add -A && git commit -m "chore: cleanup"
just release --auto
```

### Invalid commit messages

Fix with an interactive rebase:

```bash
# See which commits are invalid
cog check

# Rebase and reword
git rebase -i HEAD~3
```

Or use cocogitto to rewrite:

```bash
cog edit
```

### Wrong version released

If you need to redo a release:

```bash
# Delete the local and remote tag
git tag -d v0.2.0
git push origin :refs/tags/v0.2.0

# Reset to before the bump commit
git reset --hard HEAD~1

# Try again
just release --auto
```

## Configuration Reference

See `cog.toml` in the repo root for all settings. Key options:

```toml
tag_prefix = "v"                    # Tags are v0.1.0, v0.2.0, etc.
branch_whitelist = ["main"]         # Only bump from main
skip_ci = "[skip ci]"               # Added to bump commits

pre_bump_hooks = [                  # Run before version commit
    "echo {{version}} > VERSION",   # Update VERSION file
    "just test",                    # Run tests
    "just build",                   # Rebuild with new version
    "git add VERSION",              # Stage VERSION for commit
]

post_bump_hooks = [                 # Run after tag created
    "git push",                     # Push commit
    "git push origin {{version}}",  # Push tag
]
```

## Quick Reference

```bash
# Check commits are valid
just check-commits

# Preview version bump
just bump-dry-run

# Release (auto version)
just release --auto

# Release (force minor)
just release --minor

# Show current version
just show-version
```
