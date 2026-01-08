# shellcheck shell=bash

set -eu

# ShellSpec built-in settings
: "${SHELLSPEC_LIB:=}"

# Load mocks
# shellcheck source=spec/support/mocks.sh
. "${SHELLSPEC_SPECDIR}/support/mocks.sh"

# Helpers to load individual modules
# Each spec should only load the modules it needs
# Named with underscore prefix to avoid collision with lib functions

_load_helpers() {
  # shellcheck source=lib/helpers.sh
  . "${SHELLSPEC_PROJECT_ROOT}/lib/helpers.sh"
}

_load_repo() {
  _load_helpers
  # shellcheck source=lib/repo.sh
  . "${SHELLSPEC_PROJECT_ROOT}/lib/repo.sh"
}

_load_config() {
  _load_helpers
  _load_repo
  # shellcheck source=lib/config.sh
  . "${SHELLSPEC_PROJECT_ROOT}/lib/config.sh"
}

_load_settings() {
  _load_config
  # shellcheck source=lib/settings.sh
  . "${SHELLSPEC_PROJECT_ROOT}/lib/settings.sh"
}

_load_secrets() {
  _load_helpers
  _load_repo
  _load_config
  # shellcheck source=lib/secrets.sh
  . "${SHELLSPEC_PROJECT_ROOT}/lib/secrets.sh"
}

_load_commands() {
  _load_settings
  _load_secrets
  # shellcheck source=lib/commands.sh
  . "${SHELLSPEC_PROJECT_ROOT}/lib/commands.sh"
}

# Load all modules (equivalent to the built gh-coda)
load_all() {
  _load_commands
}

# Variants with mocked external commands
load_config() {
  _load_config
  gh() { mock_gh "$@"; }
  op() { mock_op "$@"; }
  yj() { mock_yj "$@"; }
}

load_config_with_mocks() {
  _load_config
  gh() { mock_gh "$@"; }
  op() { mock_op "$@"; }
  yj() { mock_yj "$@"; }
}

load_settings_with_mocks() {
  _load_settings
  gh() { mock_gh "$@"; }
  yj() { mock_yj "$@"; }
}

load_all_with_mocks() {
  load_all
  gh() { mock_gh "$@"; }
  op() { mock_op "$@"; }
  yj() { mock_yj "$@"; }
  # Skip dependency checks in tests
  need_cmd() { :; }
}

# Create temp directory for test fixtures
spec_helper_setup() {
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR
}

# Cleanup temp directory
spec_helper_cleanup() {
  if [[ -n "${TEST_TMPDIR:-}" && -d "$TEST_TMPDIR" ]]; then
    rm -rf "$TEST_TMPDIR"
  fi
}

# Register hooks
spec_helper_configure() {
  before_each 'spec_helper_setup'
  after_each 'spec_helper_cleanup'
}
