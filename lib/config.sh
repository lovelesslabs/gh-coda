# config.sh - Config discovery and loading

# Global: CONFIG_JSON is set by load_config() and used by other modules
CONFIG_JSON=""

# find_config [OPTIONS]
#
# Finds and outputs the path to the config file.
# Priority:
#   1. -c/--config <path>
#   2. GH_CODA_CONFIG env var
#   3. $PWD/.github/coda.yml or coda.yaml (repo-level config)
#   4. Walk up from $PWD for [.]coda.private.yml/yaml or [.]coda.public.yml/yaml
#   5. ~/.config/gh-coda/private.yml/yaml or public.yml/yaml
#
# Returns 0 and prints path if found, returns 1 if no config found.
find_config() {
  local config_path="" visibility=""

  # Parse args for -c/--config
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c|--config)
        config_path="${2:-}"
        shift 2 || die "-c/--config requires an argument"
        ;;
      *)
        shift
        ;;
    esac
  done

  # Priority 1: -c/--config flag
  if [[ -n "$config_path" ]]; then
    if [[ -f "$config_path" ]]; then
      printf '%s\n' "$config_path"
      return 0
    else
      die "config file not found: $config_path"
    fi
  fi

  # Priority 2: GH_CODA_CONFIG env var
  if [[ -n "${GH_CODA_CONFIG:-}" ]]; then
    if [[ -f "$GH_CODA_CONFIG" ]]; then
      printf '%s\n' "$GH_CODA_CONFIG"
      return 0
    else
      die "GH_CODA_CONFIG file not found: $GH_CODA_CONFIG"
    fi
  fi

  # Priority 3: $PWD/.github/coda.yml or coda.yaml (repo-level config)
  if [[ -f "$PWD/.github/coda.yml" ]]; then
    printf '%s\n' "$PWD/.github/coda.yml"
    return 0
  fi
  if [[ -f "$PWD/.github/coda.yaml" ]]; then
    printf '%s\n' "$PWD/.github/coda.yaml"
    return 0
  fi

  # For priority 4 & 5, we need to know repo visibility
  visibility="$(get_repo_visibility 2>/dev/null || echo "")"

  # Priority 4: Walk up from $PWD for [.]coda.private.yml/yaml or [.]coda.public.yml/yaml
  # Checks both dotted (.coda.private.yml) and non-dotted (coda.private.yml) variants
  if [[ -n "$visibility" ]]; then
    local dir="$PWD"

    while [[ "$dir" != "/" ]]; do
      # Check dotted variants first (takes priority)
      if [[ -f "$dir/.coda.$visibility.yml" ]]; then
        printf '%s\n' "$dir/.coda.$visibility.yml"
        return 0
      fi
      if [[ -f "$dir/.coda.$visibility.yaml" ]]; then
        printf '%s\n' "$dir/.coda.$visibility.yaml"
        return 0
      fi
      # Then non-dotted variants
      if [[ -f "$dir/coda.$visibility.yml" ]]; then
        printf '%s\n' "$dir/coda.$visibility.yml"
        return 0
      fi
      if [[ -f "$dir/coda.$visibility.yaml" ]]; then
        printf '%s\n' "$dir/coda.$visibility.yaml"
        return 0
      fi
      dir="$(dirname "$dir")"
    done

    # Check root (both variants)
    if [[ -f "/.coda.$visibility.yml" ]]; then
      printf '%s\n' "/.coda.$visibility.yml"
      return 0
    fi
    if [[ -f "/.coda.$visibility.yaml" ]]; then
      printf '%s\n' "/.coda.$visibility.yaml"
      return 0
    fi
    if [[ -f "/coda.$visibility.yml" ]]; then
      printf '%s\n' "/coda.$visibility.yml"
      return 0
    fi
    if [[ -f "/coda.$visibility.yaml" ]]; then
      printf '%s\n' "/coda.$visibility.yaml"
      return 0
    fi

    # Priority 5: ~/.config/gh-coda/private.yml/yaml or public.yml/yaml
    if [[ -f "$HOME/.config/gh-coda/$visibility.yml" ]]; then
      printf '%s\n' "$HOME/.config/gh-coda/$visibility.yml"
      return 0
    fi
    if [[ -f "$HOME/.config/gh-coda/$visibility.yaml" ]]; then
      printf '%s\n' "$HOME/.config/gh-coda/$visibility.yaml"
      return 0
    fi
  fi

  # No config found
  return 1
}

# Global to hold parsed config
CONFIG_JSON=""

# load_config <path>
# Converts YAML to JSON and stores in CONFIG_JSON global
load_config() {
  local path="$1"
  [[ -f "$path" ]] || die "config file not found: $path"
  CONFIG_JSON="$(yj < "$path")" || die "failed to parse config: $path"
}

# config_get <key> [default]
# Gets a value from CONFIG_JSON
config_get() {
  local key="$1" default="${2:-}"
  local val
  val="$(printf '%s' "$CONFIG_JSON" | jq -r ".$key // empty")"
  if [[ -z "$val" ]]; then
    printf '%s' "$default"
  else
    printf '%s' "$val"
  fi
}

# config_bool <key>
# Returns 0 if key is true, 1 otherwise
config_bool() {
  local key="$1"
  local val
  val="$(printf '%s' "$CONFIG_JSON" | jq -r ".$key // false")"
  [[ "$val" == "true" ]]
}

# config_has <key>
# Returns 0 if key exists in config
config_has() {
  local key="$1"
  printf '%s' "$CONFIG_JSON" | jq -e "has(\"$key\")" >/dev/null 2>&1
}
