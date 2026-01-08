# secrets.sh - 1Password to GitHub secrets sync

normalize_secret_name() {
  local s="$1"
  s="$(printf '%s' "$s" | tr '[:lower:]' '[:upper:]')"
  s="$(printf '%s' "$s" | sed -E 's/[^A-Z0-9_]+/_/g; s/_+/_/g; s/^_+//; s/_+$//')"
  printf '%s' "$s"
}

op_ensure_signed_in() {
  if op whoami >/dev/null 2>&1; then
    return 0
  fi

  local accounts_json account_count acct
  accounts_json="$(NO_COLOR=1 op account list --format json 2>/dev/null || true)"
  account_count="$(printf '%s' "$accounts_json" | jq -r 'length' 2>/dev/null || echo 0)"

  if [[ "$account_count" == "1" ]]; then
    acct="$(printf '%s' "$accounts_json" | jq -r '.[0].shorthand // .[0].user_uuid // empty')"
    [[ -n "$acct" ]] || die "op not signed in and couldn't determine account shorthand"
    log "op: signing in (single account detected)..."
    eval "$(op signin --account "$acct")"
    op whoami >/dev/null 2>&1 || die "op signin failed"
    return 0
  fi

  die "op is not signed in. Run: op signin, then re-run."
}

# cmd_set_secrets [--tags TAG,TAG] [NAME]
cmd_set_secrets() {
  need_cmd op
  need_cmd jq

  local tags_csv="" name="" repo="" app="actions" vault="" force_field="" dry_run="false" verbose="false"

  # Get tags from config if available
  if [[ -n "$CONFIG_JSON" ]]; then
    tags_csv="$(config_get secrets_tags)"
    app="$(config_get secrets_app actions)"
  fi

  # Parse args
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tags) tags_csv="${2:-}"; shift 2 ;;
      --app) app="${2:-}"; shift 2 ;;
      --repo) repo="${2:-}"; shift 2 ;;
      --vault) vault="${2:-}"; shift 2 ;;
      --field) force_field="${2:-}"; shift 2 ;;
      --dry-run) dry_run="true"; shift ;;
      --verbose) verbose="true"; shift ;;
      -c|--config) shift 2 ;;  # Skip config flag, handled elsewhere
      -*)
        die "unknown option: $1"
        ;;
      *)
        name="$1"; shift
        ;;
    esac
  done

  [[ -n "$tags_csv" ]] || die "no tags specified (use --tags or set secrets_tags in config)"

  # Resolve repo
  [[ -n "$repo" ]] || repo="$(resolve_repo)"

  op_ensure_signed_in

  IFS=',' read -r -a tags <<< "$tags_csv"

  if [[ "$verbose" == "true" ]]; then
    log "tags: ${tags[*]}"
    [[ -n "$name" ]] && log "name filter: $name"
    log "repo target: $repo"
  fi

  # Build item list
  local items_json
  items_json="$(
    for t in "${tags[@]}"; do
      [[ -n "$t" ]] || continue
      if [[ -n "$vault" ]]; then
        NO_COLOR=1 op item list --tags "$t" --vault "$vault" --format json
      else
        NO_COLOR=1 op item list --tags "$t" --format json
      fi
    done | jq -s 'add | unique_by(.id)'
  )"

  # Filter by name if provided
  if [[ -n "$name" ]]; then
    local match_count
    match_count="$(printf '%s' "$items_json" | jq -r --arg name "$name" '[.[] | select(.title == $name)] | length')"
    [[ "$match_count" == "1" ]] || die "expected exactly 1 match for name '$name'; found $match_count"
    items_json="$(printf '%s' "$items_json" | jq -c --arg name "$name" '[.[] | select(.title == $name)]')"
  fi

  local count
  count="$(printf '%s' "$items_json" | jq -r 'length')"
  [[ "$count" != "0" ]] || die "no 1Password items found for tag(s): $tags_csv"

  # jq program to extract secret value
  local JQ_EXTRACT JQ_FORCED_FIELD
  read -r -d '' JQ_EXTRACT <<'JQ' || true
def all_fields:
  [.. | objects | select(has("label") and has("value")) | {label: .label, value: .value, purpose: (.purpose // ""), type: (.type // .fieldType // "")}];

def field_by_label($lbl):
  (all_fields | map(select(.label == $lbl)) | .[0].value) // empty;

def best_value:
  field_by_label("credential")
  // field_by_label("password")
  // field_by_label("token")
  // (all_fields | map(select(.purpose == "PASSWORD")) | .[0].value // empty)
  // (all_fields | map(select((.type|tostring) == "CONCEALED")) | .[0].value // empty)
  // (all_fields | .[0].value // empty);

{
  secret_name_override: (field_by_label("gh_secret_name") // empty),
  secret_value: best_value
}
JQ

  read -r -d '' JQ_FORCED_FIELD <<'JQ' || true
def all_fields:
  [.. | objects | select(has("label") and has("value")) | {label: .label, value: .value}];
def field_by_label($lbl):
  (all_fields | map(select(.label == $lbl)) | .[0].value) // empty;
{
  secret_name_override: (field_by_label("gh_secret_name") // empty),
  secret_value: field_by_label($field)
}
JQ

  local gh_target_args=(--repo "$repo" --app "$app")
  local secrets_set=0

  printf '%s' "$items_json" | jq -c '.[]' | while read -r item; do
    local item_id item_title default_secret_name
    item_id="$(printf '%s' "$item" | jq -r '.id')"
    item_title="$(printf '%s' "$item" | jq -r '.title')"
    default_secret_name="$(normalize_secret_name "$item_title")"

    if [[ "$dry_run" == "true" ]]; then
      log "would set: $default_secret_name (from item: $item_title)"
      continue
    fi

    [[ "$verbose" == "true" ]] && log "fetching item: $item_title ($item_id)"

    local extracted
    if [[ -n "$force_field" ]]; then
      extracted="$(NO_COLOR=1 op item get "$item_id" --format json | jq -r --arg field "$force_field" "$JQ_FORCED_FIELD")"
    else
      extracted="$(NO_COLOR=1 op item get "$item_id" --format json | jq -r "$JQ_EXTRACT")"
    fi

    local secret_name_override secret_value secret_name
    secret_name_override="$(printf '%s' "$extracted" | jq -r '.secret_name_override // empty')"
    secret_value="$(printf '%s' "$extracted" | jq -r '.secret_value // empty')"

    secret_name="$default_secret_name"
    [[ -n "$secret_name_override" ]] && secret_name="$(normalize_secret_name "$secret_name_override")"

    [[ -n "$secret_value" ]] || die "no secret value found in item '$item_title' (use --field to force a label)"

    [[ "$verbose" == "true" ]] && log "setting secret: $secret_name (item: $item_title)"

    printf '%s' "$secret_value" | gh secret set "$secret_name" "${gh_target_args[@]}"
    (( secrets_set++ )) || true
  done

  log "done. set $count secret(s)."
}
