# gh-coda

GitHub CLI extension for applying repository settings from config files.

## Architecture

Single-file bash extension built from modular sources in `lib/`:

| Module | Purpose |
|--------|---------|
| `helpers.sh` | Utilities: `log()`, `die()`, `need_cmd()` |
| `repo.sh` | Repo resolution: `resolve_repo()`, `get_repo_visibility()` |
| `config.sh` | Config discovery/parsing: `find_config()`, `load_config()`, `config_get()`, `config_bool()`, `config_has()` |
| `settings.sh` | Apply settings via `gh repo edit` and GitHub API |
| `secrets.sh` | 1Password to GitHub secrets sync |
| `commands.sh` | CLI commands: `cmd_init`, `cmd_status`, `cmd_setup`, `main()` |

Build concatenates lib modules into single `gh-coda` executable.

## Config Discovery

Config files are discovered in this priority order:

1. `-c/--config` flag
2. `GH_CODA_CONFIG` environment variable
3. `.github/coda.yml` or `.github/coda.yaml` (repo-level)
4. Walk up from `$PWD` for `[.]coda.private.yml` or `[.]coda.public.yml`
5. `~/.config/gh-coda/private.yml` or `public.yml`

### Naming Conventions

- `.yml` and `.yaml` extensions both supported
- Visibility-specific: both dotted (`.coda.private.yml`) and non-dotted (`coda.private.yml`)
- Dotted variant takes priority over non-dotted in same directory

## Development

```bash
just build        # Build from lib/*.sh
just test         # Run shellspec tests
just lint         # Run shellcheck
just check-deps   # Verify dependencies
```

## Testing

Tests use [ShellSpec](https://shellspec.info/) in `spec/`:

- Tests mock external commands (`gh`, `op`, `yj`) via `spec/support/mocks.sh`
- Each spec loads only needed modules via `_load_*` helpers
- Temp dirs created/cleaned per test via `spec_helper_setup/cleanup`

### Writing Tests

```bash
# shellcheck shell=bash
Describe 'Feature name'
  Include spec/spec_helper.sh

  setup() {
    _load_config  # Load module and dependencies
    gh() { mock_gh "$@"; }  # Override external commands
  }

  BeforeEach 'setup'

  It 'does something'
    When call function_under_test "arg"
    The status should be success
    The output should include "expected"
  End
End
```

### Mock Variables

Control mock behavior with environment variables:
- `MOCK_GH_REPO` - Repo name returned by `gh repo view`
- `MOCK_GH_REPO_PRIVATE` - Set to 1 for private repo
- `MOCK_GH_REPO_VIEW_FAIL` - Set to 1 to simulate failure
- `MOCK_OP_SIGNED_IN` - Set to 0 for unsigned 1Password
- `MOCK_OP_ITEMS` - JSON array for `op item list`
- `MOCK_OP_ITEM` - JSON object for `op item get`
- `MOCK_YJ_OUTPUT` - Override yj conversion output

### Test File Conventions

- `spec/*_spec.sh` - Test files
- Name tests after module: `config_spec.sh`, `settings_spec.sh`
- Test groups via `Describe` blocks
- `When call` for success-expected calls, `When run` for failure-expected
