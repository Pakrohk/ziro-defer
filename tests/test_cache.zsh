#!/usr/bin/env zsh
# tests/test_cache.zsh - Phase 3b cache controller tests.
# Zero forks: mapfile + native expansions, no subshell forks in assertions.

emulate -L zsh
set -u
zmodload zsh/mapfile 2>/dev/null

source "${0:A:h}/../core/version.zsh"
source "${0:A:h}/../lib/cache-io.zsh"
source "${0:A:h}/../cache/eval-cache.zsh"
source "${0:A:h}/../cache/zwc-cache.zsh"
source "${0:A:h}/../cache/analysis-cache.zsh"
source "${0:A:h}/../cache/tag-cache.zsh"
source "${0:A:h}/../cache/marker-cache.zsh"
source "${0:A:h}/../cache/ghost-cache.zsh"
source "${0:A:h}/_harness.zsh"

# Sandbox cache dir for tests
export XDG_CACHE_HOME="/tmp/ziro_test_cache_$$"
mkdir -p "$XDG_CACHE_HOME"
source "${0:A:h}/../lib/cache-io.zsh"

# Test 1: atomic write + read
local t1_file="${XDG_CACHE_HOME}/test1.txt"
_ziro_defer_lib_cache_write_atomic "$t1_file" "hello world"
_ziro_test_assert_eq "hello world" "${mapfile[$t1_file]%$'\n'}" "atomic write then read"

# Test 2: mtime helper
_ziro_defer_lib_cache_mtime "$t1_file"
local mtime="$REPLY"
local is_positive=0
(( mtime > 0 )) && is_positive=1
_ziro_test_assert_eq "1" "$is_positive" "mtime > 0"

# Test 3: age helper
_ziro_defer_lib_cache_age_seconds "$t1_file"
local is_recent=0
(( REPLY >= 0 && REPLY < 10 )) && is_recent=1
_ziro_test_assert_eq "1" "$is_recent" "age is small"

# Test 4: analysis cache write/read
_ziro_defer_cache_analysis_write "myplugin" '{"version":"1.0"}'
_ziro_defer_cache_analysis_valid "myplugin"
_ziro_test_assert_eq "0" "$?" "analysis cache valid right after write"
_ziro_defer_cache_analysis_read "myplugin"
_ziro_test_assert_eq "{\"version\":\"1.0\"}" "${REPLY%$'\n'}" "analysis cache read matches"

# Test 5: analysis cache TTL (simulate old file)
local t5_file
_ziro_defer_cache_analysis_path "myplugin"
t5_file="$REPLY"
touch -d "8 days ago" "$t5_file" 2>/dev/null || true
_ziro_defer_cache_analysis_valid "myplugin" "" 604800
_ziro_test_assert_eq "1" "$?" "old analysis cache invalid"

# Test 6: analysis invalidate
_ziro_defer_cache_analysis_write "myplugin" '{}'
_ziro_defer_cache_analysis_invalidate "myplugin"
local is_missing=0
[[ ! -r "$t5_file" ]] && is_missing=1
_ziro_test_assert_eq "1" "$is_missing" "analysis invalidated"

# Test 7: tag cache
_ziro_defer_cache_tag_set "@lazy" "/path/to/plugin"
_ziro_defer_cache_tag_get "@lazy"
_ziro_test_assert_eq "0" "$?" "tag get found"
_ziro_test_assert_eq "/path/to/plugin" "$REPLY" "tag value matches"

# Test 8: tag clear
_ziro_defer_cache_tag_clear
_ziro_defer_cache_tag_get "@lazy"
_ziro_test_assert_eq "1" "$?" "tag cleared"

# Test 9: marker cache write/read
_ziro_defer_cache_marker_write "/tmp/testdir" '{"lang":"zsh"}'
_ziro_defer_cache_marker_valid "/tmp/testdir"
_ziro_test_assert_eq "0" "$?" "marker valid"
_ziro_defer_cache_marker_read "/tmp/testdir"
_ziro_test_assert_eq '{"lang":"zsh"}' "${REPLY%$'\n'}" "marker read matches"

# Test 10: marker invalidate
_ziro_defer_cache_marker_invalidate "/tmp/testdir"
_ziro_defer_cache_marker_valid "/tmp/testdir"
_ziro_test_assert_eq "1" "$?" "marker invalidated"

# Test 11: ghost cache put/get
_ziro_defer_cache_ghost_put "git pu" "git push origin main"
_ziro_defer_cache_ghost_get "git pu"
_ziro_test_assert_eq "0" "$?" "ghost hit"
_ziro_test_assert_eq "git push origin main" "$REPLY" "ghost result matches"

# Test 12: ghost LRU eviction
_ziro_defer_ghost_lru_max=3
local i
# @O(n)-justified: test loop to fill LRU, unavoidable for testing eviction
for (( i = 1; i <= 5; i++ )); do
  _ziro_defer_cache_ghost_put "q$i" "r$i"
done
_ziro_defer_cache_ghost_get "q1"
_ziro_test_assert_eq "1" "$?" "oldest q1 evicted"
_ziro_defer_cache_ghost_get "q5"
_ziro_test_assert_eq "0" "$?" "newest q5 present"

# Test 13: ghost invalidate
_ziro_defer_cache_ghost_invalidate
_ziro_defer_cache_ghost_get "q5"
_ziro_test_assert_eq "1" "$?" "ghost invalidated"

# Cleanup
rm -rf "$XDG_CACHE_HOME" 2>/dev/null || true

_ziro_test_summary
