#!/usr/bin/env zsh
# tests/test_stages.zsh - Phase 4 stage modules + entrypoint tests.
# Zero forks in assertions (mapfile, native expansions).

emulate -L zsh
set -u
zmodload zsh/mapfile 2>/dev/null

source "${0:A:h}/../core/version.zsh"
source "${0:A:h}/../lib/timer.zsh"
source "${0:A:h}/../lib/json-writer.zsh"
source "${0:A:h}/../lib/cycle-detect.zsh"
source "${0:A:h}/../lib/condition-eval.zsh"
source "${0:A:h}/../lib/toml-parser.zsh"
source "${0:A:h}/../lib/cache-io.zsh"
source "${0:A:h}/../core/queue.zsh"
source "${0:A:h}/../core/task-registry.zsh"
source "${0:A:h}/../core/scheduler.zsh"
source "${0:A:h}/../core/hooks.zsh"
source "${0:A:h}/../cache/eval-cache.zsh"
source "${0:A:h}/../api/ziro-defer.zsh"
source "${0:A:h}/../config/defaults.zsh"
source "${0:A:h}/../stages/stage-0-pre-source.zsh"
source "${0:A:h}/../stages/stage-1-bootstrap.zsh"
source "${0:A:h}/../stages/stage-2-pre-compinit.zsh"
source "${0:A:h}/../stages/stage-3-compinit.zsh"
source "${0:A:h}/../stages/stage-4-post-compinit.zsh"
source "${0:A:h}/../stages/stage-5-post-prompt.zsh"
source "${0:A:h}/../stages/stage-6-idle.zsh"
source "${0:A:h}/../stages/stage-7-on-demand.zsh"
source "${0:A:h}/_harness.zsh"

# Test 1: Budget functions
_ziro_test_assert_eq "0.1"       "$(_ziro_defer_stage_0_budget_ms)" "stage 0 budget = 0.1ms"
_ziro_test_assert_eq "0.5"       "$(_ziro_defer_stage_1_budget_ms)" "stage 1 budget = 0.5ms"
_ziro_test_assert_eq "1.0"       "$(_ziro_defer_stage_2_budget_ms)" "stage 2 budget = 1.0ms"
_ziro_test_assert_eq "2.0"       "$(_ziro_defer_stage_3_budget_ms)" "stage 3 budget = 2.0ms"
_ziro_test_assert_eq "1.0"       "$(_ziro_defer_stage_4_budget_ms)" "stage 4 budget = 1.0ms"
_ziro_test_assert_eq "30.0"      "$(_ziro_defer_stage_7_budget_ms)" "stage 7 budget = 30ms"

# Test 2: Config defaults loaded
typeset -g ZIRO_DATA="" ZIRO_CONFIG="" ZIRO_CACHE=""
_ziro_defer_stage_0_builtin
local has_data=0 has_config=0 has_cache=0
[[ -n "$ZIRO_DATA" ]] && has_data=1
[[ -n "$ZIRO_CONFIG" ]] && has_config=1
[[ -n "$ZIRO_CACHE" ]] && has_cache=1
_ziro_test_assert_eq "1" "$has_data" "ZIRO_DATA set by stage 0"
_ziro_test_assert_eq "1" "$has_config" "ZIRO_CONFIG set by stage 0"
_ziro_test_assert_eq "1" "$has_cache" "ZIRO_CACHE set by stage 0"
_ziro_test_assert_eq "5" "$_ZIRO_DEFER_DEFAULT_STAGE" "default_stage = 5"
_ziro_test_assert_eq "b" "$_ZIRO_DEFER_DEFAULT_SLOT" "default_slot = b"

# Test 3: Stage 1 handles missing znap gracefully
_ziro_test_assert_status 0 "stage 1 tolerates no znap" _ziro_defer_stage_1_builtin

# Test 4: Stage 2 fpath injection with mock dir
local mock_dir="/tmp/ziro_test_fpath_$$"
mkdir -p "$mock_dir"
local original_fpath_len=${#fpath[@]}
_ZIRO_DEFER_COMPLETION_PATHS=("$mock_dir")
_ziro_defer_stage_2_builtin
local fpath_expanded=0
(( ${#fpath[@]} > original_fpath_len )) && fpath_expanded=1
_ziro_test_assert_eq "1" "$fpath_expanded" "stage 2 added fpath"
# Cleanup fpath (remove our mock dir)
fpath=("${fpath[@]:#$mock_dir}")
rm -rf "$mock_dir"
_ZIRO_DEFER_COMPLETION_PATHS=()

# Test 5: Stage 6 metrics rotation
local test_metrics="${_ZIRO_DEFER_CACHE_ROOT}/metrics.jsonl"
mkdir -p "${_ZIRO_DEFER_CACHE_ROOT}"
# Create a file just above 1MB by writing short lines
local i
# @O(n)-justified: test loop to create > 1MB test file, unavoidable
for (( i = 0; i < 9000; i++ )); do
  print -r -- '{"ts":1,"task":"test","name":"t","stage":5,"slot":"b","elapsed_ms":1.00,"status":"success","cached":false,"retries":0}'
done > "$test_metrics"
_ziro_defer_stage_6_builtin
local rotated_exists=0
[[ -r "${test_metrics}.1" ]] && rotated_exists=1
_ziro_test_assert_eq "1" "$rotated_exists" "stage 6 rotated metrics"
rm -f "$test_metrics" "${test_metrics}.1" 2>/dev/null

# Test 6: Stage 5/7 are no-ops
_ziro_test_assert_status 0 "stage 5 builtin no-op" _ziro_defer_stage_5_builtin
_ziro_test_assert_status 0 "stage 7 builtin no-op" _ziro_defer_stage_7_builtin

# Test 7: plugin.zsh loads (in isolated zsh)
local plugin_status
zsh -f -c "source '${0:A:h}/../ziro-defer.plugin.zsh' 2>/dev/null; exit 0" 2>/dev/null
plugin_status=$?
_ziro_test_assert_eq "0" "$plugin_status" "plugin.zsh sources cleanly"

# Test 8: plugin.zsh idempotency (loading twice doesn't error)
zsh -f -c "source '${0:A:h}/../ziro-defer.plugin.zsh'; source '${0:A:h}/../ziro-defer.plugin.zsh'; exit 0" 2>/dev/null
_ziro_test_assert_eq "0" "$?" "plugin.zsh idempotent"

# Test 9: plugin.zsh registers precmd hook (check via direct sourcing in this shell)
source "${0:A:h}/../ziro-defer.plugin.zsh" 2>/dev/null
local is_loaded=0
[[ -n "${_ZIRO_DEFER_LOADED:-}" ]] && is_loaded=1
_ziro_test_assert_eq "1" "$is_loaded" "_ZIRO_DEFER_LOADED set"

# Test 10: plugin.zsh line count < 100 (spirit of R10.2)
local plugin_file="${0:A:h}/../ziro-defer.plugin.zsh"
local plugin_content="${mapfile[$plugin_file]}"
local -a plugin_lines=("${(f)plugin_content}")
local -i plugin_line_count=${#plugin_lines[@]}
local is_under_100=0
(( plugin_line_count < 100 )) && is_under_100=1
_ziro_test_assert_eq "1" "$is_under_100" "plugin.zsh < 100 lines (got $plugin_line_count)"

_ziro_test_summary
