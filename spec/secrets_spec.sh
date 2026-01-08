# shellcheck shell=bash
Describe 'Secrets functions'
  Include spec/spec_helper.sh

  Describe 'normalize_secret_name()'
    setup() {
      _load_secrets
    }

    BeforeEach 'setup'

    It 'converts to uppercase'
      When call normalize_secret_name "my_secret"
      The output should eq "MY_SECRET"
    End

    It 'replaces spaces with underscores'
      When call normalize_secret_name "my secret name"
      The output should eq "MY_SECRET_NAME"
    End

    It 'replaces hyphens with underscores'
      When call normalize_secret_name "my-secret-name"
      The output should eq "MY_SECRET_NAME"
    End

    It 'removes special characters'
      When call normalize_secret_name "my@secret!name#123"
      The output should eq "MY_SECRET_NAME_123"
    End

    It 'collapses multiple underscores'
      When call normalize_secret_name "my___secret"
      The output should eq "MY_SECRET"
    End

    It 'trims leading underscores'
      When call normalize_secret_name "_my_secret"
      The output should eq "MY_SECRET"
    End

    It 'trims trailing underscores'
      When call normalize_secret_name "my_secret_"
      The output should eq "MY_SECRET"
    End

    It 'handles complex names'
      When call normalize_secret_name "My API Key (Production)"
      The output should eq "MY_API_KEY_PRODUCTION"
    End
  End

  Describe 'op_ensure_signed_in()'
    setup() {
      _load_secrets
      op() { mock_op "$@"; }
    }

    BeforeEach 'setup'

    It 'succeeds when already signed in'
      export MOCK_OP_SIGNED_IN=1
      When call op_ensure_signed_in
      The status should be success
    End

    It 'fails when not signed in and no accounts'
      export MOCK_OP_SIGNED_IN=0
      export MOCK_OP_ACCOUNTS='[]'
      When run op_ensure_signed_in
      The status should be failure
      The stderr should include "not signed in"
    End

    It 'fails when not signed in and multiple accounts'
      export MOCK_OP_SIGNED_IN=0
      export MOCK_OP_ACCOUNTS='[{"shorthand":"acct1"},{"shorthand":"acct2"}]'
      When run op_ensure_signed_in
      The status should be failure
      The stderr should include "not signed in"
    End

    It 'fails when single account has no shorthand'
      export MOCK_OP_SIGNED_IN=0
      export MOCK_OP_ACCOUNTS='[{}]'
      When run op_ensure_signed_in
      The status should be failure
      The stderr should include "couldn't determine account shorthand"
    End
  End

  Describe 'cmd_set_secrets()'
    setup() {
      _load_secrets
      op() { mock_op "$@"; }
      gh() { mock_gh "$@"; }
      export GH_REPO="owner/repo"
      export MOCK_OP_SIGNED_IN=1
    }

    BeforeEach 'setup'

    It 'fails when no tags specified and not in config'
      CONFIG_JSON='{}'
      When run cmd_set_secrets
      The status should be failure
      The stderr should include "no tags specified"
    End

    It 'uses tags from config when available'
      CONFIG_JSON='{"secrets_tags":"ci-secrets"}'
      export MOCK_OP_ITEMS='[]'
      When run cmd_set_secrets
      The status should be failure
      The stderr should include "no 1Password items found"
    End

    It 'accepts --tags argument'
      CONFIG_JSON='{}'
      export MOCK_OP_ITEMS='[]'
      When run cmd_set_secrets --tags "my-tag"
      The status should be failure
      The stderr should include "no 1Password items found"
    End

    It 'respects --dry-run flag'
      CONFIG_JSON='{}'
      export MOCK_OP_ITEMS='[{"id":"abc123","title":"Test Secret"}]'
      export MOCK_OP_ITEM='{"fields":[{"label":"password","value":"secret123"}]}'
      When call cmd_set_secrets --tags "test" --dry-run
      The status should be success
      The stderr should include "would set"
      The stderr should include "TEST_SECRET"
    End

    It 'accepts --app argument'
      CONFIG_JSON='{}'
      export MOCK_OP_ITEMS='[{"id":"abc123","title":"Test Secret"}]'
      export MOCK_OP_ITEM='{"fields":[{"label":"password","value":"secret123"}]}'
      When call cmd_set_secrets --tags "test" --app "dependabot" --dry-run
      The status should be success
      The stderr should include "would set"
    End

    It 'fails with unknown option'
      CONFIG_JSON='{}'
      When run cmd_set_secrets --unknown-flag
      The status should be failure
      The stderr should include "unknown option"
      The stderr should include "--unknown-flag"
    End

    It 'fails when name filter matches zero items'
      CONFIG_JSON='{}'
      export MOCK_OP_ITEMS='[{"id":"abc123","title":"Other Secret"}]'
      When run cmd_set_secrets --tags "test" "Nonexistent Secret"
      The status should be failure
      The stderr should include "expected exactly 1 match"
      The stderr should include "found 0"
    End

    It 'fails when name filter matches multiple items'
      CONFIG_JSON='{}'
      export MOCK_OP_ITEMS='[{"id":"abc123","title":"My Secret"},{"id":"def456","title":"My Secret"}]'
      When run cmd_set_secrets --tags "test" "My Secret"
      The status should be failure
      The stderr should include "expected exactly 1 match"
      The stderr should include "found 2"
    End

    It 'fails when item has no extractable secret value'
      CONFIG_JSON='{}'
      export MOCK_OP_ITEMS='[{"id":"abc123","title":"Empty Item"}]'
      export MOCK_OP_ITEM='{"fields":[]}'
      When run cmd_set_secrets --tags "test"
      The status should be failure
      The stderr should include "no secret value found"
      The stderr should include "Empty Item"
    End

    It 'suggests --field when no secret value found'
      CONFIG_JSON='{}'
      export MOCK_OP_ITEMS='[{"id":"abc123","title":"Bad Item"}]'
      export MOCK_OP_ITEM='{"fields":[{"label":"notes","value":"not a secret"}]}'
      When run cmd_set_secrets --tags "test"
      The status should be failure
      The stderr should include "use --field to force a label"
    End

    It 'outputs verbose information when --verbose is set'
      CONFIG_JSON='{}'
      export MOCK_OP_ITEMS='[{"id":"abc123","title":"Test Secret"}]'
      export MOCK_OP_ITEM='{"fields":[{"label":"password","value":"secret123"}]}'
      When call cmd_set_secrets --tags "test" --verbose --dry-run
      The status should be success
      The stderr should include "tags:"
      The stderr should include "repo target:"
    End

    It 'outputs name filter in verbose mode'
      CONFIG_JSON='{}'
      export MOCK_OP_ITEMS='[{"id":"abc123","title":"My Secret"}]'
      export MOCK_OP_ITEM='{"fields":[{"label":"password","value":"secret123"}]}'
      When call cmd_set_secrets --tags "test" --verbose --dry-run "My Secret"
      The status should be success
      The stderr should include "name filter:"
      The stderr should include "My Secret"
    End

    It 'uses gh_secret_name override from 1Password item'
      CONFIG_JSON='{}'
      export MOCK_OP_ITEMS='[{"id":"abc123","title":"Original Name"}]'
      export MOCK_OP_ITEM='{"fields":[{"label":"gh_secret_name","value":"CUSTOM_NAME"},{"label":"password","value":"secret123"}]}'
      When call cmd_set_secrets --tags "test"
      The status should be success
      The stderr should include "done"
      # Verify the gh secret set was called with the overridden name
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "CUSTOM_NAME"
    End

    It 'extracts credential field by priority'
      CONFIG_JSON='{}'
      export MOCK_OP_ITEMS='[{"id":"abc123","title":"API Key"}]'
      export MOCK_OP_ITEM='{"fields":[{"label":"credential","value":"cred123"},{"label":"password","value":"pass456"}]}'
      When call cmd_set_secrets --tags "test" --dry-run
      The status should be success
      The stderr should include "would set: API_KEY"
    End

    It 'extracts token field when no credential or password'
      CONFIG_JSON='{}'
      export MOCK_OP_ITEMS='[{"id":"abc123","title":"Auth Token"}]'
      export MOCK_OP_ITEM='{"fields":[{"label":"token","value":"tok789"},{"label":"notes","value":"some notes"}]}'
      When call cmd_set_secrets --tags "test" --dry-run
      The status should be success
      The stderr should include "would set: AUTH_TOKEN"
    End

    It 'uses secrets_app from config'
      CONFIG_JSON='{"secrets_tags":"ci","secrets_app":"codespaces"}'
      export MOCK_OP_ITEMS='[{"id":"abc123","title":"Test"}]'
      export MOCK_OP_ITEM='{"fields":[{"label":"password","value":"secret"}]}'
      When call cmd_set_secrets --dry-run
      The status should be success
      The stderr should include "would set"
    End

    It 'handles items with concealed field type'
      CONFIG_JSON='{}'
      export MOCK_OP_ITEMS='[{"id":"abc123","title":"Concealed Secret"}]'
      export MOCK_OP_ITEM='{"fields":[{"label":"api_key","value":"hidden123","type":"CONCEALED"}]}'
      When call cmd_set_secrets --tags "test" --dry-run
      The status should be success
      The stderr should include "would set: CONCEALED_SECRET"
    End
  End
End
