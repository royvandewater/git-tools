#!/bin/bash
# Tests that git-delete-worktree absorbs a pending Ctrl-D (EOF) on failure,
# but leaves stdin untouched when it succeeds.

set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/git-delete-worktree"
failures=0

fail(){ echo "FAIL: $*" 1>&2; failures=$((failures + 1)); }
pass(){ echo "ok: $*"; }

# Runs "$@" with stdin held open by a pipe that never delivers data or EOF.
# Prints "<exit_code> <elapsed_seconds>".
run_with_open_stdin(){
  local dir="$1"; shift
  local fifo status start end
  fifo="$(mktemp -u)"
  mkfifo "$fifo"
  sleep 30 > "$fifo" &
  local holder=$!
  start=$SECONDS
  ( cd "$dir" && "$@" ) < "$fifo" >/dev/null 2>&1
  status=$?
  end=$SECONDS
  kill "$holder" 2>/dev/null
  wait "$holder" 2>/dev/null
  rm -f "$fifo"
  echo "$status $((end - start))"
}

main_repo="$(mktemp -d)"
git -C "$main_repo" init -q
git -C "$main_repo" commit -q --allow-empty -m init

# Case 1: failure path waits to absorb the EOF, then exits non-zero.
read -r status elapsed <<<"$(run_with_open_stdin "$main_repo" "$SCRIPT")"
[ "$status" -ne 0 ] || fail "failure path should exit non-zero, got $status"
[ "$elapsed" -ge 1 ] || fail "failure path should wait >=1s to absorb EOF, waited ${elapsed}s"
[ "$status" -ne 0 ] && [ "$elapsed" -ge 1 ] && pass "failure path absorbs EOF and exits non-zero"

# Case 2: success path returns immediately, leaving the EOF for the shell.
worktree="$main_repo-wt"
git -C "$main_repo" worktree add -q -b throwaway "$worktree"
read -r status elapsed <<<"$(run_with_open_stdin "$worktree" "$SCRIPT")"
[ "$status" -eq 0 ] || fail "success path should exit zero, got $status"
[ "$elapsed" -lt 1 ] || fail "success path should not wait, waited ${elapsed}s"
[ "$status" -eq 0 ] && [ "$elapsed" -lt 1 ] && pass "success path leaves stdin alone"

rm -rf "$main_repo" "$worktree"

if [ "$failures" -gt 0 ]; then
  echo "$failures test(s) failed" 1>&2
  exit 1
fi
echo "all tests passed"
