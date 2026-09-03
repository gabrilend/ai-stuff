#!/bin/sh
#
# 008-run-tests.sh
#
# Runs every test this project has and reports whether the whole set
# passed.  Meant to be run before anything is trusted -- by a person
# after a change, and by the build.  It picks whichever Lua is present,
# preferring LuaJIT, because that is what the project is written against.
#
# Runs from any directory.  Pass a project path as the first argument to
# test a copy somewhere else.

DIR="/home/ritz/programming/ai-stuff/ssh-view-only-viewer-script"
if [ -n "$1" ]; then
    DIR="$1"
fi

if [ ! -d "$DIR/src" ]; then
    echo "no src directory at $DIR -- wrong path?" >&2
    exit 1
fi

# The RAM tier the tests build their sandbox in.  Created here rather
# than by the tests, so a missing symlink is one clear error at the top
# instead of a confusing failure partway through a test run.
mkdir -p "$DIR/tmp/shared-memory"

LUA=""
if command -v luajit > /dev/null 2>&1; then
    LUA="luajit"
elif command -v lua > /dev/null 2>&1; then
    LUA="lua"
    echo "note: luajit not found, using lua -- the project targets LuaJIT"
else
    echo "no lua interpreter found" >&2
    exit 1
fi

echo "running the draw's tests with $LUA"

"$LUA" "$DIR/src/007-test-the-draw.lua" "$DIR"
RESULT=$?

if [ $RESULT -eq 0 ]; then
    echo "all tests passed"
else
    echo "tests failed" >&2
fi

exit $RESULT
