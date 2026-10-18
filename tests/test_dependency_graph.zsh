#!/usr/bin/env zsh
# tests/test_dependency_graph.zsh - Phase 5: dependency + cycle tests (chain model).
# Per RULES R12.1 and Spec 005 §7. Zero-fork assertions.

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
source "${0:A:h}/../api/ziro-defer-dispatch.zsh"
source "${0:A:h}/_harness.zsh"

# Test 1: --after=X stored in depends graph
_ziro_defer_core_register "dg_depA" 5 "b" "true"
_ziro_defer_core_register "dg_depB" 5 "b" "true" "dg_depA"
_ziro_test_assert_eq "dg_depA" "${_ziro_defer_task_depends[dg_depB]}" "--after stored in depends graph"

# Test 2: --after="X Y" multi-dep stored in depends graph
_ziro_defer_core_register "dg_depC" 5 "b" "true" "dg_depA dg_depB"
_ziro_test_assert_eq "dg_depA dg_depB" "${_ziro_defer_task_depends[dg_depC]}" "multi-dep stored in depends graph"

# Test 3: --before=B -> depends[B] includes A
_ziro_defer_core_register "dg_depPre" 5 "b" "true" "" "dg_depB"
local depb_deps="${_ziro_defer_task_depends[dg_depB]:-}"
local has_pre=0
[[ "$depb_deps" == *"dg_depPre"* ]] && has_pre=1
_ziro_test_assert_eq "1" "$has_pre" "--before target has dependency added"

# Test 4: Cycle detection blocks registration via depends graph
_ziro_defer_task_depends[dg_depA]="dg_depB"
_ziro_test_assert_status 1 "cycle A->B->A blocked" _ziro_defer_core_cycle_check "dg_depB" "dg_depA"
_ziro_defer_task_depends[dg_depA]=""

# Test 5: Dependency gate holds task when prerequisite is pending (fast path)
_ziro_defer_task_depends[dg_depB]="dg_depA"
_ziro_defer_task_status[dg_depA]="pending"
_ziro_test_assert_status 1 "depB held when single prereq pending (fast path)" _ziro_defer_core_execute_task "dg_depB"

# Test 6: Dependency gate releases when single prerequisite is terminal (fast path)
_ziro_defer_task_status[dg_depA]="success"
_ziro_test_assert_status 0 "depB runs when single prereq success (fast path)" _ziro_defer_core_execute_task "dg_depB"

# Test 7: Multi-dep gate holds when any prerequisite is pending (slow path)
_ziro_defer_task_depends[dg_depMulti]="dg_m1 dg_m2"
_ziro_defer_core_register "dg_m1" 5 "b" "true"
_ziro_defer_core_register "dg_m2" 5 "b" "true"
_ziro_defer_core_register "dg_depMulti" 5 "b" "true" "dg_m1 dg_m2"
_ziro_defer_task_status[dg_m1]="success"
_ziro_defer_task_status[dg_m2]="pending"
_ziro_test_assert_status 1 "multi-dep held when one prereq is pending" _ziro_defer_core_execute_task "dg_depMulti"

# Test 8: Multi-dep gate releases when all prerequisites are terminal
_ziro_defer_task_status[dg_m2]="success"
_ziro_test_assert_status 0 "multi-dep runs when all prereqs are terminal" _ziro_defer_core_execute_task "dg_depMulti"

# Test 9: Unknown dependency emits warning but proceeds (RULES R7.5)
local warn_file="/tmp/ziro_test_dg_warn_$$.txt"
_ziro_defer_core_register "dg_orphan" 5 "b" "true" "nonexistent_task_xyz"
_ziro_defer_core_execute_task "dg_orphan" 2> "$warn_file"
local orphan_status=$?
local has_warn=0
[[ -s "$warn_file" ]] && has_warn=1
_ziro_test_assert_eq "0" "$orphan_status" "orphan runs with unknown dependency"
_ziro_test_assert_eq "1" "$has_warn" "orphan emits warning for unknown dependency"
rm -f "$warn_file"

# Test 10: Chain execution order in dispatch
local chain_out="/tmp/ziro_test_dg_chain_$$.txt"
: > "$chain_out"
ziro-defer --stage=5 --slot=b --name=dg_c3 "echo 3 >> $chain_out"
ziro-defer --stage=5 --slot=b --name=dg_c2 --after=dg_c3 "echo 2 >> $chain_out"
ziro-defer --stage=5 --slot=b --name=dg_c1 --after=dg_c2 "echo 1 >> $chain_out"
ziro-defer-dispatch 5
local chain_content="${mapfile[$chain_out]}"
local -a lines=("${(f)chain_content}")
(( ${#lines} > 0 )) && [[ -z "${lines[-1]}" ]] && lines[-1]=()
_ziro_test_assert_eq "3 2 1" "${(j: :)lines}" "chain executes in 3 -> 2 -> 1 order"
rm -f "$chain_out"

_ziro_test_summary
