#!/bin/bash
# Tests that git-update fast-forwards local main from origin and merges it into
# the current branch.

set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/git-update"
failures=0

fail(){ echo "FAIL: $*" 1>&2; failures=$((failures + 1)); }
pass(){ echo "ok: $*"; }

tmp="$(mktemp -d)"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

git init -q --bare -b main "$tmp/origin.git"
git clone -q "$tmp/origin.git" "$tmp/seed" 2>/dev/null
git -C "$tmp/seed" switch -q -c main
git -C "$tmp/seed" commit -q --allow-empty -m init
git -C "$tmp/seed" push -q origin main

git clone -q "$tmp/origin.git" "$tmp/work"
git -C "$tmp/work" switch -q -c feature
git -C "$tmp/work" commit -q --allow-empty -m feature-work
git -C "$tmp/work" push -q -u origin feature 2>/dev/null

git -C "$tmp/seed" commit -q --allow-empty -m upstream-change
git -C "$tmp/seed" push -q origin main

(cd "$tmp/work" && "$SCRIPT" >/dev/null 2>&1)
status=$?

[ "$status" -eq 0 ] || fail "should exit zero, got $status"

upstream="$(git -C "$tmp/seed" rev-parse HEAD)"
[ "$(git -C "$tmp/work" rev-parse main)" = "$upstream" ] \
  && pass "local main fast-forwarded" \
  || fail "local main should equal origin/main"

git -C "$tmp/work" merge-base --is-ancestor "$upstream" feature \
  && pass "main merged into current branch" \
  || fail "current branch should contain origin/main"

rm -rf "$tmp"

if [ "$failures" -gt 0 ]; then
  echo "$failures test(s) failed" 1>&2
  exit 1
fi
echo "all tests passed"
