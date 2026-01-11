# shellcheck shell=bash
Describe 'Settings application'
  Include spec/spec_helper.sh

  setup() {
    _load_settings
    gh() { mock_gh "$@"; }
    yj() { mock_yj "$@"; }
  }

  BeforeEach 'setup'

  Describe 'apply_repo_edit_settings()'
    It 'calls gh repo edit with --enable-auto-merge when auto_merge is true'
      CONFIG_JSON='{"auto_merge":true}'
      When call apply_repo_edit_settings "owner/repo"
      The status should be success
      The stderr should include "applying repo edit settings"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "--enable-auto-merge"
    End

    It 'calls gh repo edit with --enable-auto-merge=false when auto_merge is false'
      CONFIG_JSON='{"auto_merge":false}'
      When call apply_repo_edit_settings "owner/repo"
      The status should be success
      The stderr should include "applying"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "--enable-auto-merge=false"
    End

    It 'calls gh repo edit with --delete-branch-on-merge when delete_branch_on_merge is true'
      CONFIG_JSON='{"delete_branch_on_merge":true}'
      When call apply_repo_edit_settings "owner/repo"
      The status should be success
      The stderr should include "applying"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "--delete-branch-on-merge"
    End

    It 'calls gh repo edit with --delete-branch-on-merge=false when delete_branch_on_merge is false'
      CONFIG_JSON='{"delete_branch_on_merge":false}'
      When call apply_repo_edit_settings "owner/repo"
      The status should be success
      The stderr should include "applying"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "--delete-branch-on-merge=false"
    End

    It 'batches multiple settings into one gh repo edit call'
      CONFIG_JSON='{"auto_merge":true,"enable_discussions":true,"enable_wiki":false}'
      When call apply_repo_edit_settings "owner/repo"
      The status should be success
      The stderr should include "applying"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "--enable-auto-merge"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "--enable-discussions"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "--enable-wiki=false"
    End

    It 'does nothing when no settings are configured'
      CONFIG_JSON='{}'
      When call apply_repo_edit_settings "owner/repo"
      The status should be success
      The path "${TEST_TMPDIR}/gh_calls.log" should not be exist
    End

    It 'handles secret scanning settings'
      CONFIG_JSON='{"enable_secret_scanning":true,"enable_secret_scanning_push_protection":true}'
      When call apply_repo_edit_settings "owner/repo"
      The status should be success
      The stderr should include "applying"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "--enable-secret-scanning"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "--enable-secret-scanning-push-protection"
    End
  End

  Describe 'apply_api_settings()'
    It 'calls PUT for dependabot_alerts when true'
      CONFIG_JSON='{"dependabot_alerts":true}'
      When call apply_api_settings "owner/repo"
      The status should be success
      The stderr should include "enabling dependabot alerts"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "api --method PUT"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "vulnerability-alerts"
    End

    It 'calls DELETE for dependabot_alerts when false'
      CONFIG_JSON='{"dependabot_alerts":false}'
      When call apply_api_settings "owner/repo"
      The status should be success
      The stderr should include "disabling dependabot alerts"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "api --method DELETE"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "vulnerability-alerts"
    End

    It 'calls PUT for dependabot_security_updates when true'
      CONFIG_JSON='{"dependabot_security_updates":true}'
      When call apply_api_settings "owner/repo"
      The status should be success
      The stderr should include "enabling dependabot security updates"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "api --method PUT"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "automated-security-fixes"
    End

    It 'does nothing when no API settings are configured'
      CONFIG_JSON='{}'
      When call apply_api_settings "owner/repo"
      The status should be success
      The path "${TEST_TMPDIR}/gh_calls.log" should not be exist
    End
  End

  Describe 'apply_branch_protection()'
    It 'does nothing when no branches config exists'
      CONFIG_JSON='{}'
      When call apply_branch_protection "owner/repo"
      The status should be success
      The path "${TEST_TMPDIR}/gh_calls.log" should not be exist
    End

    It 'calls API for each configured branch'
      CONFIG_JSON='{"branches":{"main":{"enforce_admins":true},"develop":{"enforce_admins":false}}}'
      When call apply_branch_protection "owner/repo"
      The status should be success
      The stderr should include "main"
      The stderr should include "develop"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "/repos/owner/repo/branches/main/protection"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "/repos/owner/repo/branches/develop/protection"
    End

    It 'sets required_approving_review_count to 0 by default'
      CONFIG_JSON='{"branches":{"main":{}}}'
      When call apply_branch_protection "owner/repo"
      The status should be success
      The stderr should include "main"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "required_approving_review_count"
    End

    It 'includes status checks when configured'
      CONFIG_JSON='{"branches":{"main":{"required_status_checks":{"strict":true,"checks":[{"context":"ci/build"}]}}}}'
      When call apply_branch_protection "owner/repo"
      The status should be success
      The stderr should include "main"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "ci/build"
    End
  End

  Describe 'apply_rulesets()'
    It 'does nothing when no rulesets config exists'
      CONFIG_JSON='{}'
      When call apply_rulesets "owner/repo"
      The status should be success
      The path "${TEST_TMPDIR}/gh_calls.log" should not be exist
    End

    It 'calls API for each configured ruleset'
      CONFIG_JSON='{"rulesets":[{"name":"Protect main","target":"branch","enforcement":"active"}]}'
      When call apply_rulesets "owner/repo"
      The status should be success
      The stderr should include "Protect main"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "/repos/owner/repo/rulesets"
    End

    It 'includes ruleset name in payload'
      CONFIG_JSON='{"rulesets":[{"name":"My Rule","target":"branch"}]}'
      When call apply_rulesets "owner/repo"
      The status should be success
      The stderr should include "My Rule"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "My Rule"
    End

    It 'defaults target to branch'
      CONFIG_JSON='{"rulesets":[{"name":"Test Rule"}]}'
      When call apply_rulesets "owner/repo"
      The status should be success
      The stderr should include "Test Rule"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "branch"
    End

    It 'defaults enforcement to active'
      CONFIG_JSON='{"rulesets":[{"name":"Test Rule"}]}'
      When call apply_rulesets "owner/repo"
      The status should be success
      The stderr should include "Test Rule"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "active"
    End
  End

  Describe 'apply_environments()'
    It 'does nothing when no environments config exists'
      CONFIG_JSON='{}'
      When call apply_environments "owner/repo"
      The status should be success
      The path "${TEST_TMPDIR}/gh_calls.log" should not be exist
    End

    It 'calls API for each configured environment'
      CONFIG_JSON='{"environments":{"production":{"wait_timer":30},"staging":{"wait_timer":0}}}'
      When call apply_environments "owner/repo"
      The status should be success
      The stderr should include "production"
      The stderr should include "staging"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "/repos/owner/repo/environments/production"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "/repos/owner/repo/environments/staging"
    End

    It 'includes wait_timer in payload'
      CONFIG_JSON='{"environments":{"prod":{"wait_timer":60}}}'
      When call apply_environments "owner/repo"
      The status should be success
      The stderr should include "prod"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "wait_timer"
    End

    It 'includes reviewers when configured'
      CONFIG_JSON='{"environments":{"prod":{"reviewers":[{"type":"User","id":12345}]}}}'
      When call apply_environments "owner/repo"
      The status should be success
      The stderr should include "prod"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "reviewers"
    End

    It 'includes deployment_branch_policy when configured'
      CONFIG_JSON='{"environments":{"prod":{"deployment_branch_policy":{"protected_branches":true}}}}'
      When call apply_environments "owner/repo"
      The status should be success
      The stderr should include "prod"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "deployment_branch_policy"
    End
  End

  Describe 'apply_pages()'
    It 'does nothing when no pages config exists'
      CONFIG_JSON='{}'
      When call apply_pages "owner/repo"
      The status should be success
      The path "${TEST_TMPDIR}/gh_calls.log" should not be exist
    End

    It 'disables pages when enabled is false'
      CONFIG_JSON='{"pages":{"enabled":false}}'
      When call apply_pages "owner/repo"
      The status should be success
      The stderr should include "disabling"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "--method DELETE"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "/repos/owner/repo/pages"
    End

    It 'calls API to configure pages'
      CONFIG_JSON='{"pages":{"enabled":true,"build_type":"workflow"}}'
      When call apply_pages "owner/repo"
      The status should be success
      The stderr should include "configuring GitHub Pages"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "/repos/owner/repo/pages"
    End

    It 'defaults build_type to workflow'
      CONFIG_JSON='{"pages":{"enabled":true}}'
      When call apply_pages "owner/repo"
      The status should be success
      The stderr should include "configuring GitHub Pages"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "workflow"
    End

    It 'includes source for legacy builds'
      CONFIG_JSON='{"pages":{"build_type":"legacy","source":{"branch":"main","path":"/docs"}}}'
      When call apply_pages "owner/repo"
      The status should be success
      The stderr should include "configuring GitHub Pages"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "source"
    End
  End
End
