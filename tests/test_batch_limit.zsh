#!/usr/bin/env zsh
# tests/test_batch_limit.zsh - C-5: batch_size_limit chunking.
# Zero-fork assertions.

emulate -L zsh
set -u
zmodload zsh/mapfile 2>/dev/null

source "${0:A:h}/../core/version.zsh"
source "${0:A:h}/../core/queue.zsh"
source "${0:A:h}/../core/task-registry.zsh"
source "${0:A:h}/../api/ziro-defer.zsh"
source "${0:A:h}/../api/ziro-defer-batch.zsh"
source "${0:A:h}/../config/defaults.zsh"
source "${0:A:h}/_harness.zsh"

local err_file="/tmp/ziro_test_batch_err_$$.txt"

# Test 1: Within limit (5 plugins, limit=10) -> no warning
typeset -g _ZIRO_DEFER_BATCH_SIZE_LIMIT=10
local -a plugins_small=(b_p1 b_p2 b_p3 b_p4 b_p5)
: > "$err_file"
ziro-defer-batch "${plugins_small[@]}" 2> "$err_file"
local small_warn=0
[[ -s "$err_file" ]] && small_warn=1
_ziro_test_assert_eq "0" "$small_warn" "batch within limit produces no warning"

# Test 2: Exceeding limit (15 plugins, limit=10) -> split warning emitted
: > "$err_file"
local -a plugins_large=(b_q1 b_q2 b_q3 b_q4 b_q5 b_q6 b_q7 b_q8 b_q9 b_q10 b_q11 b_q12 b_q13 b_q14 b_q15)
ziro-defer-batch "${plugins_large[@]}" 2> "$err_file"
local err_text="${mapfile[$err_file]}"
local has_split_warn=0
[[ "$err_text" == *"splitting into 2 batches"* ]] && has_split_warn=1
_ziro_test_assert_eq "1" "$has_split_warn" "exceeding limit emits splitting warning"

# Test 3: All 15 plugins are registered after chunking
local all_registered=1
local p
# @O(n)-justified: verify all 15 plugins exist in registry. Zero-fork per iteration.
for p in "${plugins_large[@]}"; do
  _ziro_defer_core_has_task "batch_${p}" || all_registered=0
done
_ziro_test_assert_eq "1" "$all_registered" "all 15 chunked plugins registered"

# Test 4: Custom slot and stage preserved across chunks
local -a plugins_custom=(b_c1 b_c2)
ziro-defer-batch --stage=6 --slot=c "${plugins_custom[@]}" 2>/dev/null
_ziro_test_assert_eq "6" "${_ziro_defer_task_stage[batch_b_c1]}" "stage preserved across batch"
_ziro_test_assert_eq "c" "${_ziro_defer_task_slot[batch_b_c1]}" "slot preserved across batch"

rm -f "$err_file"

_ziro_test_summary
