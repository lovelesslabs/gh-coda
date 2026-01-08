# shellcheck shell=bash
Describe 'Config loading'
  Include spec/spec_helper.sh

  setup() {
    _load_config
    # Mock yj to pass through (tests write JSON directly)
    yj() { cat; }
  }

  BeforeEach 'setup'

  Describe 'load_config()'
    # Note: load_config is a function in lib/config.sh, not spec_helper's load_config
    # We need to call it differently to avoid confusion

    It 'loads a valid config file'
      echo '{"auto_merge":true,"delete_branch_on_merge":true}' > "$TEST_TMPDIR/config.yaml"
      # shellcheck disable=SC2154
      When call load_config "$TEST_TMPDIR/config.yaml"
      The status should be success
      The variable CONFIG_JSON should eq '{"auto_merge":true,"delete_branch_on_merge":true}'
    End

    It 'fails when file does not exist'
      When run load_config "$TEST_TMPDIR/nonexistent.yaml"
      The status should be failure
      The stderr should include "not found"
    End
  End

  Describe 'config_get()'
    set_test_config() {
      CONFIG_JSON='{"name":"test","count":42,"nested":{"key":"value"}}'
    }

    BeforeEach 'set_test_config'

    It 'returns string value for existing key'
      When call config_get name
      The output should eq 'test'
    End

    It 'returns number value for existing key'
      When call config_get count
      The output should eq '42'
    End

    It 'returns empty string for missing key'
      When call config_get missing
      The output should eq ''
    End

    It 'returns default value for missing key'
      When call config_get missing "default_value"
      The output should eq 'default_value'
    End
  End

  Describe 'config_bool()'
    It 'returns success (0) for true value'
      CONFIG_JSON='{"enabled":true}'
      When call config_bool enabled
      The status should be success
    End

    It 'returns failure (1) for false value'
      CONFIG_JSON='{"enabled":false}'
      When call config_bool enabled
      The status should be failure
    End

    It 'returns failure (1) for missing key'
      CONFIG_JSON='{"other":true}'
      When call config_bool enabled
      The status should be failure
    End

    It 'returns failure (1) for non-boolean value'
      CONFIG_JSON='{"enabled":"yes"}'
      When call config_bool enabled
      The status should be failure
    End
  End

  Describe 'config_has()'
    It 'returns success (0) when key exists'
      CONFIG_JSON='{"auto_merge":true}'
      When call config_has auto_merge
      The status should be success
    End

    It 'returns failure (1) when key does not exist'
      CONFIG_JSON='{"auto_merge":true}'
      When call config_has missing_key
      The status should be failure
    End

    It 'returns success for key with false value'
      CONFIG_JSON='{"disabled":false}'
      When call config_has disabled
      The status should be success
    End

    It 'returns success for key with null value'
      CONFIG_JSON='{"nullable":null}'
      When call config_has nullable
      The status should be success
    End
  End
End
