# settings.sh - Apply repo settings
# shellcheck disable=SC2154
# CONFIG_JSON is set by load_config() in config.sh (files are concatenated at build)

# apply_branch_protection <repo>
# Applies branch protection rules from config
apply_branch_protection() {
  local repo="$1"

  # Check if branches config exists
  if ! printf '%s' "$CONFIG_JSON" | jq -e '.branches' >/dev/null 2>&1; then
    return 0
  fi

  local branches
  branches="$(printf '%s' "$CONFIG_JSON" | jq -r '.branches | keys[]')"

  for branch in $branches; do
    log "configuring branch protection for: $branch"

    local branch_config
    branch_config="$(printf '%s' "$CONFIG_JSON" | jq -c ".branches[\"$branch\"]")"

    # Build the protection payload
    local payload='{}'

    # Required status checks
    if printf '%s' "$branch_config" | jq -e '.required_status_checks' >/dev/null 2>&1; then
      local strict checks_array
      strict="$(printf '%s' "$branch_config" | jq -r '.required_status_checks.strict // false')"

      # Build contexts array from checks
      if printf '%s' "$branch_config" | jq -e '.required_status_checks.checks' >/dev/null 2>&1; then
        checks_array="$(printf '%s' "$branch_config" | jq -c '[.required_status_checks.checks[] | .context]')"
      else
        checks_array='[]'
      fi

      payload="$(printf '%s' "$payload" | jq -c --argjson strict "$strict" --argjson contexts "$checks_array" '.required_status_checks = {strict: $strict, contexts: $contexts}')"
    else
      payload="$(printf '%s' "$payload" | jq -c '.required_status_checks = null')"
    fi

    # Required pull request reviews
    if printf '%s' "$branch_config" | jq -e '.required_reviews' >/dev/null 2>&1; then
      local reviews_obj='{}'
      local count dismiss_stale code_owners

      count="$(printf '%s' "$branch_config" | jq -r '.required_reviews.count // 0')"
      dismiss_stale="$(printf '%s' "$branch_config" | jq -r '.required_reviews.dismiss_stale // false')"
      code_owners="$(printf '%s' "$branch_config" | jq -r '.required_reviews.require_code_owners // false')"

      reviews_obj="$(printf '%s' "$reviews_obj" | jq -c \
        --argjson count "$count" \
        --argjson dismiss "$dismiss_stale" \
        --argjson owners "$code_owners" \
        '.required_approving_review_count = $count | .dismiss_stale_reviews = $dismiss | .require_code_owner_reviews = $owners')"

      payload="$(printf '%s' "$payload" | jq -c --argjson reviews "$reviews_obj" '.required_pull_request_reviews = $reviews')"
    else
      # Default: no reviews required
      payload="$(printf '%s' "$payload" | jq -c '.required_pull_request_reviews = {required_approving_review_count: 0}')"
    fi

    # Enforce admins
    local enforce_admins
    enforce_admins="$(printf '%s' "$branch_config" | jq -r '.enforce_admins // false')"
    payload="$(printf '%s' "$payload" | jq -c --argjson val "$enforce_admins" '.enforce_admins = $val')"

    # Restrictions (who can push) - null means no restrictions
    if printf '%s' "$branch_config" | jq -e '.restrictions' >/dev/null 2>&1; then
      local restrictions
      restrictions="$(printf '%s' "$branch_config" | jq -c '.restrictions')"
      payload="$(printf '%s' "$payload" | jq -c --argjson val "$restrictions" '.restrictions = $val')"
    else
      payload="$(printf '%s' "$payload" | jq -c '.restrictions = null')"
    fi

    # Boolean flags with defaults
    local allow_force allow_delete linear_history
    allow_force="$(printf '%s' "$branch_config" | jq -r '.allow_force_pushes // false')"
    allow_delete="$(printf '%s' "$branch_config" | jq -r '.allow_deletions // false')"
    linear_history="$(printf '%s' "$branch_config" | jq -r '.required_linear_history // false')"

    payload="$(printf '%s' "$payload" | jq -c \
      --argjson force "$allow_force" \
      --argjson delete "$allow_delete" \
      --argjson linear "$linear_history" \
      '.allow_force_pushes = $force | .allow_deletions = $delete | .required_linear_history = $linear')"

    # Additional options
    local conversation_resolution lock_branch allow_fork_syncing
    conversation_resolution="$(printf '%s' "$branch_config" | jq -r '.required_conversation_resolution // false')"
    lock_branch="$(printf '%s' "$branch_config" | jq -r '.lock_branch // false')"
    allow_fork_syncing="$(printf '%s' "$branch_config" | jq -r '.allow_fork_syncing // false')"

    payload="$(printf '%s' "$payload" | jq -c \
      --argjson conv "$conversation_resolution" \
      --argjson lock "$lock_branch" \
      --argjson fork "$allow_fork_syncing" \
      '.required_conversation_resolution = $conv | .lock_branch = $lock | .allow_fork_syncing = $fork')"

    # Apply the protection
    printf '%s' "$payload" | gh api --method PUT "/repos/$repo/branches/$branch/protection" --input - >/dev/null 2>&1 \
      || log "  warning: failed to set protection for $branch (branch may not exist or insufficient permissions)"
  done
}

