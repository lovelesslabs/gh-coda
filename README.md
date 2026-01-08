# gh-coda

> *one more thing...* for repositories

A GitHub CLI extension that applies your preferred repository settings from a config file. Stop clicking through repo settings manually—define them once, apply them everywhere.

## Installation

```bash
gh ext install claylo/gh-coda
```

### Dependencies

- [yj](https://github.com/sclevine/yj) — YAML to JSON converter (`brew install yj`)
- [jq](https://jqlang.github.io/jq/) — JSON processor (`brew install jq`)
- [1Password CLI](https://developer.1password.com/docs/cli/) — for `set-secrets` command (optional)

## Quick Start

1. Create a config file:

```yaml
# ~/.config/gh-coda/public.conf
auto_merge: true
delete_branch_on_merge: true
allow_squash_merge: true
allow_merge_commit: false
enable_discussions: true
enable_secret_scanning: true
dependabot_alerts: true
```

2. Run it:

```bash
cd your-repo
gh coda
```

That's it. Your repo now has all those settings applied.

## Usage

```
gh coda [SUBCOMMAND] [OPTIONS]

Subcommands:
  setup        Apply all settings from config (default)
  init         Create a .gh-coda config file in current directory
  set-secrets  Sync secrets from 1Password to GitHub
  status       Show current repo settings vs. config

Options:
  -R, --repo <owner/repo>   Target repository (default: current repo)
  -c, --config <path>       Path to config file (overrides discovery)
  -h, --help                Show this help
```

## Config Discovery

gh-coda finds your config in this order:

1. `-c/--config` flag
2. `GH_CODA_CONFIG` environment variable
3. `.gh-coda` in current directory
4. Walk up directory tree for `.gh-coda.private` or `.gh-coda.public` (based on repo visibility)
5. `~/.config/gh-coda/private.conf` or `public.conf`

This layered approach lets you have different defaults for:
- **Personal repos** → `~/.config/gh-coda/private.conf`
- **Open source projects** → `~/.config/gh-coda/public.conf`
- **Work repos** → `/path/to/work/.gh-coda.private`
- **Specific project** → `./project/.gh-coda`

## GitHub Token Scopes

gh-coda uses the `gh` CLI, which authenticates via `gh auth login`. Different features require different token scopes:

| Feature | Required Scope | Notes |
|---------|---------------|-------|
| Repo settings (`gh repo edit`) | `repo` | All merge, wiki, project, discussion settings |
| Secret scanning | `repo` | Free for public repos; requires [GitHub Advanced Security](https://docs.github.com/en/get-started/learning-about-github/about-github-advanced-security) for private repos |
| Dependabot alerts | `repo`, `security_events` | Requires repo admin; via API |
| Dependabot security updates | `repo`, `security_events` | Requires repo admin; via API |
| Branch protection | `repo` | Requires repo admin; via API |
| Repository rulesets | `repo` | Requires repo admin; via API |
| Environments | `repo` | Requires repo admin; via API |
| GitHub Pages | `repo` | Requires repo admin; via API |
| Repository secrets | `repo` | For Actions, Dependabot, or Codespaces secrets |
| Organization secrets | `admin:org` | When using `--org` with `set-secrets` |

### Checking your scopes

```bash
gh auth status
```

### Minimum recommended scopes

For basic repo settings only:

```bash
gh auth login --scopes repo
```

For full functionality (including Dependabot alerts/security updates):

```bash
gh auth login --scopes repo,security_events
```

If you also manage organization secrets:

```bash
gh auth login --scopes repo,security_events,admin:org
```

## Available Settings

### Via `gh repo edit`

| Config Key | Description |
|------------|-------------|
| `auto_merge` | Enable/disable auto-merge for PRs |
| `delete_branch_on_merge` | Delete head branch after merge |
| `allow_squash_merge` | Allow squash merging |
| `allow_merge_commit` | Allow merge commits |
| `allow_rebase_merge` | Allow rebase merging |
| `enable_discussions` | Enable GitHub Discussions |
| `enable_projects` | Enable GitHub Projects |
| `enable_wiki` | Enable wiki |
| `enable_secret_scanning` | Enable secret scanning |
| `enable_secret_scanning_push_protection` | Block pushes containing secrets |

### Via GitHub API

| Config Key | Description |
|------------|-------------|
| `dependabot_alerts` | Enable Dependabot vulnerability alerts |
| `dependabot_security_updates` | Enable Dependabot security updates |

### Branch Protection & Rulesets

GitHub offers two ways to protect branches: **Branch Protection Rules** (legacy) and **Repository Rulesets** (newer, more flexible). gh-coda supports both.

| Feature | Branch Protection | Rulesets |
|---------|------------------|----------|
| Scope | Single branch pattern | Multiple patterns, include/exclude |
| Bypass | Admins only toggle | Fine-grained bypass permissions |
| Status checks | Basic | More granular control |
| Org-level | No | Yes (with org rulesets) |
| API | Older, stable | Newer, more options |

**Recommendation**: Use **rulesets** for new projects. Use **branch protection** if you need compatibility with older tooling or have existing rules.

[Learn more about the differences →](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)

#### Branch Protection (legacy)

```yaml
branches:
  main:
    required_status_checks:
      strict: true                    # Require branch to be up to date
      checks:
        - context: ci/build
        - context: ci/test
    required_reviews:
      count: 1                        # Number of approvals (default: 0)
      dismiss_stale: true             # Dismiss approvals on new commits
      require_code_owners: true       # Require CODEOWNERS approval
    enforce_admins: false             # Apply rules to admins too
    allow_force_pushes: false
    allow_deletions: false
    required_linear_history: true     # Require linear history (no merge commits)
    required_conversation_resolution: true
    lock_branch: false                # Make branch read-only
    allow_fork_syncing: false
    restrictions:                     # Who can push (null = no restrictions)
      users: []
      teams: []
```

#### Repository Rulesets (recommended)

```yaml
rulesets:
  - name: Protect main branch
    target: branch                    # branch or tag
    enforcement: active               # active, evaluate, or disabled
    conditions:
      ref_name:
        include:
          - "~DEFAULT_BRANCH"         # or: refs/heads/main, refs/heads/release/*
        exclude: []
    rules:
      - type: pull_request
        parameters:
          required_approving_review_count: 1
          dismiss_stale_reviews_on_push: true
          require_code_owner_review: true
      - type: required_status_checks
        parameters:
          strict_required_status_checks_policy: true
          required_status_checks:
            - context: ci/build
            - context: ci/test
      - type: non_fast_forward        # Prevent force pushes
      - type: deletion                # Prevent branch deletion
      - type: required_linear_history
```

All branch protection and ruleset settings require **repo admin** permissions.

### Deployment Environments

Configure deployment environments with approval requirements and branch policies:

```yaml
environments:
  production:
    wait_timer: 30                    # Minutes to wait before deployment (0-43200)
    reviewers:
      - type: User
        id: 12345                     # GitHub user ID
      - type: Team
        id: 67890                     # GitHub team ID
    deployment_branch_policy:
      protected_branches: true        # Only allow protected branches
      custom_branch_policies: false   # Or use custom patterns below
  staging:
    wait_timer: 0
    deployment_branch_policy:
      protected_branches: false
      custom_branch_policies: true
```

To find user/team IDs:
```bash
# User ID
gh api users/USERNAME -q '.id'
# Team ID (org required)
gh api orgs/ORG/teams/TEAM-SLUG -q '.id'
```

### GitHub Pages

Configure GitHub Pages deployment:

```yaml
pages:
  enabled: true                       # Set to false to disable Pages
  build_type: workflow                # workflow (Actions) or legacy (branch deploy)
  https_enforced: true                # Enforce HTTPS
  cname: docs.example.com             # Custom domain (optional)

  # For legacy builds only:
  source:
    branch: main                      # Branch to deploy from
    path: /docs                       # Path within branch (/ or /docs)
```

**Build types:**
- `workflow` — Deploy via GitHub Actions (recommended). Create a workflow that publishes to the `github-pages` environment.
- `legacy` — Deploy directly from a branch. Specify `source.branch` and `source.path`.

## 1Password Integration

Sync secrets from 1Password to GitHub Actions:

```yaml
# In your .gh-coda config
secrets_tags: github-actions,deploy
secrets_app: actions  # or: dependabot, codespaces
```

Then run:
```bash
gh coda set-secrets
```

Or specify tags directly:
```bash
gh coda set-secrets --tags github-actions,release
```

### How it works

1. Finds 1Password items with the specified tags
2. Extracts the secret value (looks for fields: `credential`, `password`, `token`, or first concealed field)
3. Sets it as a GitHub secret (name derived from item title, or override with `gh_secret_name` field)

## Examples

```bash
# Initialize a new config with defaults
gh coda init

# Initialize from an existing config
gh coda init -c ~/.config/gh-coda/public.conf

# Apply settings to current repo
gh coda

# Check what would change
gh coda status

# Apply to a different repo
gh coda -R myorg/other-repo

# Use a specific config
gh coda -c ./my-config.yaml

# Just sync secrets
gh coda set-secrets --tags ci-secrets
```

## Development

```bash
# Run tests
just test

# Build the extension
just build

# Check dependencies
just check-deps

# Verify conventional commits
just check-commits
```

### Releasing

This project uses [cocogitto](https://docs.cocogitto.io/) for conventional commits and automated versioning.

```bash
# Preview what the next version would be
just bump-dry-run

# Create a release (auto-calculates version from commits)
just release --auto

# Or force a specific bump type
just release --minor
```

The release process:
1. Calculates next version from commit history (feat→minor, fix→patch)
2. Updates `VERSION` file
3. Runs tests and rebuilds
4. Generates `CHANGELOG.md`
5. Creates version commit and tag
6. Pushes to origin (triggers GitHub release workflow)

## License

MIT
