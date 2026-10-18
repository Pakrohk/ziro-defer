# tests/_harness.zsh - Pure Zsh assertion harness.
# Per RULES R12.4: exits 0 on pass, non-zero on fail with line diagnostics.

emulate -L zsh

typeset -gi _ziro_test_run=0
typeset -gi _ziro_test_pass=0
typeset -gi _ziro_test_fail=0
typeset -g _ziro_test_file="${0:t}"

_ziro_test_assert_eq() {
  local expected="$1" actual="$2" msg="${3:-assertion}"
  (( _ziro_test_run++ ))
  if [[ "$expected" == "$actual" ]]; then
    (( _ziro_test_pass++ ))
    print -u1 "  ✅ PASS: $msg"
  else
    (( _ziro_test_fail++ ))
    print -u2 "  ❌ FAIL: $msg"
    print -u2 "     expected: '$expected'"
    print -u2 "     actual:   '$actual'"
    return 1
  fi
}

_ziro_test_assert_status() {
  local expected_status="$1" msg="${2:-status}"
  shift 2
  "$@" >/dev/null 2>&1
  local actual_status=$?
  (( _ziro_test_run++ ))
  if (( expected_status == actual_status )); then
    (( _ziro_test_pass++ ))
    print -u1 "  ✅ PASS: $msg"
  else
    (( _ziro_test_fail++ ))
    print -u2 "  ❌ FAIL: $msg (expected status $expected_status, got $actual_status)"
    return 1
  fi
}

_ziro_test_summary() {
  print ""
  print "[${_ziro_test_file}] Passed: $_ziro_test_pass / $_ziro_test_run"
  if (( _ziro_test_fail > 0 )); then
    print -u2 "[${_ziro_test_file}] FAILED: $_ziro_test_fail assertions"
    return 1
  fi
  return 0
}
