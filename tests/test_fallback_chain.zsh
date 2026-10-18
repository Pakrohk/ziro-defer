#!/usr/bin/env zsh
# tests/test_fallback_chain.zsh - C-2: config-driven retry and warning.
# Zero-fork assertions.

emulate -L zsh
set -u
zmodload zsh/mapfile 2>/dev/null

source "${0:A:h}/../core/version.zsh"
source "${0:A:h}/../core/queue.zsh"
source "${0:A:h}/../core/task-registry.zsh"
source "${0:A:h}/../lib/timer.zsh"
source "${0:A:h}/../lib/json-writer.zsh"
source "${0:A:h}/../lib/cycle-detect.zsh"
source "${0:A:h}/../lib/condition-eval.zsh"
source "${0:A:h}/../core/scheduler.zsh"
source "${0:A:h}/../config/defaults.zsh"
source "${0:A:h}/_harness.zsh"

typeset -gi _test_fb_count=0
_test_cmd_always_fail() { (( _test_fb_count++ )); false; }
_test_cmd_succeed_second() { (( _test_fb_count++ )); (( _test_fb_count == 2 )); }

# Test 1: retry_on_failure=true, max_retries=1 -> 2 attempts, status=failure
_test_fb_count=0
_ZIRO_DEFER_RETRY_ON_FAILURE="true"
_ZIRO_DEFER_MAX_RETRIES="1"
_ZIRO_DEFER_SUPPRESS_WARNINGS="true"
_ziro_defer_core_register "fb_t1" 5 "b" "_test_cmd_always_fail"
_ziro_defer_core_execute_task "fb_t1" 2>/dev/null
_ziro_test_assert_eq "2" "$_test_fb_count" "retry_on_failure=true: 2 attempts made"
_ziro_test_assert_eq "failure" "${_ziro_defer_task_status[fb_t1]}" "task status is failure"

# Test 2: retry_on_failure=false -> only 1 attempt
_test_fb_count=0
_ZIRO_DEFER_RETRY_ON_FAILURE="false"
_ziro_defer_core_register "fb_t2" 5 "b" "_test_cmd_always_fail"
_ziro_defer_core_execute_task "fb_t2" 2>/dev/null
_ziro_test_assert_eq "1" "$_test_fb_count" "retry_on_failure=false: 1 attempt made"

# Test 3: task fails once, succeeds on retry -> status=success
_test_fb_count=0
_ZIRO_DEFER_RETRY_ON_FAILURE="true"
_ZIRO_DEFER_MAX_RETRIES="1"
_ziro_defer_core_register "fb_t3" 5 "b" "_test_cmd_succeed_second"
_ziro_defer_core_execute_task "fb_t3" 2>/dev/null
_ziro_test_assert_eq "2" "$_test_fb_count" "succeeds on 2nd attempt: 2 attempts made"
_ziro_test_assert_eq "success" "${_ziro_defer_task_status[fb_t3]}" "task status is success"

# Test 4: max_retries=2 -> 3 attempts
_test_fb_count=0
_ZIRO_DEFER_RETRY_ON_FAILURE="true"
_ZIRO_DEFER_MAX_RETRIES="2"
_ziro_defer_core_register "fb_t4" 5 "b" "_test_cmd_always_fail"
_ziro_defer_core_execute_task "fb_t4" 2>/dev/null
_ziro_test_assert_eq "3" "$_test_fb_count" "max_retries=2: 3 attempts made"

# Test 5: suppress_warnings controls stderr output
local warn_file="/tmp/ziro_test_warn_$$.txt"
_ZIRO_DEFER_RETRY_ON_FAILURE="false"
_ZIRO_DEFER_SUPPRESS_WARNINGS="true"
: > "$warn_file"
_ziro_defer_core_register "fb_t5" 5 "b" "_test_cmd_always_fail"
_ziro_defer_core_execute_task "fb_t5" 2> "$warn_file"
local warn_suppressed=0
[[ ! -s "$warn_file" ]] && warn_suppressed=1
_ziro_test_assert_eq "1" "$warn_suppressed" "suppress_warnings=true produces no warning"

_ZIRO_DEFER_SUPPRESS_WARNINGS="false"
: > "$warn_file"
_ziro_defer_core_register "fb_t6" 5 "b" "_test_cmd_always_fail"
_ziro_defer_core_execute_task "fb_t6" 2> "$warn_file"
local warn_emitted=0
[[ -s "$warn_file" ]] && warn_emitted=1
_ziro_test_assert_eq "1" "$warn_emitted" "suppress_warnings=false produces warning"
rm -f "$warn_file"

_ziro_test_summary