# apply_rulesets <repo>
# Applies repository rulesets from config
apply_rulesets() {
  local repo="$1"

  # Check if rulesets config exists
  if ! printf '%s' "$CONFIG_JSON" | jq -e '.rulesets' >/dev/null 2>&1; then
    return 0
  fi

  local rulesets
  rulesets="$(printf '%s' "$CONFIG_JSON" | jq -c '.rulesets[]')"

  echo "$rulesets" | while read -r ruleset_config; do
    local name
    name="$(printf '%s' "$ruleset_config" | jq -r '.name')"
    [[ -n "$name" && "$name" != "null" ]] || continue

    log "configuring ruleset: $name"

    # Check if ruleset already exists
    local existing_id
    existing_id="$(gh api "/repos/$repo/rulesets" 2>/dev/null | jq -r ".[] | select(.name == \"$name\") | .id" || true)"

    # Build the ruleset payload
    local payload
    payload="$(printf '%s' "$ruleset_config" | jq -c '{
      name: .name,
      target: (.target // "branch"),
      enforcement: (.enforcement // "active"),
      conditions: (.conditions // {ref_name: {include: ["~DEFAULT_BRANCH"], exclude: []}}),
      rules: (.rules // [])
    }')"

    if [[ -n "$existing_id" && "$existing_id" != "null" ]]; then
      # Update existing ruleset
      printf '%s' "$payload" | gh api --method PUT "/repos/$repo/rulesets/$existing_id" --input - >/dev/null 2>&1 \
        || log "  warning: failed to update ruleset $name"
    else
      # Create new ruleset
      printf '%s' "$payload" | gh api --method POST "/repos/$repo/rulesets" --input - >/dev/null 2>&1 \
        || log "  warning: failed to create ruleset $name"
    fi
  done
}

# apply_environments <repo>
# Configures deployment environments
apply_environments() {
  local repo="$1"

  # Check if environments config exists
  if ! printf '%s' "$CONFIG_JSON" | jq -e '.environments' >/dev/null 2>&1; then
    return 0
  fi

  local env_names
  env_names="$(printf '%s' "$CONFIG_JSON" | jq -r '.environments | keys[]')"

  for env_name in $env_names; do
    log "configuring environment: $env_name"

    local env_config
    env_config="$(printf '%s' "$CONFIG_JSON" | jq -c ".environments[\"$env_name\"]")"

    # Build the environment payload
    local payload='{}'

    # Wait timer (delay before deployment)
    local wait_timer
    wait_timer="$(printf '%s' "$env_config" | jq -r '.wait_timer // 0')"
    payload="$(printf '%s' "$payload" | jq -c --argjson val "$wait_timer" '.wait_timer = $val')"

    # Reviewers
    if printf '%s' "$env_config" | jq -e '.reviewers' >/dev/null 2>&1; then
      local reviewers
      reviewers="$(printf '%s' "$env_config" | jq -c '.reviewers')"
      payload="$(printf '%s' "$payload" | jq -c --argjson val "$reviewers" '.reviewers = $val')"
    fi

    # Deployment branch policy
    if printf '%s' "$env_config" | jq -e '.deployment_branch_policy' >/dev/null 2>&1; then
      local policy
      policy="$(printf '%s' "$env_config" | jq -c '.deployment_branch_policy')"
      payload="$(printf '%s' "$payload" | jq -c --argjson val "$policy" '.deployment_branch_policy = $val')"
    fi

    # Apply the environment
    printf '%s' "$payload" | gh api --method PUT "/repos/$repo/environments/$env_name" --input - >/dev/null 2>&1 \
      || log "  warning: failed to configure environment $env_name"
  done
}

# apply_pages <repo>
# Configures GitHub Pages
apply_pages() {
  local repo="$1"

  # Check if pages config exists
  if ! printf '%s' "$CONFIG_JSON" | jq -e '.pages' >/dev/null 2>&1; then
    return 0
  fi

  local pages_config
  pages_config="$(printf '%s' "$CONFIG_JSON" | jq -c '.pages')"

  # Check if pages should be enabled (use explicit check to handle false correctly)
  local enabled
  enabled="$(printf '%s' "$pages_config" | jq -r 'if has("enabled") then .enabled else true end')"

  if [[ "$enabled" == "false" ]]; then
    log "disabling GitHub Pages..."
    gh api --method DELETE "/repos/$repo/pages" 2>/dev/null || true
    return 0
  fi

  log "configuring GitHub Pages..."

  # Build the pages payload
  local payload='{}'

  # Build type: workflow or legacy
  local build_type
  build_type="$(printf '%s' "$pages_config" | jq -r '.build_type // "workflow"')"
  payload="$(printf '%s' "$payload" | jq -c --arg val "$build_type" '.build_type = $val')"

  # Source branch and path (for legacy builds)
  if [[ "$build_type" == "legacy" ]]; then
    local branch path
    branch="$(printf '%s' "$pages_config" | jq -r '.source.branch // "main"')"
    path="$(printf '%s' "$pages_config" | jq -r '.source.path // "/"')"
    payload="$(printf '%s' "$payload" | jq -c --arg branch "$branch" --arg path "$path" '.source = {branch: $branch, path: $path}')"
  fi

  # Check if pages is already enabled
  if gh api "/repos/$repo/pages" >/dev/null 2>&1; then
    # Update existing
    printf '%s' "$payload" | gh api --method PUT "/repos/$repo/pages" --input - >/dev/null 2>&1 \
      || log "  warning: failed to update GitHub Pages"
  else
    # Enable pages
    printf '%s' "$payload" | gh api --method POST "/repos/$repo/pages" --input - >/dev/null 2>&1 \
      || log "  warning: failed to enable GitHub Pages"
  fi

  # HTTPS enforcement
  local https_enforced
  https_enforced="$(printf '%s' "$pages_config" | jq -r '.https_enforced // true')"
  if [[ "$https_enforced" == "true" ]]; then
    gh api --method PUT "/repos/$repo/pages" -f https_enforced=true >/dev/null 2>&1 || true
  fi

  # Custom domain
  local cname
  cname="$(printf '%s' "$pages_config" | jq -r '.cname // empty')"
  if [[ -n "$cname" ]]; then
    gh api --method PUT "/repos/$repo/pages" -f cname="$cname" >/dev/null 2>&1 \
      || log "  warning: failed to set custom domain"
  fi
}

# apply_repo_edit_settings <repo>
# Applies settings that can be set via `gh repo edit`
apply_repo_edit_settings() {
  local repo="$1"
  local args=()

  # Helper to add enable/disable flag
  add_bool_flag() {
    local config_key="$1" flag_name="$2"
    if config_has "$config_key"; then
      if config_bool "$config_key"; then
        args+=("--enable-$flag_name")
      else
        # disable equivalent
        args+=("--enable-${flag_name}=false")
      fi
    fi
  }

  # Boolean settings with enable/disable flags
  add_bool_flag auto_merge "auto-merge"
  add_bool_flag allow_squash_merge "squash-merge"
  add_bool_flag allow_merge_commit "merge-commit"
  add_bool_flag allow_rebase_merge "rebase-merge"
  add_bool_flag enable_discussions "discussions"
  add_bool_flag enable_projects "projects"
  add_bool_flag enable_wiki "wiki"
  add_bool_flag enable_secret_scanning "secret-scanning"
  add_bool_flag enable_secret_scanning_push_protection "secret-scanning-push-protection"

  # Description (string value, not boolean)
  if config_has "description"; then
    local desc
    desc="$(config_get description)"
    if [[ -n "$desc" ]]; then
      args+=("--description" "$desc")
    fi
  fi

  # Special case: delete_branch_on_merge uses different flag format
  if config_has "delete_branch_on_merge"; then
    if config_bool "delete_branch_on_merge"; then
      args+=("--delete-branch-on-merge")
    else
      args+=("--delete-branch-on-merge=false")
    fi
  fi

  if (( ${#args[@]} > 0 )); then
    log "applying repo edit settings..."
    gh repo edit "$repo" "${args[@]}"
  fi
}

# apply_api_settings <repo>
# Applies settings that require direct API calls
apply_api_settings() {
  local repo="$1"

  # Dependabot vulnerability alerts
  if config_has "dependabot_alerts"; then
    if config_bool "dependabot_alerts"; then
      log "enabling dependabot alerts..."
      gh api --method PUT "/repos/$repo/vulnerability-alerts" 2>/dev/null || true
    else
      log "disabling dependabot alerts..."
      gh api --method DELETE "/repos/$repo/vulnerability-alerts" 2>/dev/null || true
    fi
  fi

  # Dependabot security updates (automated security fixes)
  if config_has "dependabot_security_updates"; then
    if config_bool "dependabot_security_updates"; then
      log "enabling dependabot security updates..."
      gh api --method PUT "/repos/$repo/automated-security-fixes" 2>/dev/null || true
    else
      log "disabling dependabot security updates..."
      gh api --method DELETE "/repos/$repo/automated-security-fixes" 2>/dev/null || true
    fi
  fi
}

# apply_topics <repo>
# Sets repository topics (replaces all topics atomically)
apply_topics() {
  local repo="$1"

  if ! printf '%s' "$CONFIG_JSON" | jq -e '.topics' >/dev/null 2>&1; then
    return 0
  fi

  log "setting repository topics..."

  local payload
  payload="$(printf '%s' "$CONFIG_JSON" | jq -c '{names: [.topics[] | tostring]}')"

  printf '%s' "$payload" | gh api --method PUT "/repos/$repo/topics" --input - >/dev/null 2>&1 \
    || log "  warning: failed to set repository topics"
}

# apply_variables <repo>
# Sets GitHub Actions variables from config
apply_variables() {
  local repo="$1"

  if ! printf '%s' "$CONFIG_JSON" | jq -e '.variables' >/dev/null 2>&1; then
    return 0
  fi

  log "setting repository variables..."

  local keys
  keys="$(printf '%s' "$CONFIG_JSON" | jq -r '.variables | keys[]')"

  for key in $keys; do
    local value
    value="$(printf '%s' "$CONFIG_JSON" | jq -r ".variables[\"$key\"] | tostring")"
    gh variable set "$key" --body "$value" --repo "$repo" >/dev/null 2>&1 \
      || log "  warning: failed to set variable $key"
  done
}
