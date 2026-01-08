# shellcheck shell=bash
Describe 'Repository functions'
  Include spec/spec_helper.sh

  Describe 'resolve_repo()'
    setup() {
      _load_repo
      gh() { mock_gh "$@"; }
    }

    BeforeEach 'setup'

    It 'uses GH_REPO env var when set'
      export GH_REPO="env/repo"
      When call resolve_repo
      The status should be success
      The output should eq "env/repo"
    End

    It 'calls gh repo view when GH_REPO is not set'
      unset GH_REPO
      export MOCK_GH_REPO="owner/myrepo"
      When call resolve_repo
      The status should be success
      The output should eq "owner/myrepo"
    End

    It 'fails with helpful message when not in git repo'
      unset GH_REPO
      # Override mock to simulate "not a git repo" error
      gh() {
        echo "fatal: not a git repository (or any parent up to mount point /)" >&2
        return 1
      }
      When run resolve_repo
      The status should be failure
      The stderr should include "not in a git repo"
    End

    It 'fails with helpful message when no remotes'
      unset GH_REPO
      # Override mock to simulate "no git remotes" error
      gh() {
        echo "no git remotes found" >&2
        return 1
      }
      When run resolve_repo
      The status should be failure
      The stderr should include "no remotes"
    End

    It 'fails with generic message for other errors'
      unset GH_REPO
      # Override mock to simulate other error
      gh() {
        echo "some other error" >&2
        return 1
      }
      When run resolve_repo
      The status should be failure
      The stderr should include "failed to resolve repo"
    End
  End

  Describe 'get_repo_visibility()'
    setup() {
      _load_repo
      gh() { mock_gh "$@"; }
    }

    BeforeEach 'setup'

    It 'returns "private" for private repos'
      export MOCK_GH_REPO_PRIVATE=1
      When call get_repo_visibility "owner/repo"
      The status should be success
      The output should eq "private"
    End

    It 'returns "public" for public repos'
      export MOCK_GH_REPO_PRIVATE=0
      When call get_repo_visibility "owner/repo"
      The status should be success
      The output should eq "public"
    End

    It 'resolves repo when not provided'
      export GH_REPO="myowner/myrepo"
      export MOCK_GH_REPO_PRIVATE=1
      When call get_repo_visibility
      The status should be success
      The output should eq "private"
    End
  End
End
