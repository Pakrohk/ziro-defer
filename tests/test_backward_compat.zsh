#!/usr/bin/env zsh
# tests/test_backward_compat.zsh - Phase 5: zsh-defer alias and legacy patterns.
# Per RULES R12.1 and R9.3. Zero-fork assertions.

emulate -L zsh
set -u

source "${0:A:h}/../core/version.zsh"
source "${0:A:h}/../core/queue.zsh"
source "${0:A:h}/../core/task-registry.zsh"
source "${0:A:h}/../lib/timer.zsh"
source "${0:A:h}/../lib/json-writer.zsh"
source "${0:A:h}/../lib/cycle-detect.zsh"
source "${0:A:h}/../lib/condition-eval.zsh"
source "${0:A:h}/../core/scheduler.zsh"
source "${0:A:h}/../api/ziro-defer.zsh"
source "${0:A:h}/_harness.zsh"

# Test 1: zsh-defer alias exists
local has_alias=0
(( $+functions[zsh-defer] == 1 )) && has_alias=1
_ziro_test_assert_eq "1" "$has_alias" "zsh-defer function exists"

# Test 2: zsh-defer maps to stage=5 slot=b
zsh-defer --name=compat_t1 "echo hi" 2>/dev/null
_ziro_test_assert_eq "5" "${_ziro_defer_task_stage[compat_t1]}" "zsh-defer default stage=5"
_ziro_test_assert_eq "b" "${_ziro_defer_task_slot[compat_t1]}" "zsh-defer default slot=b"

# Test 3: ziro-defer without flags also defaults correctly
ziro-defer --name=compat_t2 "echo world" 2>/dev/null
_ziro_test_assert_eq "5" "${_ziro_defer_task_stage[compat_t2]}" "ziro-defer default stage=5"
_ziro_test_assert_eq "b" "${_ziro_defer_task_slot[compat_t2]}" "ziro-defer default slot=b"

# Test 4: zsh-defer passes through args correctly
zsh-defer --name=compat_t3 --stage=4 --slot=a "echo deep" 2>/dev/null
_ziro_test_assert_eq "4" "${_ziro_defer_task_stage[compat_t3]}" "zsh-defer respects --stage"
_ziro_test_assert_eq "a" "${_ziro_defer_task_slot[compat_t3]}" "zsh-defer respects --slot"

# Test 5: version is 2.0.0 per ADR-007
_ziro_test_assert_eq "2.0.0" "$ZIRO_DEFER_VERSION" "version = 2.0.0"

_ziro_test_summary
