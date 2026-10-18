#!/usr/bin/env zsh
# tests/test_before_enforcement.zsh - Chain model: --before enforcement and depends graph.
# Zero-fork assertions (native string matching, mapfile).

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

# Test 1: A --before=B (B exists) -> depends[B] includes A
ziro-defer --stage=5 --slot=b --name=bf_B1 "true"
ziro-defer --stage=5 --slot=b --name=bf_A1 --before=bf_B1 "true"
local b1_deps="${_ziro_defer_task_depends[bf_B1]:-}"
local has_a1=0
[[ "$b1_deps" == *"bf_A1"* ]] && has_a1=1
_ziro_test_assert_eq "1" "$has_a1" "B exists: depends[B] includes A"

# Test 2: A --before=B (B not yet registered) -> pending_before recorded, then B registered -> depends[B] includes A and pending cleared
ziro-defer --stage=5 --slot=b --name=bf_A2 --before=bf_B2 "true"
local pending_val="${_ziro_defer_task_pending_before[bf_A2]:-}"
_ziro_test_assert_eq "bf_B2" "$pending_val" "pending_before recorded before B registered"
ziro-defer --stage=5 --slot=b --name=bf_B2 "true"
local b2_deps="${_ziro_defer_task_depends[bf_B2]:-}"
local has_a2=0
[[ "$b2_deps" == *"bf_A2"* ]] && has_a2=1
_ziro_test_assert_eq "1" "$has_a2" "after B registered: depends[B] includes A"
local pending_cleared=0
[[ -z "${_ziro_defer_task_pending_before[bf_A2]:-}" ]] && pending_cleared=1
_ziro_test_assert_eq "1" "$pending_cleared" "pending_before cleared after B registered"

# Test 3: A --after=X --before=B -> depends[A]=X AND depends[B] includes A
ziro-defer --stage=5 --slot=b --name=bf_X3 "true"
ziro-defer --stage=5 --slot=b --name=bf_B3 "true"
ziro-defer --stage=5 --slot=b --name=bf_A3 --after=bf_X3 --before=bf_B3 "true"
local a3_deps="${_ziro_defer_task_depends[bf_A3]:-}"
local b3_deps="${_ziro_defer_task_depends[bf_B3]:-}"
local a3_has_x3=0 b3_has_a3=0
[[ "$a3_deps" == *"bf_X3"* ]] && a3_has_x3=1
[[ "$b3_deps" == *"bf_A3"* ]] && b3_has_a3=1
_ziro_test_assert_eq "1" "$a3_has_x3" "depends[A] includes X"
_ziro_test_assert_eq "1" "$b3_has_a3" "depends[B] includes A"

# Test 4: A --before=A (self-cycle) -> rejected
ziro-defer --stage=5 --slot=b --name=bf_self --before=bf_self "true" 2>/dev/null
local self_rc=$?
local self_failed=0
(( self_rc != 0 )) && self_failed=1
_ziro_test_assert_eq "1" "$self_failed" "self --before rejected"

# Test 5: A --after=B, B --after=A (mutual cycle) -> rejected
ziro-defer --stage=5 --slot=b --name=bf_cycA "true"
ziro-defer --stage=5 --slot=b --name=bf_cycB --after=bf_cycA "true"
ziro-defer --stage=5 --slot=b --name=bf_cycA2 --after=bf_cycB --before=bf_cycA "true" 2>/dev/null
local cyc_rc=$?
local cyc_failed=0
(( cyc_rc != 0 )) && cyc_failed=1
_ziro_test_assert_eq "1" "$cyc_failed" "mutual cycle rejected via depends graph"

# Test 6: Chain A -> B -> C: runs in C -> B -> A order
local out_file="/tmp/ziro_test_chain_$$.txt"
: > "$out_file"
ziro-defer --stage=5 --slot=b --name=ch_C "echo C >> $out_file"
ziro-defer --stage=5 --slot=b --name=ch_B --after=ch_C "echo B >> $out_file"
ziro-defer --stage=5 --slot=b --name=ch_A --after=ch_B "echo A >> $out_file"
ziro-defer-dispatch 5
local out_content="${mapfile[$out_file]}"
local -a lines=("${(f)out_content}")
(( ${#lines} > 0 )) && [[ -z "${lines[-1]}" ]] && lines[-1]=()
_ziro_test_assert_eq "C B A" "${(j: :)lines}" "chain runs in dependency order C B A"
rm -f "$out_file"

# Test 7: Multi-dependency: task waits for all prerequisites
local out_multi="/tmp/ziro_test_multi_$$.txt"
: > "$out_multi"
ziro-defer --stage=5 --slot=b --name=md_X "echo X >> $out_multi"
ziro-defer --stage=5 --slot=b --name=md_Y "echo Y >> $out_multi"
ziro-defer --stage=5 --slot=b --name=md_Z --after="md_X md_Y" "echo Z >> $out_multi"
ziro-defer-dispatch 5
local multi_content="${mapfile[$out_multi]}"
local -a multi_lines=("${(f)multi_content}")
(( ${#multi_lines} > 0 )) && [[ -z "${multi_lines[-1]}" ]] && multi_lines[-1]=()
_ziro_test_assert_eq "Z" "${multi_lines[-1]}" "multi-dep: Z runs last after both X and Y"
rm -f "$out_multi"

_ziro_test_summary
