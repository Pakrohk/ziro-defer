# ziro-defer v2.0.0

Multi-stage runtime task scheduler for Zsh.

> Inspired by [EVOID](https://github.com/EvolveBeyond/EVOID) — see [docs/PROJECT-DNA.md](docs/PROJECT-DNA.md).

## What it is

`ziro-defer` schedules shell tasks across **8 deterministic stages** with **4 priority slots**, **6 cache types**, dependency graphs, conditional execution, and JSONL telemetry — all with **zero fork on the hot path**.

## Highlights

- **8 Execution Stages**: 5 hot-path (0-4, cumulative < 4.6ms) + 3 cold-path (5-7)
- **4 Priority Slots**: `a` (critical) > `b` (normal) > `c` (lazy) > `d` (background)
- **6 Cache Types**: eval_output, compiled_zwc, analysis_json, tag_resolution, project_markers, ghost_candidates
- **Dependency Graph**: `--after`, `--before` with Tarjan cycle detection
- **Conditional Execution**: `--if-var`, `--if-cmd`, `--if-ssh`, `--if-not-root`, `--if-dir`
- **Observability**: JSONL metrics + `ziro-defer-stats`
- **Upstream Compatible**: `zsh-defer <cmd>` alias preserved

## Quick start

```zsh
# Standalone
source /path/to/ziro-defer/ziro-defer.plugin.zsh

# Via znap
znap source Pakrohk/ziro-defer

# Schedule a task (default: stage=5, slot=b)
ziro-defer 'source ~/.my-plugin.zsh'

# Schedule with explicit stage/slot
ziro-defer --stage=5 --slot=a --name=ghost 'znap source Pakrohk/ziro-ghost'

# Chain with dependency
ziro-defer --stage=5 --slot=b --name=fsh --after=ghost 'znap source zdharma/fsh'

# Conditional
ziro-defer --stage=6 --slot=d --if-cmd=git --name=check 'git fetch --quiet'
```

## API Surface

- `ziro-defer [OPTIONS] <cmd>` — primary scheduler
- `ziro-defer-batch [OPTIONS] <plugins...>` — batch registration
- `ziro-defer-dispatch [--force] <0-7>` — synchronous stage dispatcher
- `ziro-defer-bind-widget <key> <cmd>` — ZLE key one-shot binding
- `ziro-defer-reorder --task=<id> --slot=<a|b|c|d>` — dynamic priority change
- `ziro-defer-stats [pattern]` — aggregate metrics report

## Documentation

- [docs/USAGE.md](docs/USAGE.md) — full usage guide
- [docs/INTEGRATION.md](docs/INTEGRATION.md) — ziro-shell + Ghost v2 integration
- [docs/PROJECT-DNA.md](docs/PROJECT-DNA.md) — design provenance (EVOID)
- [docs/man/ziro-defer.1](docs/man/ziro-defer.1) — man page

## Requirements

- Zsh ≥ 5.8
- Standard modules: `zsh/datetime`, `zsh/stat`, `zsh/mapfile`, `zsh/parameter`, `zsh/files`
- No external binaries required on hot path

## License

MIT — see [LICENSE](LICENSE).
