# Changelog

All notable changes to `ziro-defer` are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

## [2.0.0] — 2026-10-18

### Added

- **8 execution stages** (0-7) with deterministic ascending ordering
- **4 priority slots** (`a` critical, `b` normal, `c` lazy, `d` background)
- **6 cache types**: `eval_output`, `compiled_zwc`, `analysis_json`, `tag_resolution`, `project_markers`, `ghost_candidates`
- **Dependency graph** with `--after` / `--before` and Tarjan-style cycle detection
- **Conditional execution**: `--if-var`, `--if-cmd`, `--if-ssh`, `--if-not-root`, `--if-dir`
- **Public API**: `ziro-defer`, `ziro-defer-batch`, `ziro-defer-dispatch`, `ziro-defer-bind-widget`, `ziro-defer-reorder`, `ziro-defer-stats`
- **`--on-key=<key>`** flag for ZLE key binding
- **JSONL telemetry** (`metrics.jsonl`) with automatic rotation at 1024 KB
- **Single precmd hook** dispatcher (O(1) vs O(N) per-task hooks)
- **Atomic cache writes** via `zsh/files` builtin (zero-fork `mv`)
- **Design DNA** documentation (EVOID inspiration record)
- **Chain-based `depends` graph**: `--after` and `--before` map to a unified internal `_ziro_defer_task_depends[task_id]` string. Fast path for single-dep (no loop); multi-dep uses native `${(s: :)}` split (zero fork).
- **New `--depends=` flag**: explicit alias for `--after`, clearer for chain declarations (`A --depends="X Y"`).
- **Progress visibility via `zle -M`**: stages 5-7 in interactive shells show `ziro-defer: running '<name>'...` while the task executes. User can Ctrl-C to abort a hang. No fork, no prompt.

### Changed

- **BREAKING (internal)**: Task registry now uses flat associative arrays instead of sorted lists
- **BREAKING (internal)**: `ziro-defer <cmd>` defaults to Stage 5 Slot b (matches legacy post-prompt defer)
- Queue pop returns via `$REPLY` (not `$()`) to eliminate subshells
- Stage budgets: cumulative hot path ceiling tightened from flexible to **< 4.6ms**
- **Dependency internals**: `_ziro_defer_task_after` and `_ziro_defer_task_before` remain for backward-compat tests, but `_ziro_defer_task_depends` is the authoritative graph.
- **Timeout is now visibility-oriented**: `zle -M` progress instead of nothing. Post-hoc measurement only; kill deferred to v2.1.0.

### Fixed

- Reserved Zsh variable collision: `local status=` → `local task_status=` (2 sites)
- Subshell memory sync removed from `core/queue.zsh` (208 → 176 lines, zero I/O)

### Security

- Zero network access on hot path (RULES R17.2)
- Cache directories created with mode 0700 (RULES R17.3)
- No arbitrary `eval` on untrusted input (RULES R17.1)

## [0.1.5] — Historical

Legacy two-stage deferral model. Archived at `.specify/specs/_deprecated/005-znap-optimization-v1/`.

## Known Limitations (v2.0.0)

- **`prompt_cache_mode = "full"` not implemented**: Only `fast` mode works.
  Full mode requires the analyzer (Spec 001, v2.1.0) to safely determine per-plugin
  cold-path prompt evaluation. The config key is accepted but is a no-op.
- **Hot-path benchmark ~10.36ms (> 4.6ms budget)**: Measured on uncompiled sources.
  `.zwc` compilation + analyzer-driven config optimization will bring this under
  budget in v2.1.0. v2.0.0 accepts ~10ms as functional but over-budget.
- **Metrics rotation only in Stage 6 (idle)**: If shell never idles, `metrics.jsonl`
  can grow past 1MB. Rotation occurs on first idle cycle (> 5s). Acceptable for v2.0.0.
- **Analyzer integration deferred to v2.1.0**: v2.0.0 ships the runtime + config
  infrastructure. Per-plugin analysis (the 9 responsibilities: timing, hot/cold,
  blocking, caching, compile safety) will populate `defer.conf` in v2.1.0.

### v2.1.0 Roadmap

- **User-in-loop timeout with kill**: stages 5-7 execute tasks in background, poll for completion, on timeout prompt `[k]ill / [w]ait / [s]kip`. Kill requires explicit user approval (`kill -TERM $pid`). Golden rule: nothing so important that shell hangs.
- **Analyzer integration** (Spec 001): analyzer populates `defer.conf` with 9 responsibilities (timing, hot/cold, blocking, compile safety, cache strategy, sub-section splitting, before/after chains, blocked-by detection).
- **`prompt_cache_mode = "full"`**: cold-path prompt evaluation on first run. Currently no-op.
- **`.zwc` compilation**: bytecode optimization for hot-path files. Expected to bring benchmark from ~10ms under 4.6ms.
- **Metrics rotation in emit_metric**: currently only at Stage 6 idle.
