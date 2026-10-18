#!/usr/bin/env zsh
# tests/test_priority_slots.zsh - Verify O(1) queue + slot precedence.
# Per RULES R12.1: covers push/pop FIFO, size, remove, cross-slot ordering,
# and task-registry integration.

emulate -L zsh
set -u
source "${0:A:h}/../core/version.zsh"
source "${0:A:h}/../core/queue.zsh"
source "${0:A:h}/../core/task-registry.zsh"
source "${0:A:h}/_harness.zsh"

# ─── Test 1: Push/Pop FIFO within same slot ───
_ziro_defer_core_queue_push 5 a task1
_ziro_defer_core_queue_push 5 a task2
_ziro_defer_core_queue_push 5 a task3

_ziro_defer_core_queue_pop 5 a
_ziro_test_assert_eq "task1" "$REPLY" "FIFO pop 1"
_ziro_defer_core_queue_pop 5 a
_ziro_test_assert_eq "task2" "$REPLY" "FIFO pop 2"
_ziro_defer_core_queue_pop 5 a
_ziro_test_assert_eq "task3" "$REPLY" "FIFO pop 3"

# ─── Test 2: Empty pop returns 1 ───
_ziro_test_assert_status 1 "Empty pop returns 1" _ziro_defer_core_queue_pop 5 a

# ─── Test 3: Size across slots ───
_ziro_defer_core_queue_push 5 a s_a
_ziro_defer_core_queue_push 5 b s_b1
_ziro_defer_core_queue_push 5 b s_b2
_ziro_defer_core_queue_push 5 c s_c
_ziro_test_assert_eq "1" "$(_ziro_defer_core_queue_size 5 a)" "Size slot a = 1"
_ziro_test_assert_eq "2" "$(_ziro_defer_core_queue_size 5 b)" "Size slot b = 2"
_ziro_test_assert_eq "1" "$(_ziro_defer_core_queue_size 5 c)" "Size slot c = 1"
_ziro_test_assert_eq "4" "$(_ziro_defer_core_queue_size 5)"   "Total stage 5 = 4"

# ─── Test 4: Remove specific task ───
_ziro_defer_core_queue_remove 5 b s_b1
_ziro_test_assert_eq "1" "$(_ziro_defer_core_queue_size 5 b)" "After remove b size = 1"
_ziro_defer_core_queue_pop 5 b
_ziro_test_assert_eq "s_b2" "$REPLY" "Remaining task is s_b2"

# ─── Test 5: Independent stages ───
_ziro_defer_core_queue_push 0 a pre_task
_ziro_defer_core_queue_push 7 a od_task
_ziro_defer_core_queue_pop 0 a
_ziro_test_assert_eq "pre_task" "$REPLY" "Stage 0 independent"
_ziro_defer_core_queue_pop 7 a
_ziro_test_assert_eq "od_task"  "$REPLY" "Stage 7 independent"

# ─── Test 6: Clear ───
_ziro_defer_core_queue_clear 5
_ziro_test_assert_eq "0" "$(_ziro_defer_core_queue_size 5)" "Clear stage 5"

# ─── Test 7: FIFO across compaction (> 100 items) ───
local i
for i in {1..150}; do
  _ziro_defer_core_queue_push 6 d "bulk_$i"
done
_ziro_test_assert_eq "150" "$(_ziro_defer_core_queue_size 6 d)" "Bulk push 150"
# Pop 120 times to trigger compaction
for i in {1..120}; do
  _ziro_defer_core_queue_pop 6 d
done
_ziro_test_assert_eq "30" "$(_ziro_defer_core_queue_size 6 d)" "After 120 pops, size = 30"
_ziro_defer_core_queue_pop 6 d
_ziro_test_assert_eq "bulk_121" "$REPLY" "FIFO preserved after compaction"

# ─── Test 8: Task Registry & Cycle Detection ───
_ziro_defer_core_register reg_task_a 5 b "echo a"
_ziro_test_assert_eq "pending" "$(_ziro_defer_core_task_status reg_task_a)" "Status pending"
_ziro_test_assert_status 0 "Has reg_task_a" _ziro_defer_core_has_task reg_task_a

_ziro_defer_core_register reg_task_b 5 b "echo b" reg_task_a
_ziro_test_assert_status 0 "Has reg_task_b" _ziro_defer_core_has_task reg_task_b

_ziro_test_assert_status 1 "Self-cycle blocked" _ziro_defer_core_cycle_check reg_task_x reg_task_x

_ziro_defer_core_unregister reg_task_a
_ziro_test_assert_eq "" "$(_ziro_defer_core_task_status reg_task_a)" "Unregister clears status"

_ziro_test_summary
