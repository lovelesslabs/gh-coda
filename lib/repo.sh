# repo.sh - Repository resolution and info

# Returns repo as "OWNER/REPO" on stdout
# Returns non-zero if it cannot determine
resolve_repo() {
  if [[ -n "${GH_REPO:-}" ]]; then
    printf '%s\n' "$GH_REPO"
    return 0
  fi

  local out rc
  out="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>&1)" || rc=$?
  rc="${rc:-0}"

  if (( rc == 0 )); then
    printf '%s\n' "$out"
    return 0
  fi

  if [[ "$out" == *"fatal: not a git repository"* ]]; then
    die "not in a git repo (and GH_REPO not set)"
  fi

  if [[ "$out" == *"no git remotes found"* ]]; then
    die "git repo has no remotes; push/add a GitHub remote or set GH_REPO"
  fi

  die "failed to resolve repo (gh rc=$rc): $out"
}

# Returns "private" or "public"
get_repo_visibility() {
  local repo="${1:-}"
  [[ -n "$repo" ]] || repo="$(resolve_repo)"
  gh repo view "$repo" --json isPrivate -q 'if .isPrivate then "private" else "public" end'
}
