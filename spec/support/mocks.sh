# shellcheck shell=bash
# Mock implementations for external commands

# Mock gh command
# Set MOCK_GH_* variables to control behavior
mock_gh() {
  case "$1" in
    repo)
      case "$2" in
        view)
          if [[ "${MOCK_GH_REPO_VIEW_FAIL:-}" == "1" ]]; then
            echo "error: repository not found" >&2
            return 1
          fi
          # Parse --json and -q args
          local json_fields="" jq_query=""
          shift 2
          while [[ $# -gt 0 ]]; do
            case "$1" in
              --json) json_fields="$2"; shift 2 ;;
              -q) jq_query="$2"; shift 2 ;;
              *) shift ;;
            esac
          done
          # Return mock data based on requested fields
          local is_private="false"
          [[ "${MOCK_GH_REPO_PRIVATE:-}" == "1" ]] && is_private="true"

          if [[ "$json_fields" == "nameWithOwner" ]]; then
            if [[ -n "$jq_query" ]]; then
              echo "${MOCK_GH_REPO:-owner/repo}"
            else
              echo '{"nameWithOwner":"'"${MOCK_GH_REPO:-owner/repo}"'"}'
            fi
          elif [[ "$json_fields" == "isPrivate" ]]; then
            if [[ -n "$jq_query" ]]; then
              # Simulate jq: 'if .isPrivate then "private" else "public" end'
              if [[ "$is_private" == "true" ]]; then
                echo "private"
              else
                echo "public"
              fi
            else
              echo '{"isPrivate":'"$is_private"'}'
            fi
          else
            echo '{"nameWithOwner":"'"${MOCK_GH_REPO:-owner/repo}"'","isPrivate":'"$is_private"'}'
          fi
          ;;
        edit)
          # Record the edit call for verification
          echo "gh repo edit $*" >> "${TEST_TMPDIR:-/tmp}/gh_calls.log"
          ;;
      esac
      ;;
    secret)
      case "$2" in
        set)
          # Record the secret set call
          echo "gh secret set $*" >> "${TEST_TMPDIR:-/tmp}/gh_calls.log"
          ;;
      esac
      ;;
    api)
      # Record API calls with any stdin input
      local input=""
      if [[ "$*" == *"--input"* ]]; then
        input="$(cat)"
      fi
      echo "gh api $* $input" >> "${TEST_TMPDIR:-/tmp}/gh_calls.log"
      ;;
  esac
}

# Mock yj command (YAML to JSON)
mock_yj() {
  # Just pass through to cat - tests should provide JSON directly
  # or set MOCK_YJ_OUTPUT
  if [[ -n "${MOCK_YJ_OUTPUT:-}" ]]; then
    echo "$MOCK_YJ_OUTPUT"
  else
    cat
  fi
}

# Mock op command
# Note: Avoid ${var:-{}} syntax as bash has parsing quirks with literal braces
mock_op() {
  local _default_obj='{}'
  local _default_arr='[]'
  case "$1" in
    whoami)
      if [[ "${MOCK_OP_SIGNED_IN:-1}" == "1" ]]; then
        echo "signed in"
        return 0
      else
        return 1
      fi
      ;;
    signin)
      if [[ "${MOCK_OP_SIGNIN_FAIL:-0}" == "1" ]]; then
        echo "signin failed" >&2
        return 1
      fi
      # Output export command for eval
      echo "export OP_SESSION_test=fake_session"
      return 0
      ;;
    item)
      case "$2" in
        list)
          echo "${MOCK_OP_ITEMS:-$_default_arr}"
          ;;
        get)
          # Support per-item mocks via MOCK_OP_ITEM_<id>
          local item_id="$3"
          local var_name="MOCK_OP_ITEM_${item_id}"
          if [[ -n "${!var_name:-}" ]]; then
            echo "${!var_name}"
          else
            echo "${MOCK_OP_ITEM:-$_default_obj}"
          fi
          ;;
      esac
      ;;
    account)
      case "$2" in
        list)
          echo "${MOCK_OP_ACCOUNTS:-$_default_arr}"
          ;;
      esac
      ;;
  esac
}

# Helper to read recorded gh calls
get_gh_calls() {
  if [[ -f "${TEST_TMPDIR:-/tmp}/gh_calls.log" ]]; then
    cat "${TEST_TMPDIR:-/tmp}/gh_calls.log"
  fi
}

# Helper to clear recorded calls
clear_gh_calls() {
  rm -f "${TEST_TMPDIR:-/tmp}/gh_calls.log"
}
