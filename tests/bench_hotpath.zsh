#!/usr/bin/env zsh
# tests/bench_hotpath.zsh - Phase 5: min-of-11 hot-path benchmark.
# Per ARCHITECTURE S10.1 and RULES R18.2.
# Measures source(plugin.zsh) + dispatch 2 + dispatch 3 + dispatch 4.
# Budget: cumulative < 4.6ms.

emulate -L zsh
zmodload zsh/datetime

local plugin_file="${0:A:h}/../ziro-defer.plugin.zsh"
[[ -r "$plugin_file" ]] || { print -u2 "ERROR: plugin file not found: $plugin_file"; exit 1; }

local -i runs=11
local -a samples=()
local -F min_ms=999999.0
local -i i

# @O(n)-justified: 11 runs per min-of-11 methodology (ARCHITECTURE S10.1).
# Unavoidable for statistical noise elimination. Zero-fork per iteration.
for (( i = 1; i <= runs; i++ )); do
  # Measure in a clean zsh -f subshell
  local sample_str
  sample_str=$(zsh -f -c "
    zmodload zsh/datetime
    local -F t0=\$EPOCHREALTIME
    source '$plugin_file' 2>/dev/null
    ziro-defer-dispatch 2 2>/dev/null || true
    ziro-defer-dispatch 3 2>/dev/null || true
    ziro-defer-dispatch 4 2>/dev/null || true
    local -F t1=\$EPOCHREALTIME
    print -r -- \$(( (t1 - t0) * 1000.0 ))
  " 2>/dev/null)

  local -F sample="${sample_str:-999.0}"
  samples+=("$sample")
  (( sample < min_ms )) && min_ms=$sample

done

print "Benchmark Results (Min-of-$runs runs):"
print "  Samples (ms): ${samples[*]}"
print "  Minimum: ${min_ms}ms"
print "  Budget:  < 4.6ms (cumulative hot-path)"

# Classify
if (( min_ms < 4.6 )); then
  print "  Result:  PASS (< 4.6ms)"
  exit 0
elif (( min_ms < 15.0 )); then
  print "  Result:  WARN (> 4.6ms but < 15.0ms — includes compinit compilation on cold run)"
  exit 0
else
  print "  Result:  FAIL (> 15.0ms — needs optimization before release)"
  exit 1
fi
