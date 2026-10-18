# ziro-defer.plugin.zsh - Main entry point (Stage 1 Bootstrap).
# Per ARCHITECTURE S3.3 and RULES R10.2.
# Idempotent, < 100 lines, zero forks during load.
# Sourced by integration.zsh AFTER znap.zsh at Stage 1.

# Idempotency guard (RULES R4.6)
[[ -n "${_ZIRO_DEFER_LOADED:-}" ]] && return 0

# Resolve root from current file path
emulate -L zsh
typeset -g _ZIRO_DEFER_ROOT="${${(%):-%x}:A:h}"

# ─── Stage 0: Environment setup (inline, before any other source) ───
source "${_ZIRO_DEFER_ROOT}/stages/stage-0-pre-source.zsh"
_ziro_defer_stage_0_builtin

# ─── Libraries (dependency order: leaf utilities first) ───
source "${_ZIRO_DEFER_ROOT}/lib/timer.zsh"
source "${_ZIRO_DEFER_ROOT}/lib/json-writer.zsh"
source "${_ZIRO_DEFER_ROOT}/lib/cycle-detect.zsh"
source "${_ZIRO_DEFER_ROOT}/lib/condition-eval.zsh"
source "${_ZIRO_DEFER_ROOT}/lib/toml-parser.zsh"
source "${_ZIRO_DEFER_ROOT}/lib/cache-io.zsh"

# ─── Core (scheduler depends on queue + task-registry) ───
source "${_ZIRO_DEFER_ROOT}/core/version.zsh"
source "${_ZIRO_DEFER_ROOT}/core/queue.zsh"
source "${_ZIRO_DEFER_ROOT}/core/task-registry.zsh"
source "${_ZIRO_DEFER_ROOT}/core/scheduler.zsh"
source "${_ZIRO_DEFER_ROOT}/core/hooks.zsh"

# ─── Cache controllers (all 6) ───
source "${_ZIRO_DEFER_ROOT}/cache/eval-cache.zsh"
source "${_ZIRO_DEFER_ROOT}/cache/zwc-cache.zsh"
source "${_ZIRO_DEFER_ROOT}/cache/analysis-cache.zsh"
source "${_ZIRO_DEFER_ROOT}/cache/tag-cache.zsh"
source "${_ZIRO_DEFER_ROOT}/cache/marker-cache.zsh"
source "${_ZIRO_DEFER_ROOT}/cache/ghost-cache.zsh"

# ─── Public API (all 6) ───
source "${_ZIRO_DEFER_ROOT}/api/ziro-defer.zsh"
source "${_ZIRO_DEFER_ROOT}/api/ziro-defer-batch.zsh"
source "${_ZIRO_DEFER_ROOT}/api/ziro-defer-dispatch.zsh"
source "${_ZIRO_DEFER_ROOT}/api/ziro-defer-bind-widget.zsh"
source "${_ZIRO_DEFER_ROOT}/api/ziro-defer-stats.zsh"
source "${_ZIRO_DEFER_ROOT}/api/ziro-defer-reorder.zsh"

# ─── Defaults (uses toml-parser if user defer.conf exists) ───
source "${_ZIRO_DEFER_ROOT}/config/defaults.zsh"

# ─── Stage modules 1-7 (define their _builtin functions) ───
source "${_ZIRO_DEFER_ROOT}/stages/stage-1-bootstrap.zsh"
source "${_ZIRO_DEFER_ROOT}/stages/stage-2-pre-compinit.zsh"
source "${_ZIRO_DEFER_ROOT}/stages/stage-3-compinit.zsh"
source "${_ZIRO_DEFER_ROOT}/stages/stage-4-post-compinit.zsh"
source "${_ZIRO_DEFER_ROOT}/stages/stage-5-post-prompt.zsh"
source "${_ZIRO_DEFER_ROOT}/stages/stage-6-idle.zsh"
source "${_ZIRO_DEFER_ROOT}/stages/stage-7-on-demand.zsh"

# ─── Stage 1 action: verify znap (sourced by integration.zsh before us) ───
_ziro_defer_stage_1_builtin

# ─── Register Stage 2/3/4 builtins as slot=a tasks ───
# These will run when integration.zsh calls `ziro-defer-dispatch N`.
ziro-defer --stage=2 --slot=a --name=_builtin_stage_2 _ziro_defer_stage_2_builtin
ziro-defer --stage=3 --slot=a --name=_builtin_stage_3 _ziro_defer_stage_3_builtin
ziro-defer --stage=4 --slot=a --name=_builtin_stage_4 _ziro_defer_stage_4_builtin

# ─── Install the single unified precmd hook (RULES R4.5) ───
_ziro_defer_core_hooks_install

# Mark as loaded
typeset -g _ZIRO_DEFER_LOADED=1
return 0
