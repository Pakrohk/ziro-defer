#!/usr/bin/env zsh
# tests/test_scheduler_smoke.zsh - Phase 2 smoke test.
# Zero-fork assertions: uses mapfile + ${(f)} + ${(j: :)} instead of tr/sed.

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
source "${0:A:h}/../lib/toml-parser.zsh"
source "${0:A:h}/../core/scheduler.zsh"
source "${0:A:h}/../core/hooks.zsh"
source "${0:A:h}/_harness.zsh"

# Helper: read file content into REPLY without fork (mapfile module)
_ziro_test_read_file() {
  REPLY="${mapfile[$1]}"
}

# Helper: assert file content equals joined-by-space string
_ziro_test_assert_file_joined() {
  local expected="$1" file="$2" msg="$3"
  local -a lines=()
  _ziro_test_read_file "$file"
  lines=("${(f)REPLY}")
  # Trim trailing empty (files end with \n)
  (( ${#lines} > 0 )) && [[ -z "${lines[-1]}" ]] && lines[-1]=()
  _ziro_test_assert_eq "$expected" "${(j: :)lines}" "$msg"
}

# Test 1: Conditions
_ziro_test_assert_status 0 "if-cmd=zsh exists" _ziro_defer_lib_eval_condition "if-cmd=zsh"
_ziro_test_assert_status 1 "if-cmd=nonexistent fails" _ziro_defer_lib_eval_condition "if-cmd=__nonexistent_xyz__"
_ziro_test_assert_status 0 "if-not-root (normal user)" _ziro_defer_lib_eval_condition "if-not-root"

# Test 2: JSON record (no fork — uses local var pattern)
_ziro_defer_lib_json_record "1234.5" "cmd with \"quotes\"" "t1" "5" "b" "12.42" "success" "false" "0"
local json="$REPLY"
local has_name=0 has_elapsed=0
[[ "$json" == *'"name":"t1"'* ]] && has_name=1
[[ "$json" == *'"elapsed_ms":12.42'* ]] && has_elapsed=1
_ziro_test_assert_eq "1" "$has_name" "JSON has name"
_ziro_test_assert_eq "1" "$has_elapsed" "JSON has elapsed_ms"

# Test 3: Cycle detection
_ziro_defer_task_after=()
_ziro_test_assert_status 0 "No cycle A->B" _ziro_defer_lib_detect_cycle "A" "B"
_ziro_defer_task_after[B]="A"
_ziro_test_assert_status 1 "Cycle A->B->A" _ziro_defer_lib_detect_cycle "A" "B"
_ziro_defer_task_after=()

# Test 4: End-to-end dispatch
local outfile="/tmp/ziro_defer_smoke_$$.txt"
: > "$outfile"
_ziro_defer_core_register "smoke1" 5 "b" "echo hello >> $outfile"
_ziro_defer_core_register "smoke2" 5 "b" "echo world >> $outfile"
_ziro_defer_core_dispatch_stage 5
_ziro_test_assert_file_joined "hello world" "$outfile" "Both tasks executed"
_ziro_test_assert_eq "success" "${_ziro_defer_task_status[smoke1]}" "smoke1 success"
_ziro_test_assert_eq "success" "${_ziro_defer_task_status[smoke2]}" "smoke2 success"
rm -f "$outfile"

# Test 5: Dependency order (both ready in same dispatch)
local outfile2="/tmp/ziro_defer_smoke2_$$.txt"
: > "$outfile2"
_ziro_defer_core_register "dA" 5 "b" "echo A >> $outfile2"
_ziro_defer_core_register "dB" 5 "b" "echo B >> $outfile2" "dA"
_ziro_defer_core_dispatch_stage 5
_ziro_test_assert_file_joined "A B" "$outfile2" "Dependency A->B order preserved"
rm -f "$outfile2"

# Test 6: Held task retry (dependency not yet ready in first pass)
# hB in slot a runs before hA in slot b. First dispatch: hB held, hA executes.
# Second dispatch: hB executes.
local outfile3="/tmp/ziro_defer_smoke3_$$.txt"
: > "$outfile3"
_ziro_defer_core_register "hB" 5 "a" "echo B >> $outfile3" "hA"
_ziro_defer_core_register "hA" 5 "b" "echo A >> $outfile3"
_ziro_defer_core_dispatch_stage 5
_ziro_test_assert_eq "success" "${_ziro_defer_task_status[hA]}" "hA executed in first pass"
_ziro_test_assert_eq "success" "${_ziro_defer_task_status[hB]}" "hB executed in same dispatch via retry"
_ziro_test_assert_file_joined "A B" "$outfile3" "First pass: A then B ran"
_ziro_defer_core_dispatch_stage 5
_ziro_test_assert_file_joined "A B" "$outfile3" "Second pass: idempotent"
rm -f "$outfile3"

# Test 7: Skipped condition
_ziro_defer_core_register "skipme" 5 "b" "echo SHOULD_NOT_RUN" "" "" "if-cmd=__nonexistent_xyz__"
_ziro_defer_core_dispatch_stage 5
_ziro_test_assert_eq "skipped" "${_ziro_defer_task_status[skipme]}" "Condition false -> skipped"

_ziro_test_summary
