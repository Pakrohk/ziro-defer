#!/usr/bin/env zsh
# tests/test_conditions.zsh - Phase 5: all 5 predicate flags.
# Per RULES R12.1 and R8. Zero-fork assertions.

emulate -L zsh
set -u

source "${0:A:h}/../core/version.zsh"
source "${0:A:h}/../lib/condition-eval.zsh"
source "${0:A:h}/_harness.zsh"

# Test 1: if-cmd=zsh (exists)
_ziro_test_assert_status 0 "if-cmd=zsh true" _ziro_defer_lib_eval_condition "if-cmd=zsh"

# Test 2: if-cmd=nonexistent
_ziro_test_assert_status 1 "if-cmd=fake false" _ziro_defer_lib_eval_condition "if-cmd=__fake_xyz__"

# Test 3: if-var (set)
export TEST_ZIRO_VAR="hello"
_ziro_test_assert_status 0 "if-var=TEST_ZIRO_VAR true" _ziro_defer_lib_eval_condition "if-var=TEST_ZIRO_VAR"

# Test 4: if-var (unset)
unset TEST_ZIRO_UNSET 2>/dev/null
_ziro_test_assert_status 1 "if-var=TEST_ZIRO_UNSET false" _ziro_defer_lib_eval_condition "if-var=TEST_ZIRO_UNSET"
unset TEST_ZIRO_VAR

# Test 5: if-not-root (non-root user)
if (( EUID != 0 )); then
  _ziro_test_assert_status 0 "if-not-root true for non-root" _ziro_defer_lib_eval_condition "if-not-root"
else
  _ziro_test_assert_status 1 "if-not-root false for root" _ziro_defer_lib_eval_condition "if-not-root"
fi

# Test 6: if-dir=/tmp (exists)
_ziro_test_assert_status 0 "if-dir=/tmp true" _ziro_defer_lib_eval_condition "if-dir=/tmp"

# Test 7: if-dir=/nonexistent
_ziro_test_assert_status 1 "if-dir=/nonexistent false" _ziro_defer_lib_eval_condition "if-dir=/__nonexistent_dir_xyz__"

# Test 8: if-ssh (when not in SSH)
if [[ -z "${SSH_CONNECTION:-}" && -z "${SSH_TTY:-}" ]]; then
  _ziro_test_assert_status 1 "if-ssh false without SSH" _ziro_defer_lib_eval_condition "if-ssh"
fi

# Test 9: empty condition passes
_ziro_test_assert_status 0 "empty condition passes" _ziro_defer_lib_eval_condition ""

# Test 10: unknown condition passes (safe default)
_ziro_test_assert_status 0 "unknown condition passes" _ziro_defer_lib_eval_condition "if-unknown=foo"

_ziro_test_summary
