#!/usr/bin/env zsh
# tests/test_cli.zsh - Phase 3a CLI tests.
# Zero forks: mapfile + native expansions, no subshell forks in assertions.

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
source "${0:A:h}/../api/ziro-defer.zsh"
source "${0:A:h}/../api/ziro-defer-batch.zsh"
source "${0:A:h}/../api/ziro-defer-dispatch.zsh"
source "${0:A:h}/../api/ziro-defer-bind-widget.zsh"
source "${0:A:h}/../api/ziro-defer-reorder.zsh"
source "${0:A:h}/../api/ziro-defer-stats.zsh"
source "${0:A:h}/_harness.zsh"

# Helper: assert file first line without fork (mapfile)
_ziro_test_file_first_line() {
  local file="$1"
  local c="${mapfile[$file]}"
  local -a lines=("${(f)c}")
  (( ${#lines} > 0 )) && [[ -z "${lines[-1]}" ]] && lines[-1]=()
  REPLY="${lines[1]:-}"
}

# Test 1: register via ziro-defer with all options
ziro-defer --stage=5 --slot=a --name=cli_t1 "echo hi"
_ziro_test_assert_eq "5" "${_ziro_defer_task_stage[cli_t1]}" "stage stored"
_ziro_test_assert_eq "a" "${_ziro_defer_task_slot[cli_t1]}" "slot stored"
_ziro_test_assert_eq "echo hi" "${_ziro_defer_task_cmd[cli_t1]}" "cmd stored"

# Test 2: default stage/slot
ziro-defer --name=cli_t2 "echo world"
_ziro_test_assert_eq "5" "${_ziro_defer_task_stage[cli_t2]}" "default stage=5"
_ziro_test_assert_eq "b" "${_ziro_defer_task_slot[cli_t2]}" "default slot=b"

# Test 3: dependency registration
ziro-defer --name=cli_t3 --after=cli_t1 "echo dep"
_ziro_test_assert_eq "cli_t1" "${_ziro_defer_task_after[cli_t3]}" "after stored"

# Test 4: reorder task
ziro-defer-reorder --task=cli_t2 --slot=c
_ziro_test_assert_eq "c" "${_ziro_defer_task_slot[cli_t2]}" "reordered to c"

# Test 5: reorder idempotent
ziro-defer-reorder --task=cli_t2 --slot=c
_ziro_test_assert_eq "c" "${_ziro_defer_task_slot[cli_t2]}" "reorder idempotent"

# Test 6: unknown option fails
ziro-defer --bogus=1 "echo x" 2>/dev/null
_ziro_test_assert_eq "1" "$?" "unknown option returns 1"

# Test 7: missing command fails
ziro-defer --name=cli_t_missing 2>/dev/null
_ziro_test_assert_eq "1" "$?" "missing cmd returns 1"

# Test 8: invalid stage fails
ziro-defer --stage=9 "echo x" 2>/dev/null
_ziro_test_assert_eq "1" "$?" "invalid stage returns 1"

# Test 9: dispatch runs queued task
local outfile="/tmp/ziro_cli_test_$$.txt"
: > "$outfile"
_ziro_defer_core_register "disp_t1" 5 "b" "echo ran >> $outfile"
ziro-defer-dispatch 5
_ziro_test_file_first_line "$outfile"
_ziro_test_assert_eq "ran" "$REPLY" "dispatch ran queued task"
rm -f "$outfile"

# Test 10: stats does not error when metrics file exists
_ziro_test_assert_status 0 "stats runs without error" ziro-defer-stats

# Test 11: batch registers multiple plugins
_ziro_defer_q_5_b=()
ziro-defer-batch --stage=5 --slot=b --source-mode=source /tmp/a.zsh /tmp/b.zsh
local has_batch_a=0 has_batch_b=0
[[ -n "${_ziro_defer_task_cmd[batch_a.zsh]:-}" ]] && has_batch_a=1
[[ -n "${_ziro_defer_task_cmd[batch_b.zsh]:-}" ]] && has_batch_b=1
_ziro_test_assert_eq "1" "$has_batch_a" "batch registered a.zsh"
_ziro_test_assert_eq "1" "$has_batch_b" "batch registered b.zsh"

_ziro_test_summary
