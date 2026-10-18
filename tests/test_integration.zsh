#!/usr/bin/env zsh
# tests/test_integration.zsh - Phase 5: end-to-end integration.
# Registers → dispatches → metrics → stats. Zero-fork assertions.

emulate -L zsh
set -u
zmodload zsh/mapfile 2>/dev/null

source "${0:A:h}/../core/version.zsh"
source "${0:A:h}/../lib/timer.zsh"
source "${0:A:h}/../lib/json-writer.zsh"
source "${0:A:h}/../lib/cycle-detect.zsh"
source "${0:A:h}/../lib/condition-eval.zsh"
source "${0:A:h}/../core/queue.zsh"
source "${0:A:h}/../core/task-registry.zsh"
source "${0:A:h}/../core/scheduler.zsh"
source "${0:A:h}/../lib/cache-io.zsh"
source "${0:A:h}/../api/ziro-defer.zsh"
source "${0:A:h}/../api/ziro-defer-dispatch.zsh"
source "${0:A:h}/../api/ziro-defer-stats.zsh"
source "${0:A:h}/../api/ziro-defer-reorder.zsh"
source "${0:A:h}/_harness.zsh"

# Sandbox cache
export XDG_CACHE_HOME="/tmp/ziro_test_int_$$"
mkdir -p "$XDG_CACHE_HOME/ziro/defer"
source "${0:A:h}/../lib/cache-io.zsh"

# Test 1: full lifecycle (register 3 tasks, dispatch, verify order)
local outfile="/tmp/ziro_int_$$.txt"
: > "$outfile"
ziro-defer --stage=5 --slot=b --name=int_a "echo A >> $outfile"
ziro-defer --stage=5 --slot=b --name=int_b --after=int_a "echo B >> $outfile"
ziro-defer --stage=5 --slot=c --name=int_c "echo C >> $outfile"
ziro-defer-dispatch 5
local content="${mapfile[$outfile]}"
local -a lines=("${(f)content}")
(( ${#lines} > 0 )) && [[ -z "${lines[-1]}" ]] && lines[-1]=()
_ziro_test_assert_eq "A B C" "${(j: :)lines}" "execution order: slot-b then slot-c, dep-respecting"
_ziro_test_assert_eq "success" "${_ziro_defer_task_status[int_a]}" "int_a success"
_ziro_test_assert_eq "success" "${_ziro_defer_task_status[int_b]}" "int_b success"
_ziro_test_assert_eq "success" "${_ziro_defer_task_status[int_c]}" "int_c success"
rm -f "$outfile"

# Test 2: metrics file exists after dispatch
local metrics_file="${XDG_CACHE_HOME}/ziro/defer/metrics.jsonl"
local has_mfile=0 has_a=0 has_c=0
[[ -r "$metrics_file" ]] && has_mfile=1
_ziro_test_assert_eq "1" "$has_mfile" "metrics file created"
local m_content="${mapfile[$metrics_file]}"
[[ "$m_content" == *'int_a'* ]] && has_a=1
[[ "$m_content" == *'int_c'* ]] && has_c=1
_ziro_test_assert_eq "1" "$has_a" "metrics has int_a"
_ziro_test_assert_eq "1" "$has_c" "metrics has int_c"

# Test 3: stats reads metrics
_ziro_test_assert_status 0 "stats after dispatch" ziro-defer-stats

# Test 4: condition skip in full pipeline
ziro-defer --stage=5 --slot=b --name=int_skip --if-cmd=__nonexistent_xyz__ "echo SHOULD_NOT_RUN"
ziro-defer-dispatch 5
_ziro_test_assert_eq "skipped" "${_ziro_defer_task_status[int_skip]}" "condition skipped in dispatch"

# Test 5: reorder works in full pipeline
ziro-defer --stage=5 --slot=d --name=int_reord "echo R"
ziro-defer-reorder --task=int_reord --slot=a
_ziro_test_assert_eq "a" "${_ziro_defer_task_slot[int_reord]}" "reorder to slot a"

# Cleanup
rm -rf "$XDG_CACHE_HOME" 2>/dev/null || true

_ziro_test_summary
