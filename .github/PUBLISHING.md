# Publishing Guide

This project uses [cocogitto](https://docs.cocogitto.io/) for automated versioning and releases following the semantic-release pattern.

## How Releases Work

Releases are **fully automated**. When you merge a PR to `main`:

1. CI runs tests, linting, and commit validation
2. If tests pass, CI checks for releasable commits (feat/fix) since the last tag
3. If found, `cog bump --auto` creates a version commit + tag
4. The tag push triggers the release workflow
5. GitHub Release is created with the built `gh-coda` artifact

**You don't need to run any release commands locally.** Just write conventional commits and merge.

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

### 2. Verify commits are valid (optional)

```bash
just check-commits
# or
cog check
```

### 3. Create a PR and merge

That's it. CI handles the rest.

## What Triggers a Release?

A release is created when **all** of these are true:

- Push to `main` branch (not a PR)
- All CI checks pass (tests, lint, commit validation)
- At least one `feat` or `fix` commit exists since the last tag

Commits like `docs`, `chore`, `ci`, `test` do **not** trigger releases on their own.

## Manual Release (Rare)

If you need to force a release locally (e.g., first release, or CI is broken):

```bash
# Preview what would happen
just bump-dry-run

# Create release (auto-calculated version)
just release --auto

# Force a specific bump type
just release --minor
just release --major
just release --patch
```

## Troubleshooting

### Release didn't happen after merge

Check if you have releasable commits:

```bash
cog log  # Shows commits since last tag
```

If only `docs`, `chore`, `ci`, or `test` commits exist, no release is created. To force one:

```bash
just release --patch
```

### "No commits to bump"

You haven't made any bumpable commits (feat/fix) since the last tag. Either:
- Add a feature or fix commit
- Force a release: `just release --patch`

### Invalid commit messages

The commit-msg hook should catch these locally. If they slip through:

```bash
# See which commits are invalid
cog check

# Fix with interactive rebase
git rebase -i HEAD~3
```

### Wrong version released

```bash
# Delete the local and remote tag
git tag -d v0.2.0
git push origin :refs/tags/v0.2.0

# Reset to before the bump commit
git reset --hard HEAD~1
git push --force-with-lease

# CI will re-run and create the correct release
```

## Configuration Reference

See `cog.toml` in the repo root. Key settings:

```toml
tag_prefix = "v"                    # Tags are v0.1.0, v0.2.0, etc.
branch_whitelist = ["main"]         # Only bump from main

pre_bump_hooks = [                  # Run before version commit
    "echo {{version}} > VERSION",
    "just test",
    "just build",
    "git add VERSION",
]

post_bump_hooks = [                 # Run after tag created
    "git push",
    "git push origin {{version}}",
]
```

## Quick Reference

```bash
# Check commits are valid
just check-commits

# Preview what release would do
just bump-dry-run

# Show current version
just show-version

# Manual release (rarely needed)
just release --auto
```
