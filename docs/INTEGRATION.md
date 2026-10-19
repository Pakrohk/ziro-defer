# ziro-defer — Integration Guide

## Integrating with ziro-shell v1.3.0

In `integration.zsh`, replace the legacy multi-branch bootstrap with a unified Stage 1 call:

```zsh
# Stage 0: Pre-source (inline)
zmodload -F zsh/datetime b:EPOCHREALTIME
typeset -gF _ziro_boot_t0=$EPOCHREALTIME
typeset -g ZIRO_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/ziro"
typeset -g ZIRO_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/ziro"
typeset -g ZIRO_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/ziro"

# Stage 1: Bootstrap
source "$ZIRO_DATA/vendor/znap/znap.zsh"
source "$ZIRO_HOME/ziro-defer/ziro-defer.plugin.zsh"

# Stages 2-4: Declarative, then dispatch synchronously
ziro-defer --stage=2 --slot=a znap source zsh-users/zsh-completions
ziro-defer --stage=4 --slot=a znap eval starship 'starship init zsh --print-full-init'

ziro-defer-dispatch 2
ziro-defer-dispatch 3
ziro-defer-dispatch 4

# Prompt rendered — user sees interactive shell
ziro-defer --stage=5 --slot=a --name=ghost znap source Pakrohk/ziro-ghost
ziro-defer --stage=5 --slot=b --name=fsh --after=ghost 'znap source zdharma-continuum/fast-syntax-highlighting'
ziro-defer --stage=6 --slot=d --name=update _ziro_update_check_background
```

## Integrating with ziro-ghost v2.0.0

Ghost v2 has 4 subsystems that map to Defer stages:

| Ghost Subsystem | Defer Stage | Slot | Budget |
|:---|:---:|:---:|:---:|
| Stage 0 Core (ZLE stubs) | 1 (direct source) | — | < 0.5ms |
| Stage 1 ZLE Hook (post-prompt) | 5 | a | < 2ms |
| Stage 2 Aux Sources | 6 | c | background |
| Stage 3 Rust Focus | — (external widget) | — | < 30ms |

**Note**: Ghost Stage 3 is **NOT** a Defer task — it's Ghost's own Tab widget, spawned on demand. Defer does not manage it.

## Standalone (no ziro-shell)

```zsh
source ~/path/to/ziro-defer/ziro-defer.plugin.zsh
source ~/path/to/ziro-ghost/ghost.plugin.zsh  # sourced via Defer's default hooks
```

Works identically. No `~/.ziro/` required.

## Chain Dependencies in ziro-shell

When generating `plugins.gen.zsh` from the analyzer, express dependencies as a chain:

```zsh
# Analyzer output (example)
ziro-defer --stage=5 --slot=a --name=ghost  'znap source Pakrohk/ziro-ghost'
ziro-defer --stage=5 --slot=b --name=zcolors 'znap eval zcolors "zcolors ${(q)LS_COLORS}"'
ziro-defer --stage=5 --slot=b --name=fsh --depends='ghost zcolors' 'znap source zdharma-continuum/fast-syntax-highlighting'
```

`fsh` will not run until both `ghost` and `zcolors` reach terminal state.

### Ghost v2 mapping (v2.0.0)

| Ghost subsystem | Defer stage | Slot | Notes |
|:---|:---:|:---:|:---|
| Stage 0 Core | 1 (direct source) | — | Not a Defer task |
| Stage 1 ZLE Hook | 5 | a | `--after` ghost itself |
| Stage 2 Aux Sources | 6 | c | background |
| Stage 3 Rust Focus | — (external widget) | — | Ghost's own Tab |
