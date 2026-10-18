#!/usr/bin/env zsh
# tests/test_observability.zsh - Phase 5: JSONL metrics + stats.
# Per RULES R12.1 and R10. Zero-fork assertions.

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
source "${0:A:h}/../lib/cache-io.zsh"
source "${0:A:h}/../api/ziro-defer-stats.zsh"
source "${0:A:h}/_harness.zsh"

# Sandbox cache
local saved_xdg="${XDG_CACHE_HOME:-}"
export XDG_CACHE_HOME="/tmp/ziro_test_obs_$$"
mkdir -p "$XDG_CACHE_HOME/ziro/defer"
source "${0:A:h}/../lib/cache-io.zsh"

_ziro_defer_core_emit_metric() {
  emulate -L zsh
  local task_id="$1" elapsed_ms="$2" task_status="$3"
  local metrics_file="${XDG_CACHE_HOME}/ziro/defer/metrics.jsonl"
  local cmd="${_ziro_defer_task_cmd[$task_id]:-test}"
  local stage="${_ziro_defer_task_stage[$task_id]:-5}"
  local slot="${_ziro_defer_task_slot[$task_id]:-b}"
  local record
  _ziro_defer_lib_json_record "$EPOCHREALTIME" "$cmd" "$task_id" "$stage" "$slot" "$elapsed_ms" "$task_status" "false" "0"
  record=$REPLY
  print -r -- "$record" >> "$metrics_file"
}

# Test 1: metric line emitted and valid JSON shape
_ziro_defer_task_cmd[obs_t1]="echo hi"
_ziro_defer_task_stage[obs_t1]=5
_ziro_defer_task_slot[obs_t1]="b"
_ziro_defer_core_emit_metric "obs_t1" 12.34 "success"
local metrics_file="${XDG_CACHE_HOME}/ziro/defer/metrics.jsonl"
local content="${mapfile[$metrics_file]}"
local has_name=0 has_status=0 has_stage=0
[[ "$content" == *'"name":"obs_t1"'* ]] && has_name=1
[[ "$content" == *'"status":"success"'* ]] && has_status=1
[[ "$content" == *'"stage":5'* ]] && has_stage=1
_ziro_test_assert_eq "1" "$has_name" "metric has name"
_ziro_test_assert_eq "1" "$has_status" "metric has status"
_ziro_test_assert_eq "1" "$has_stage" "metric has stage"

# Test 2: multiple metrics accumulate
_ziro_defer_core_emit_metric "obs_t1" 10.0 "success"
_ziro_defer_core_emit_metric "obs_t1" 20.0 "failure"
content="${mapfile[$metrics_file]}"
local -a metric_lines=("${(f)content}")
local lines_ge_3=0
(( ${#metric_lines[@]} >= 3 )) && lines_ge_3=1
_ziro_test_assert_eq "1" "$lines_ge_3" "3+ metric lines accumulated"

# Test 3: stats command produces output
_ziro_test_assert_status 0 "stats runs" ziro-defer-stats

# Test 4: stats output mentions stage summary
local stats_file="${XDG_CACHE_HOME}/stats_out.txt"
ziro-defer-stats > "$stats_file" 2>/dev/null
local stats_out="${mapfile[$stats_file]}"
local has_summary=0 has_records=0
[[ "$stats_out" == *'Stage Summary'* ]] && has_summary=1
[[ "$stats_out" == *'Total records'* ]] && has_records=1
_ziro_test_assert_eq "1" "$has_summary" "stats has Stage Summary"
_ziro_test_assert_eq "1" "$has_records" "stats has Total records"

# Cleanup
rm -rf "$XDG_CACHE_HOME" 2>/dev/null || true
if [[ -n "$saved_xdg" ]]; then
  export XDG_CACHE_HOME="$saved_xdg"
fi

_ziro_test_summary
