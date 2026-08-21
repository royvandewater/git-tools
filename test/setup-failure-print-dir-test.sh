#!/bin/bash
# Tests that git-new-worktree prints the worktree path on stdout even when
# setup.sh exits non-zero, and still exits non-zero itself.

set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/git-new-worktree"
failures=0

fail(){ echo "FAIL: $*" 1>&2; failures=$((failures + 1)); }
pass(){ echo "ok: $*"; }

fake_home="$(mktemp -d)"
project="proj"
repo="$fake_home/Projects/royvandewater/$project"
mkdir -p "$repo"
git -C "$repo" init -q
git -C "$repo" commit -q --allow-empty -m init

setup_dir="$fake_home/Projects/royvandewater/worktrees/$project"
mkdir -p "$setup_dir"
printf '#!/bin/bash\nexit 3\n' > "$setup_dir/setup.sh"
chmod +x "$setup_dir/setup.sh"

expected="$fake_home/Projects/royvandewater/worktrees/$project/app/feature"
stdout="$(HOME="$fake_home" "$SCRIPT" "$project" app/feature 2>/dev/null)"
status=$?

[ "$status" -ne 0 ] || fail "should exit non-zero when setup.sh fails, got $status"
case "$stdout" in
  *"$expected"*) pass "prints worktree path despite setup.sh failure" ;;
  *) fail "stdout should contain $expected, got: $stdout" ;;
esac

rm -rf "$fake_home"

if [ "$failures" -gt 0 ]; then
  echo "$failures test(s) failed" 1>&2
  exit 1
fi
echo "all tests passed"
