# commands.sh - Subcommands and main entry point
# shellcheck disable=SC2154
# CONFIG_JSON is set by load_config() in config.sh (files are concatenated at build)

# Version (replaced during build)
VERSION="@@VERSION@@"

# Default config template
DEFAULT_CONFIG='# gh-coda config
# See: https://github.com/claylo/gh-coda

# Merge settings
auto_merge: true
delete_branch_on_merge: true
allow_squash_merge: true
allow_merge_commit: false
allow_rebase_merge: true

# Features
enable_discussions: false
enable_projects: false
enable_wiki: false

# Security
enable_secret_scanning: true
enable_secret_scanning_push_protection: true
dependabot_alerts: true
dependabot_security_updates: true

# 1Password secrets sync (optional)
# secrets_tags: github-actions
# secrets_app: actions
'

cmd_init() {
  local config_path="" output_path="$PWD/.github/coda.yml" force="false"

  # Parse args
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c|--config) config_path="${2:-}"; shift 2 ;;
      -o|--output) output_path="${2:-}"; shift 2 ;;
      -f|--force) force="true"; shift ;;
      -*)
        die "unknown option: $1"
        ;;
      *)
        shift
        ;;
    esac
  done

  # Check if output already exists
  if [[ -f "$output_path" && "$force" != "true" ]]; then
    die "config already exists: $output_path (use --force to overwrite)"
  fi

  # If no config specified, try to find one (but not the output path itself)
  if [[ -z "$config_path" ]]; then
    config_path="$(find_config 2>/dev/null || true)"
    # Don't copy a file to itself
    if [[ -n "$config_path" ]]; then
      local real_config real_output
      real_config="$(cd "$(dirname "$config_path")" && pwd)/$(basename "$config_path")"
      real_output="$(cd "$(dirname "$output_path")" 2>/dev/null && pwd)/$(basename "$output_path")" 2>/dev/null || real_output="$output_path"
      [[ "$real_config" == "$real_output" ]] && config_path=""
    fi
  fi

  # Ensure parent directory exists (e.g., .github/)
  local output_dir
  output_dir="$(dirname "$output_path")"
  [[ -d "$output_dir" ]] || mkdir -p "$output_dir"

  if [[ -n "$config_path" && -f "$config_path" ]]; then
    # Copy existing config
    cp "$config_path" "$output_path"
    log "copied $config_path -> $output_path"
  else
    # Write default config
    printf '%s' "$DEFAULT_CONFIG" > "$output_path"
    log "created $output_path with defaults"
  fi

  log ""
  log "edit $output_path to customize, then run: gh coda"
}

cmd_status() {
  local repo="" config_path

  # Parse --repo flag
  local args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -R|--repo) repo="${2:-}"; shift 2 ;;
      *) args+=("$1"); shift ;;
    esac
  done
  set -- ${args[@]+"${args[@]}"}

  [[ -n "$repo" ]] || repo="$(resolve_repo)"
  config_path="$(find_config "$@" || true)"

  log "repo: $repo"
  log "visibility: $(get_repo_visibility "$repo")"

  if [[ -z "$config_path" ]]; then
    log "config: (none found)"
    return 0
  fi

  log "config: $config_path"
  need_cmd yj
  load_config "$config_path"

  log ""
  log "configured settings:"
  printf '%s' "$CONFIG_JSON" | jq -r 'to_entries[] | "  \(.key): \(.value)"'
}

cmd_setup() {
  need_cmd yj
  need_cmd jq
  need_cmd gh

  local repo="" config_path

  # Parse --repo flag, pass rest to find_config
  local args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -R|--repo) repo="${2:-}"; shift 2 ;;
      *) args+=("$1"); shift ;;
    esac
  done
  set -- ${args[@]+"${args[@]}"}

  config_path="$(find_config "$@")" || die "no config file found"

  [[ -n "$repo" ]] || repo="$(resolve_repo)"
  log "repo: $repo"
  log "config: $config_path"

  load_config "$config_path"

  apply_repo_edit_settings "$repo"
  apply_api_settings "$repo"
  apply_branch_protection "$repo"
  apply_rulesets "$repo"
  apply_environments "$repo"
  apply_pages "$repo"

  # Run set-secrets if secrets_tags is configured
  if config_has "secrets_tags"; then
    cmd_set_secrets --repo "$repo" "$@"
  fi

  log "setup complete."
}

usage() {
  cat <<'EOF'
gh coda: one more thing... for repositories

Usage:
  gh coda [SUBCOMMAND] [OPTIONS]

Subcommands:
  setup        Apply all settings from config (default)
  init         Create a .github/coda.yml config file
  set-secrets  Sync secrets from 1Password to GitHub
  status       Show current repo settings vs. config

Options:
  -R, --repo <owner/repo>   Target repository (default: current repo)
  -c, --config <path>       Path to config file (overrides discovery)
  -h, --help                Show this help
  -v, --version             Show version

Config Discovery (in priority order):
  1. -c/--config flag
  2. GH_CODA_CONFIG environment variable
  3. .github/coda.yml or .github/coda.yaml
  4. Walk up from $PWD for [.]coda.private.yml or [.]coda.public.yml
  5. ~/.config/gh-coda/private.yml or public.yml

Config Format (YAML):
  auto_merge: true
  delete_branch_on_merge: true
  enable_discussions: true
  dependabot_alerts: true
  secrets_tags: github-actions,release

EOF
}

main() {
  case "${1:-}" in
    setup)
      shift
      cmd_setup "$@"
      ;;
    init)
      shift
      cmd_init "$@"
      ;;
    set-secrets)
      shift
      cmd_set_secrets "$@"
      ;;
    status)
      shift
      cmd_status "$@"
      ;;
    -h|--help|help)
      usage
      ;;
    -v|--version|version)
      echo "gh-coda $VERSION"
      ;;
    -*)
      # Flag passed directly, assume setup
      cmd_setup "$@"
      ;;
    "")
      # No args, run setup
      cmd_setup "$@"
      ;;
    *)
      die "unknown command: $1 (try 'gh coda --help')"
      ;;
  esac
}
