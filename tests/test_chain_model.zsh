#!/usr/bin/env zsh
# tests/test_chain_model.zsh - Chain model end-to-end (depends graph, --depends flag, chains).
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

# Test 1: --depends flag sets depends graph identically to --after
ziro-defer --stage=5 --slot=b --name=cm_dep1 "true"
ziro-defer --stage=5 --slot=b --name=cm_task1 --depends=cm_dep1 "true"
_ziro_test_assert_eq "cm_dep1" "${_ziro_defer_task_depends[cm_task1]}" "--depends sets depends graph"

# Test 2: Deep 4-level chain: A --depends=B, B --depends=C, C --depends=D -> runs D -> C -> B -> A
local out_deep="/tmp/ziro_test_cm_deep_$$.txt"
: > "$out_deep"
ziro-defer --stage=5 --slot=b --name=deep_D "echo D >> $out_deep"
ziro-defer --stage=5 --slot=b --name=deep_C --depends=deep_D "echo C >> $out_deep"
ziro-defer --stage=5 --slot=b --name=deep_B --depends=deep_C "echo B >> $out_deep"
ziro-defer --stage=5 --slot=b --name=deep_A --depends=deep_B "echo A >> $out_deep"
ziro-defer-dispatch 5
local deep_content="${mapfile[$out_deep]}"
local -a deep_lines=("${(f)deep_content}")
(( ${#deep_lines} > 0 )) && [[ -z "${deep_lines[-1]}" ]] && deep_lines[-1]=()
_ziro_test_assert_eq "D C B A" "${(j: :)deep_lines}" "deep 4-level chain executes D -> C -> B -> A"
rm -f "$out_deep"

# Test 3: Diamond dependency: D -> (B, C) -> A
local out_diam="/tmp/ziro_test_cm_diam_$$.txt"
: > "$out_diam"
ziro-defer --stage=5 --slot=b --name=dm_D "echo D >> $out_diam"
ziro-defer --stage=5 --slot=b --name=dm_B --depends=dm_D "echo B >> $out_diam"
ziro-defer --stage=5 --slot=b --name=dm_C --depends=dm_D "echo C >> $out_diam"
ziro-defer --stage=5 --slot=b --name=dm_A --depends="dm_B dm_C" "echo A >> $out_diam"
ziro-defer-dispatch 5
local diam_content="${mapfile[$out_diam]}"
local -a diam_lines=("${(f)diam_content}")
(( ${#diam_lines} > 0 )) && [[ -z "${diam_lines[-1]}" ]] && diam_lines[-1]=()
_ziro_test_assert_eq "D" "${diam_lines[1]}" "diamond: D runs first"
_ziro_test_assert_eq "A" "${diam_lines[-1]}" "diamond: A runs last"
local dm_middle="${diam_lines[2]} ${diam_lines[3]}"
local valid_middle=0
[[ "$dm_middle" == "B C" || "$dm_middle" == "C B" ]] && valid_middle=1
_ziro_test_assert_eq "1" "$valid_middle" "diamond: B and C run between D and A"
rm -f "$out_diam"

# Test 4: Mixed --after and --before on same registration
ziro-defer --stage=5 --slot=b --name=mx_X "true"
ziro-defer --stage=5 --slot=b --name=mx_B "true"
ziro-defer --stage=5 --slot=b --name=mx_A --after=mx_X --before=mx_B "true"
local mx_a_deps="${_ziro_defer_task_depends[mx_A]:-}"
local mx_b_deps="${_ziro_defer_task_depends[mx_B]:-}"
local mx_a_ok=0 mx_b_ok=0
[[ "$mx_a_deps" == *"mx_X"* ]] && mx_a_ok=1
[[ "$mx_b_deps" == *"mx_A"* ]] && mx_b_ok=1
_ziro_test_assert_eq "1" "$mx_a_ok" "mixed: depends[A] contains after target X"
_ziro_test_assert_eq "1" "$mx_b_ok" "mixed: depends[B] contains before task A"

# Test 5: pending_before resolution
ziro-defer --stage=5 --slot=b --name=pb_early --before=pb_late "true"
local pb_recorded=0
[[ -n "${_ziro_defer_task_pending_before[pb_early]:-}" ]] && pb_recorded=1
_ziro_test_assert_eq "1" "$pb_recorded" "pending_before recorded for missing target"
ziro-defer --stage=5 --slot=b --name=pb_late "true"
local pb_resolved=0
[[ "${_ziro_defer_task_depends[pb_late]:-}" == *"pb_early"* ]] && pb_resolved=1
_ziro_test_assert_eq "1" "$pb_resolved" "pending_before resolved when target registers"

# Test 6: unregister clears depends entry
_ziro_defer_core_unregister "pb_late"
local pb_late_cleared=0
[[ -z "${_ziro_defer_task_depends[pb_late]:-}" ]] && pb_late_cleared=1
_ziro_test_assert_eq "1" "$pb_late_cleared" "unregister clears depends entry"

# Test 7: 3-node cycle detection via DFS walk
_ziro_defer_core_register "cm_cyc1" 5 "b" "true"
_ziro_defer_core_register "cm_cyc2" 5 "b" "true" "cm_cyc1"
_ziro_defer_core_register "cm_cyc3" 5 "b" "true" "cm_cyc2"
_ziro_test_assert_status 1 "3-node cycle cm_cyc1 -> cm_cyc3 blocked" _ziro_defer_lib_detect_cycle "cm_cyc1" "cm_cyc3"

# Test 8: multiple --depends flags append rather than overwrite
ziro-defer --stage=5 --slot=b --name=mf_t1 "true"
ziro-defer --stage=5 --slot=b --name=mf_t2 "true"
ziro-defer --stage=5 --slot=b --name=mf_target --depends=mf_t1 --depends=mf_t2 "true"
_ziro_test_assert_eq "mf_t1 mf_t2" "${_ziro_defer_task_depends[mf_target]}" "multiple --depends append"

# Test 9: --depends with space-separated string stores all prerequisites
ziro-defer --stage=5 --slot=b --name=sp_target --depends="p1 p2 p3" "true"
_ziro_test_assert_eq "p1 p2 p3" "${_ziro_defer_task_depends[sp_target]}" "space-separated --depends stores all prerequisites"

# Test 10: Task with no dependencies runs immediately without hold
ziro-defer --stage=5 --slot=b --name=nodep_task "true"
_ziro_defer_core_execute_task "nodep_task"
local nodep_rc=$?
_ziro_test_assert_eq "0" "$nodep_rc" "task with no dependencies executes immediately"

_ziro_test_summary
