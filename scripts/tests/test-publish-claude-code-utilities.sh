#!/usr/bin/env bash
# test-publish-claude-code-utilities.sh
#
# Checks the copy that keeps the public skills repository current: that a
# committed skill and CLAUDE.md are published with a README and the licence;
# that an uncommitted edit, the service's own skills and the settings are not;
# that a removed skill is removed; that a dry run works before the public
# repository exists; that a run with nothing new makes no
# commit; that a dry run pushes nothing; that something shaped like a key
# stops the push; and that a missing public repository is never created
# without the owner's --create.
#
# Everything happens in a scratch folder in RAM: a pretend ~/.claude, and a
# local bare repository standing in for GitHub. Nothing is pushed anywhere.

DIR="${1:-/home/ritz/programming/ai-stuff/scripts}"
TOOL="$DIR/publish-claude-code-utilities"
ROOM="$(mktemp -d /dev/shm/test-publish-utilities.XXXXXX)"
trap 'rm -rf "$ROOM"' EXIT
SOURCE="$ROOM/source"
REMOTE="$ROOM/remote.git"
WORK="$ROOM/ram/work"

passed=0
failed=0

# {{{ check()
check() {
  local description="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    echo "FAIL: $description (expected '$expected', got '$actual')"
  fi
}
# }}}

# {{{ publish()
publish() {
  "$TOOL" --dir "$DIR" --source "$SOURCE" --remote "$REMOTE" --work "$WORK" "$@" > "$ROOM/out" 2>&1
}
# }}}

# {{{ public_file()
# What the stand-in GitHub holds at a path on main, or MISSING.
public_file() {
  git --git-dir="$REMOTE" show "main:$1" 2>/dev/null || echo MISSING
}
# }}}

# {{{ public_commits()
public_commits() {
  git --git-dir="$REMOTE" rev-list --count main 2>/dev/null || echo 0
}
# }}}

# {{{ commit_source()
commit_source() {
  git -C "$SOURCE" add -A
  git -C "$SOURCE" commit --quiet -m "$1"
}
# }}}

# The pretend ~/.claude: rules, one skill, a service skill, settings.
mkdir -p "$SOURCE/skills/alpha" "$SOURCE/skills/synced/svc"
git -C "$SOURCE" init --quiet
echo "rules" > "$SOURCE/CLAUDE.md"
echo "alpha one" > "$SOURCE/skills/alpha/SKILL.md"
echo "service" > "$SOURCE/skills/synced/svc/SKILL.md"
echo '{"hooks":{}}' > "$SOURCE/settings.json"
commit_source "start"

# No public repository, and no --create: refused, nothing made.
publish
check "a missing public repository is refused without --create" 1 $?
check "and nothing was created" "no" "$([ -e "$REMOTE" ] && echo yes || echo no)"

# A dry run before the public repository exists shows the first publish.
publish --dry-run
check "a dry run with no public repository succeeds" 0 $?
check "and lists the skill it would publish" "yes" "$(grep -q 'skills/alpha/SKILL.md' "$ROOM/out" && echo yes || echo no)"
check "and still creates nothing" "no" "$([ -e "$REMOTE" ] && echo yes || echo no)"

git init --quiet --bare "$REMOTE"

# The first publish.
publish
check "the first publish succeeds" 0 $?
check "CLAUDE.md is published" "rules" "$(public_file CLAUDE.md)"
check "a committed skill is published" "alpha one" "$(public_file skills/alpha/SKILL.md)"
check "the service's own skills are not" "MISSING" "$(public_file skills/synced/svc/SKILL.md)"
check "the settings are not" "MISSING" "$(public_file settings.json)"
check "a README is written" "yes" "$(public_file README.md | grep -q 'alpha' && echo yes || echo no)"
check "the licence is copied" "yes" "$(public_file LICENSE | grep -q 'AFFERO' && echo yes || echo no)"

# An edit not yet committed is not published, and makes no commit.
before=$(public_commits)
echo "alpha half-finished" > "$SOURCE/skills/alpha/SKILL.md"
publish
check "a run with only uncommitted edits succeeds" 0 $?
check "the uncommitted edit is not published" "alpha one" "$(public_file skills/alpha/SKILL.md)"
check "and no commit was made" "$before" "$(public_commits)"
git -C "$SOURCE" checkout --quiet -- skills/alpha/SKILL.md

# A dry run shows a change and pushes nothing.
mkdir -p "$SOURCE/skills/beta"
echo "beta" > "$SOURCE/skills/beta/SKILL.md"
commit_source "beta"
publish --dry-run
check "a dry run succeeds" 0 $?
check "and pushes nothing" "MISSING" "$(public_file skills/beta/SKILL.md)"

# A skill added and another removed: the copy follows both.
git -C "$SOURCE" rm --quiet -r skills/alpha
commit_source "alpha retired"
publish
check "the publish after a change succeeds" 0 $?
check "the new skill is published" "beta" "$(public_file skills/beta/SKILL.md)"
check "the removed skill is removed" "MISSING" "$(public_file skills/alpha/SKILL.md)"

# Nothing new: no commit.
before=$(public_commits)
publish
check "a run with nothing new succeeds" 0 $?
check "and makes no commit" "$before" "$(public_commits)"

# Something shaped like a key stops it.
mkdir -p "$SOURCE/skills/leaky"
echo "token sk-ant-abcdefghijklmnop" > "$SOURCE/skills/leaky/SKILL.md"
commit_source "leaky"
before=$(public_commits)
publish
check "a key-shaped string is refused" 1 $?
check "and names the file" "yes" "$(grep -q 'skills/leaky/SKILL.md' "$ROOM/out" && echo yes || echo no)"
check "and pushes nothing" "$before" "$(public_commits)"

echo "test-publish-claude-code-utilities: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
