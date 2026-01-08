# shellcheck shell=bash
Describe 'Config discovery'
  Include spec/spec_helper.sh

  Describe 'find_config()'
    setup() {
      _load_config
    }

    BeforeEach 'setup'

    It 'returns --config path when -c flag is provided'
      touch "$TEST_TMPDIR/custom.yaml"
      When call find_config -c "$TEST_TMPDIR/custom.yaml"
      The status should be success
      The output should eq "$TEST_TMPDIR/custom.yaml"
    End

    It 'returns --config path when --config flag is provided'
      touch "$TEST_TMPDIR/custom.yaml"
      When call find_config --config "$TEST_TMPDIR/custom.yaml"
      The status should be success
      The output should eq "$TEST_TMPDIR/custom.yaml"
    End

    It 'fails when -c path does not exist'
      When run find_config -c "$TEST_TMPDIR/nonexistent.yaml"
      The status should be failure
      The stderr should include "not found"
    End

    It 'uses GH_CODA_CONFIG env var when set'
      touch "$TEST_TMPDIR/env.yaml"
      export GH_CODA_CONFIG="$TEST_TMPDIR/env.yaml"
      When call find_config
      The status should be success
      The output should eq "$TEST_TMPDIR/env.yaml"
    End

    It 'finds .github/coda.yml in current directory'
      mkdir -p "$TEST_TMPDIR/.github"
      touch "$TEST_TMPDIR/.github/coda.yml"
      cd "$TEST_TMPDIR"
      When call find_config
      The status should be success
      The output should eq "$TEST_TMPDIR/.github/coda.yml"
    End

    It 'finds .github/coda.yaml in current directory'
      mkdir -p "$TEST_TMPDIR/.github"
      touch "$TEST_TMPDIR/.github/coda.yaml"
      cd "$TEST_TMPDIR"
      When call find_config
      The status should be success
      The output should eq "$TEST_TMPDIR/.github/coda.yaml"
    End

    It 'prefers .yml over .yaml'
      mkdir -p "$TEST_TMPDIR/.github"
      touch "$TEST_TMPDIR/.github/coda.yml"
      touch "$TEST_TMPDIR/.github/coda.yaml"
      cd "$TEST_TMPDIR"
      When call find_config
      The status should be success
      The output should eq "$TEST_TMPDIR/.github/coda.yml"
    End

    It 'prefers -c over GH_CODA_CONFIG'
      touch "$TEST_TMPDIR/flag.yaml"
      touch "$TEST_TMPDIR/env.yaml"
      export GH_CODA_CONFIG="$TEST_TMPDIR/env.yaml"
      When call find_config -c "$TEST_TMPDIR/flag.yaml"
      The status should be success
      The output should eq "$TEST_TMPDIR/flag.yaml"
    End

    It 'prefers GH_CODA_CONFIG over .github/coda.yml in pwd'
      mkdir -p "$TEST_TMPDIR/.github"
      touch "$TEST_TMPDIR/.github/coda.yml"
      touch "$TEST_TMPDIR/env.yaml"
      export GH_CODA_CONFIG="$TEST_TMPDIR/env.yaml"
      cd "$TEST_TMPDIR"
      When call find_config
      The status should be success
      The output should eq "$TEST_TMPDIR/env.yaml"
    End

    It 'prefers .github/coda.yml over visibility-specific files'
      mkdir -p "$TEST_TMPDIR/.github"
      touch "$TEST_TMPDIR/.github/coda.yml"
      touch "$TEST_TMPDIR/coda.private.yml"
      cd "$TEST_TMPDIR"
      When call find_config
      The status should be success
      The output should eq "$TEST_TMPDIR/.github/coda.yml"
    End
  End

  Describe 'find_config() with visibility-specific files'
    setup_with_mock() {
      _load_config
      gh() { mock_gh "$@"; }
    }

    BeforeEach 'setup_with_mock'

    It 'finds coda.private.yml for private repos'
      export MOCK_GH_REPO_PRIVATE=1
      touch "$TEST_TMPDIR/coda.private.yml"
      cd "$TEST_TMPDIR"
      When call find_config
      The status should be success
      The output should eq "$TEST_TMPDIR/coda.private.yml"
    End

    It 'finds coda.public.yml for public repos'
      export MOCK_GH_REPO_PRIVATE=0
      touch "$TEST_TMPDIR/coda.public.yml"
      cd "$TEST_TMPDIR"
      When call find_config
      The status should be success
      The output should eq "$TEST_TMPDIR/coda.public.yml"
    End

    It 'finds coda.private.yaml for private repos'
      export MOCK_GH_REPO_PRIVATE=1
      touch "$TEST_TMPDIR/coda.private.yaml"
      cd "$TEST_TMPDIR"
      When call find_config
      The status should be success
      The output should eq "$TEST_TMPDIR/coda.private.yaml"
    End

    It 'walks up directory tree to find config'
      export MOCK_GH_REPO_PRIVATE=1
      mkdir -p "$TEST_TMPDIR/a/b/c"
      touch "$TEST_TMPDIR/coda.private.yml"
      cd "$TEST_TMPDIR/a/b/c"
      When call find_config
      The status should be success
      The output should eq "$TEST_TMPDIR/coda.private.yml"
    End

    It 'finds .coda.private.yml (dotted) for private repos'
      export MOCK_GH_REPO_PRIVATE=1
      touch "$TEST_TMPDIR/.coda.private.yml"
      cd "$TEST_TMPDIR"
      When call find_config
      The status should be success
      The output should eq "$TEST_TMPDIR/.coda.private.yml"
    End

    It 'finds .coda.public.yml (dotted) for public repos'
      export MOCK_GH_REPO_PRIVATE=0
      touch "$TEST_TMPDIR/.coda.public.yml"
      cd "$TEST_TMPDIR"
      When call find_config
      The status should be success
      The output should eq "$TEST_TMPDIR/.coda.public.yml"
    End

    It 'finds .coda.private.yaml (dotted .yaml) for private repos'
      export MOCK_GH_REPO_PRIVATE=1
      touch "$TEST_TMPDIR/.coda.private.yaml"
      cd "$TEST_TMPDIR"
      When call find_config
      The status should be success
      The output should eq "$TEST_TMPDIR/.coda.private.yaml"
    End

    It 'prefers dotted over non-dotted variant'
      export MOCK_GH_REPO_PRIVATE=1
      touch "$TEST_TMPDIR/.coda.private.yml"
      touch "$TEST_TMPDIR/coda.private.yml"
      cd "$TEST_TMPDIR"
      When call find_config
      The status should be success
      The output should eq "$TEST_TMPDIR/.coda.private.yml"
    End

    It 'walks up to find dotted variant'
      export MOCK_GH_REPO_PRIVATE=1
      mkdir -p "$TEST_TMPDIR/a/b/c"
      touch "$TEST_TMPDIR/.coda.private.yml"
      cd "$TEST_TMPDIR/a/b/c"
      When call find_config
      The status should be success
      The output should eq "$TEST_TMPDIR/.coda.private.yml"
    End
  End
End
