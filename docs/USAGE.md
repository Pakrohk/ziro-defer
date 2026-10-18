# ziro-defer — Usage Guide

## Installation

**Standalone**:
```zsh
source /path/to/ziro-defer/ziro-defer.plugin.zsh
```

**Znap**:
```zsh
znap source Pakrohk/ziro-defer
```

**Zinit**:
```zsh
zinit light Pakrohk/ziro-defer
```

## The 8 Stages

| Stage | Trigger | Budget | Purpose |
|:---:|:---|:---:|:---|
| 0 | shell init start | < 0.1ms | XDG paths, module hoist |
| 1 | after stage 0 | < 0.5ms | znap + scheduler core |
| 2 | after stage 1 | < 1.0ms | fpath injection |
| 3 | after stage 2 | < 2.0ms | compinit -C |
| 4 | after stage 3 | < 1.0ms | prompt cache source |
| 5 | first precmd | unbounded | deferred loading (default) |
| 6 | shell idle > 5s | unbounded | background maintenance |
| 7 | on demand | < 30ms | lazy loading |

## The 4 Priority Slots

| Slot | Name | Typical Workload |
|:---:|:---|:---|
| `a` | Critical | Prompt, core ZLE bindings |
| `b` | Normal | Highlighters, autosuggestions |
| `c` | Lazy | Decorators, git info |
| `d` | Background | Telemetry, update checks |

## Common Patterns

### Defer a plugin load
```zsh
ziro-defer --stage=5 --slot=b --name=fsh 'znap source zdharma-continuum/fast-syntax-highlighting'
```

### Chain with dependency
```zsh
ziro-defer --stage=5 --slot=a --name=ghost 'znap source Pakrohk/ziro-ghost'
ziro-defer --stage=5 --slot=b --name=fsh --after=ghost 'znap source zdharma-continuum/fast-syntax-highlighting'
```

### Conditional execution
```zsh
# Only run if git is installed
ziro-defer --stage=6 --slot=d --if-cmd=git --name=check 'git fetch --quiet'

# Only run in SSH sessions
ziro-defer --stage=6 --slot=d --if-ssh --name=ssh-sync 'rsync -az ~/.config/ ~/backup/'
```

### Interactive timeout prompt
```zsh
# In ~/.config/ziro/defer.conf
[behavior]
interactive_timeout_prompt = true
```
On a slow cold-path task, you'll be prompted: `[s]kip · [c]ontinue · [q]uit stage`.

## Inspecting Metrics

```zsh
ziro-defer-stats
```

Sample output:
```
Stage Summary:
  Stage 0 (pre-source)    :   0ms  (0 tasks)
  Stage 5 (post-prompt)   :  34ms  (8 tasks)
  Stage 6 (idle)          : 120ms  (2 tasks)

Cache & Totals:
  Total records:      14
  Cache hits:         6
```

## Configuration

Edit `~/.config/ziro/defer.conf`. See Spec 005 §13 for the full schema.

## Dependency Chains (v2.0.0)

Two equivalent syntaxes:

```zsh
# Option 1: --after / --before (classic)
ziro-defer --name=A --after=X "cmd"           # A waits for X
ziro-defer --name=B --before=Y "cmd"          # Y waits for B

# Option 2: --depends (explicit, v2.0.0+)
ziro-defer --name=A --depends="X Y" "cmd"     # A waits for X and Y
```

### Multi-level chains

```zsh
ziro-defer --name=D --stage=5 "echo D"
ziro-defer --name=C --stage=5 --after=D "echo C"
ziro-defer --name=B --stage=5 --after=C "echo B"
ziro-defer --name=A --stage=5 --after=B "echo A"
# Runs in order: D → C → B → A
```

### How it works internally

Single graph: `_ziro_defer_task_depends[task_id]` holds space-separated prerequisite IDs. Fast path (single dep) does one status check; multi-dep uses native Zsh split (zero fork). Cycle detection walks the graph via DFS.

### Progress visibility

For stages 5-7, interactive shells see:

```
ziro-defer: running 'fsh'...
```

while the task executes. If the task hangs, this message stays visible; press Ctrl-C to abort. Configurable via `[behavior] show_progress_message = true`.
