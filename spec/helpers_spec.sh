# shellcheck shell=bash
Describe 'Helper functions'
  Include spec/spec_helper.sh

  setup() {
    _load_helpers
  }

  BeforeEach 'setup'

  Describe 'log()'
    It 'writes message to stderr'
      When call log "test message"
      The status should be success
      The stderr should eq "test message"
      The output should eq ""
    End

    It 'handles multiple arguments'
      When call log "hello" "world"
      The status should be success
      The stderr should eq "hello world"
    End

    It 'handles empty message'
      When call log ""
      The status should be success
      The stderr should eq ""
    End
  End

  Describe 'die()'
    It 'exits with status 1'
      When run die "fatal error"
      The status should eq 1
      The stderr should be present
    End

    It 'writes error message to stderr'
      When run die "fatal error"
      The status should eq 1
      The stderr should include "error:"
      The stderr should include "fatal error"
    End

    It 'prefixes message with error:'
      When run die "something broke"
      The status should eq 1
      The stderr should eq "error: something broke"
    End
  End

  Describe 'need_cmd()'
    It 'succeeds for existing command (bash)'
      When call need_cmd bash
      The status should be success
    End

    It 'succeeds for existing command (cat)'
      When call need_cmd cat
      The status should be success
    End

    It 'fails for nonexistent command'
      When run need_cmd this_command_does_not_exist_xyz123
      The status should be failure
      The stderr should include "missing dependency"
      The stderr should include "this_command_does_not_exist_xyz123"
    End
  End
End
