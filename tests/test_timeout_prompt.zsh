#!/usr/bin/env zsh
# tests/test_timeout_prompt.zsh - C-3: interactive timeout prompt and skip/quit flags.
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
source "${0:A:h}/../api/ziro-defer.zsh"
source "${0:A:h}/../api/ziro-defer-dispatch.zsh"
source "${0:A:h}/_harness.zsh"

# Test 1: Non-TTY (test runner environment) does not prompt
unset _ZIRO_DEFER_TIMEOUT_PROMPTED 2>/dev/null || true
_ZIRO_DEFER_INTERACTIVE_TIMEOUT_PROMPT="true"
local err_file="/tmp/ziro_test_prompt_$$.txt"
: > "$err_file"
_ziro_defer_core_maybe_timeout_prompt "prompt_t1" 100 2> "$err_file"
local has_prompt_text=0
[[ -s "$err_file" ]] && has_prompt_text=1
_ziro_test_assert_eq "0" "$has_prompt_text" "non-TTY skips prompt without output"
rm -f "$err_file"

# Test 2: Once-per-session guard prevents repeated prompt
typeset -g _ZIRO_DEFER_TIMEOUT_PROMPTED=1
_ziro_defer_core_maybe_timeout_prompt "prompt_t2" 100
_ziro_test_assert_eq "1" "$_ZIRO_DEFER_TIMEOUT_PROMPTED" "guard flag remains set"
unset _ZIRO_DEFER_TIMEOUT_PROMPTED

# Test 3: Disabled via configuration
_ZIRO_DEFER_INTERACTIVE_TIMEOUT_PROMPT="false"
_ziro_defer_core_maybe_timeout_prompt "prompt_t3" 100
local prompted_when_disabled=0
[[ -n "${_ZIRO_DEFER_TIMEOUT_PROMPTED:-}" ]] && prompted_when_disabled=1
_ziro_test_assert_eq "0" "$prompted_when_disabled" "disabled config prevents prompt"
_ZIRO_DEFER_INTERACTIVE_TIMEOUT_PROMPT="true"

# Test 4: Timeout sets task status to 'timeout'
_ziro_defer_core_register "to_t1" 5 "b" "sleep 0.05" "" "" "" 10
_ziro_defer_core_execute_task "to_t1" 2>/dev/null
_ziro_test_assert_eq "timeout" "${_ziro_defer_task_status[to_t1]}" "task marked timeout when elapsed > timeout"

# Test 5: _ZIRO_DEFER_SKIP_STAGE breaks out of dispatch for remaining tasks
ziro-defer --stage=5 --slot=b --name=to_skip1 "typeset -g _ZIRO_DEFER_SKIP_STAGE=1"
ziro-defer --stage=5 --slot=b --name=to_skip2 "true"
ziro-defer-dispatch 5
_ziro_test_assert_eq "success" "${_ziro_defer_task_status[to_skip1]}" "first task executed"
_ziro_test_assert_eq "pending" "${_ziro_defer_task_status[to_skip2]}" "subsequent task skipped when stage skipped"

_ziro_test_summary
