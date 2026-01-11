# shellcheck shell=bash
Describe 'Commands'
  Include spec/spec_helper.sh

  Describe 'main()'
    setup() {
      load_all
    }

    BeforeEach 'setup'

    It 'shows help with --help'
      When call main --help
      The status should be success
      The output should include "gh coda"
      The output should include "--repo"
      The output should include "-R"
    End

    It 'shows help with -h'
      When call main -h
      The status should be success
      The output should include "gh coda"
    End

    It 'shows help with help subcommand'
      When call main help
      The status should be success
      The output should include "gh coda"
    End

    It 'fails with unknown command'
      When run main unknown-cmd
      The status should be failure
      The stderr should include "unknown command"
    End

    It 'suggests --help when unknown command'
      When run main badcmd
      The status should be failure
      The stderr should include "--help"
    End
  End

  Describe 'main() routing'
    setup() {
      load_all_with_mocks
      export GH_REPO="testowner/testrepo"
    }

    BeforeEach 'setup'

    It 'routes to setup when no args given'
      cd "$TEST_TMPDIR"
      unset GH_CODA_CONFIG
      When run main
      The status should be failure
      The stderr should include "no config file found"
    End

    It 'routes to setup when flag given without subcommand'
      echo '{"auto_merge":true}' > "$TEST_TMPDIR/config.yaml"
      When call main -c "$TEST_TMPDIR/config.yaml"
      The status should be success
      The stderr should include "setup complete"
    End

    It 'routes to init subcommand'
      cd "$TEST_TMPDIR"
      When call main init
      The status should be success
      The stderr should include "created"
      The path "$TEST_TMPDIR/.github/coda.yml" should be exist
    End

    It 'routes to status subcommand'
      cd "$TEST_TMPDIR"
      unset GH_CODA_CONFIG
      When call main status
      The status should be success
      The stderr should include "repo:"
    End

    It 'routes to set-secrets subcommand'
      CONFIG_JSON='{}'
      When run main set-secrets
      The status should be failure
      The stderr should include "no tags specified"
    End
  End

  Describe 'cmd_init()'
    setup() {
      load_all
    }

    BeforeEach 'setup'

    It 'creates default config when none exists'
      cd "$TEST_TMPDIR"
      When call cmd_init
      The status should be success
      The stderr should include "created"
      The path "$TEST_TMPDIR/.github/coda.yml" should be exist
      The contents of file "$TEST_TMPDIR/.github/coda.yml" should include "auto_merge"
      The contents of file "$TEST_TMPDIR/.github/coda.yml" should include "delete_branch_on_merge"
    End

    It 'copies existing config when -c is provided'
      echo "custom: true" > "$TEST_TMPDIR/source.yaml"
      cd "$TEST_TMPDIR"
      When call cmd_init -c "$TEST_TMPDIR/source.yaml"
      The status should be success
      The stderr should include "copied"
      The contents of file "$TEST_TMPDIR/.github/coda.yml" should include "custom: true"
    End

    It 'copies existing config when --config is provided'
      echo "longflag: true" > "$TEST_TMPDIR/source.yaml"
      cd "$TEST_TMPDIR"
      When call cmd_init --config "$TEST_TMPDIR/source.yaml"
      The status should be success
      The stderr should include "copied"
      The contents of file "$TEST_TMPDIR/.github/coda.yml" should include "longflag: true"
    End

    It 'fails if config already exists without --force'
      mkdir -p "$TEST_TMPDIR/.github"
      touch "$TEST_TMPDIR/.github/coda.yml"
      cd "$TEST_TMPDIR"
      When run cmd_init
      The status should be failure
      The stderr should include "already exists"
    End

    It 'suggests --force when config exists'
      mkdir -p "$TEST_TMPDIR/.github"
      touch "$TEST_TMPDIR/.github/coda.yml"
      cd "$TEST_TMPDIR"
      When run cmd_init
      The status should be failure
      The stderr should include "--force"
    End

    It 'overwrites existing config with --force'
      mkdir -p "$TEST_TMPDIR/.github"
      echo "old: true" > "$TEST_TMPDIR/.github/coda.yml"
      cd "$TEST_TMPDIR"
      When call cmd_init --force
      The status should be success
      The stderr should include "created"
      The contents of file "$TEST_TMPDIR/.github/coda.yml" should include "auto_merge"
      The contents of file "$TEST_TMPDIR/.github/coda.yml" should not include "old: true"
    End

    It 'overwrites existing config with -f short flag'
      mkdir -p "$TEST_TMPDIR/.github"
      echo "old: true" > "$TEST_TMPDIR/.github/coda.yml"
      cd "$TEST_TMPDIR"
      When call cmd_init -f
      The status should be success
      The stderr should include "created"
    End

    It 'respects -o/--output for custom path'
      cd "$TEST_TMPDIR"
      When call cmd_init -o "$TEST_TMPDIR/custom-config.yaml"
      The status should be success
      The stderr should include "created"
      The path "$TEST_TMPDIR/custom-config.yaml" should be exist
    End

    It 'respects --output long flag'
      cd "$TEST_TMPDIR"
      When call cmd_init --output "$TEST_TMPDIR/long-flag.yaml"
      The status should be success
      The stderr should include "created"
      The path "$TEST_TMPDIR/long-flag.yaml" should be exist
    End

    It 'fails with unknown option'
      cd "$TEST_TMPDIR"
      When run cmd_init --badoption
      The status should be failure
      The stderr should include "unknown option"
      The stderr should include "--badoption"
    End

    It 'includes security settings in default config'
      cd "$TEST_TMPDIR"
      When call cmd_init
      The status should be success
      The stderr should include "created"
      The contents of file "$TEST_TMPDIR/.github/coda.yml" should include "enable_secret_scanning"
      The contents of file "$TEST_TMPDIR/.github/coda.yml" should include "dependabot_alerts"
    End

    It 'shows next steps after creation'
      cd "$TEST_TMPDIR"
      When call cmd_init
      The status should be success
      The stderr should include "edit"
      The stderr should include "gh coda"
    End
  End

  Describe 'usage()'
    setup() {
      load_all
    }

    BeforeEach 'setup'

    It 'includes all subcommands'
      When call usage
      The output should include "setup"
      The output should include "init"
      The output should include "set-secrets"
      The output should include "status"
    End

    It 'documents --repo flag'
      When call usage
      The output should include "--repo"
      The output should include "-R"
    End

    It 'documents --config flag'
      When call usage
      The output should include "--config"
      The output should include "-c"
    End
  End

  Describe 'version flag'
    setup() {
      load_all
    }

    BeforeEach 'setup'

    It 'shows version with --version'
      When call main --version
      The status should be success
      The output should include "gh-coda"
    End

    It 'shows version with -v'
      When call main -v
      The status should be success
      The output should include "gh-coda"
    End

    It 'shows version with version subcommand'
      When call main version
      The status should be success
      The output should include "gh-coda"
    End
  End

  Describe 'cmd_status()'
    setup() {
      load_all_with_mocks
      export GH_REPO="testowner/testrepo"
      # Isolate from real config files in project directory
      cd "$TEST_TMPDIR"
      unset GH_CODA_CONFIG
    }

    BeforeEach 'setup'

    It 'displays repo name'
      When call cmd_status
      The status should be success
      The stderr should include "repo:"
      The stderr should include "testowner/testrepo"
    End

    It 'displays visibility as private'
      export MOCK_GH_REPO_PRIVATE=1
      When call cmd_status
      The status should be success
      The stderr should include "visibility:"
      The stderr should include "private"
    End

    It 'displays visibility as public'
      export MOCK_GH_REPO_PRIVATE=0
      When call cmd_status
      The status should be success
      The stderr should include "visibility:"
      The stderr should include "public"
    End

    It 'displays config path when config exists'
      echo '{"auto_merge":true}' > "$TEST_TMPDIR/test.yaml"
      When call cmd_status -c "$TEST_TMPDIR/test.yaml"
      The status should be success
      The stderr should include "config:"
      The stderr should include "$TEST_TMPDIR/test.yaml"
      The stdout should include "auto_merge"
    End

    It 'displays configured settings from config'
      echo '{"auto_merge":true,"delete_branch_on_merge":false}' > "$TEST_TMPDIR/test.yaml"
      When call cmd_status -c "$TEST_TMPDIR/test.yaml"
      The status should be success
      The stderr should include "configured settings"
      The stdout should include "auto_merge"
      The stdout should include "delete_branch_on_merge"
    End

    It 'displays (none found) when no config exists'
      When call cmd_status
      The status should be success
      The stderr should include "none found"
    End

    It 'respects -R short flag'
      When call cmd_status -R "other/repo"
      The status should be success
      The stderr should include "repo:"
      The stderr should include "other/repo"
    End

    It 'respects --repo long flag'
      When call cmd_status --repo "long/flag"
      The status should be success
      The stderr should include "repo:"
      The stderr should include "long/flag"
    End

    It 'respects --config long flag'
      echo '{"test":true}' > "$TEST_TMPDIR/test.yaml"
      When call cmd_status --config "$TEST_TMPDIR/test.yaml"
      The status should be success
      The stderr should include "config:"
      The stdout should include "test"
    End

    It 'passes remaining args to find_config'
      echo '{"test":true}' > "$TEST_TMPDIR/test.yaml"
      When call cmd_status -c "$TEST_TMPDIR/test.yaml"
      The status should be success
      The stderr should include "$TEST_TMPDIR/test.yaml"
      The stdout should include "test"
    End
  End

  Describe 'cmd_setup()'
    setup() {
      load_all_with_mocks
      export GH_REPO="testowner/testrepo"
    }

    BeforeEach 'setup'

    It 'fails when no config is found'
      cd "$TEST_TMPDIR"
      unset GH_CODA_CONFIG
      When run cmd_setup
      The status should be failure
      The stderr should include "no config file found"
    End

    It 'displays repo and config path'
      echo '{"auto_merge":true}' > "$TEST_TMPDIR/config.yaml"
      When call cmd_setup -c "$TEST_TMPDIR/config.yaml"
      The status should be success
      The stderr should include "repo:"
      The stderr should include "config:"
      The stderr should include "setup complete"
    End

    It 'applies repo edit settings from config'
      echo '{"auto_merge":true}' > "$TEST_TMPDIR/config.yaml"
      When call cmd_setup -c "$TEST_TMPDIR/config.yaml"
      The status should be success
      The stderr should include "applying repo edit settings"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "--enable-auto-merge"
    End

    It 'respects -R short flag'
      echo '{"auto_merge":true}' > "$TEST_TMPDIR/config.yaml"
      When call cmd_setup -R "other/repo" -c "$TEST_TMPDIR/config.yaml"
      The status should be success
      The stderr should include "other/repo"
    End

    It 'respects --repo long flag'
      echo '{"auto_merge":true}' > "$TEST_TMPDIR/config.yaml"
      When call cmd_setup --repo "long/repo" -c "$TEST_TMPDIR/config.yaml"
      The status should be success
      The stderr should include "long/repo"
    End

    It 'respects --config long flag'
      echo '{"auto_merge":true}' > "$TEST_TMPDIR/config.yaml"
      When call cmd_setup --config "$TEST_TMPDIR/config.yaml"
      The status should be success
      The stderr should include "setup complete"
    End

    It 'applies dependabot alerts when configured'
      echo '{"dependabot_alerts":true}' > "$TEST_TMPDIR/config.yaml"
      When call cmd_setup -c "$TEST_TMPDIR/config.yaml"
      The status should be success
      The stderr should include "enabling dependabot alerts"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "vulnerability-alerts"
    End

    It 'applies dependabot security updates when configured'
      echo '{"dependabot_security_updates":true}' > "$TEST_TMPDIR/config.yaml"
      When call cmd_setup -c "$TEST_TMPDIR/config.yaml"
      The status should be success
      The stderr should include "enabling dependabot security updates"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "automated-security-fixes"
    End

    It 'applies branch protection when configured'
      echo '{"branches":{"main":{"enforce_admins":true}}}' > "$TEST_TMPDIR/config.yaml"
      When call cmd_setup -c "$TEST_TMPDIR/config.yaml"
      The status should be success
      The stderr should include "branch protection"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "/branches/main/protection"
    End

    It 'applies rulesets when configured'
      echo '{"rulesets":[{"name":"Protect main"}]}' > "$TEST_TMPDIR/config.yaml"
      When call cmd_setup -c "$TEST_TMPDIR/config.yaml"
      The status should be success
      The stderr should include "ruleset"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "/rulesets"
    End

    It 'applies environments when configured'
      echo '{"environments":{"production":{"wait_timer":30}}}' > "$TEST_TMPDIR/config.yaml"
      When call cmd_setup -c "$TEST_TMPDIR/config.yaml"
      The status should be success
      The stderr should include "environment"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "/environments/production"
    End

    It 'applies pages when configured'
      echo '{"pages":{"enabled":true}}' > "$TEST_TMPDIR/config.yaml"
      When call cmd_setup -c "$TEST_TMPDIR/config.yaml"
      The status should be success
      The stderr should include "GitHub Pages"
      The contents of file "${TEST_TMPDIR}/gh_calls.log" should include "/pages"
    End

    It 'disables pages when enabled is false'
      echo '{"pages":{"enabled":false}}' > "$TEST_TMPDIR/config.yaml"
      When call cmd_setup -c "$TEST_TMPDIR/config.yaml"
      The status should be success
      The stderr should include "disabling GitHub Pages"
    End

    It 'applies multiple settings in one run'
      echo '{"auto_merge":true,"delete_branch_on_merge":true,"dependabot_alerts":true}' > "$TEST_TMPDIR/config.yaml"
      When call cmd_setup -c "$TEST_TMPDIR/config.yaml"
      The status should be success
      The stderr should include "applying repo edit settings"
      The stderr should include "enabling dependabot alerts"
      The stderr should include "setup complete"
    End

    It 'does not trigger set-secrets without secrets_tags'
      echo '{"auto_merge":true}' > "$TEST_TMPDIR/config.yaml"
      When call cmd_setup -c "$TEST_TMPDIR/config.yaml"
      The status should be success
      The stderr should not include "tags:"
    End

    It 'uses resolved repo when -R not provided'
      echo '{"auto_merge":true}' > "$TEST_TMPDIR/config.yaml"
      When call cmd_setup -c "$TEST_TMPDIR/config.yaml"
      The status should be success
      The stderr should include "testowner/testrepo"
    End
  End

  Describe 'usage() content'
    setup() {
      load_all
    }

    BeforeEach 'setup'

    It 'documents config discovery order'
      When call usage
      The output should include "Config Discovery"
      The output should include "GH_CODA_CONFIG"
      The output should include ".github/coda"
    End

    It 'shows config format examples'
      When call usage
      The output should include "Config Format"
      The output should include "auto_merge"
      The output should include "secrets_tags"
    End

    It 'documents all options'
      When call usage
      The output should include "--help"
      The output should include "--version"
    End
  End
End
