# ziro-defer — Design DNA & Inspiration

> **Provenance Record** — This document is permanent. Do not remove or
> modify without explicit architectural decision.

## Primary Inspiration: EVOID

**Repository**: https://github.com/EvolveBeyond/EVOID  
**Project**: Reference Runtime for Intent-Oriented Programming (IOP)

`ziro-defer` is a **runtime scheduler**, not a framework. This design
choice is directly inspired by EVOID's *"Runtime, not Framework"*
principle.

### Direct Derivatives

| EVOID Concept | ziro-defer Equivalent | Reference |
|:---|:---|:---|
| Intent Levels (3) | Priority Slots (4: a/b/c/d) | Spec 005 §6 R13 |
| Pipeline Processors | Strategy conditions + fallback chain | Spec 005 §7, §10 |
| Runtime not framework | `ziro-defer` composes tasks | Spec 005 §1.2 |
| Declarative TOML | `defer.conf` | Spec 005 §13 |
| Plugin manifest | `ziro-plugin.toml` | Spec 012 |

### Immutable Principles

1. **Declarative scheduling** — `--stage`, `--slot`, `--if-*` declare intent; scheduler decides execution.
2. **Levels over flags** — four semantic slots beat a dozen boolean flags.
3. **Pipeline over conditional** — condition evaluation → dependency check → execution → fallback.

## References

- EVOID repository: https://github.com/EvolveBeyond/EVOID

---

**Recorded**: 2026-10-18  
**Status**: Permanent — do not remove.
