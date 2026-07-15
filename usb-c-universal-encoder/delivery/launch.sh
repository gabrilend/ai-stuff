#!/usr/bin/env bash
#
# launch.sh — the entry point of the delivered system.
#
# In one sentence: this is what "it just works" means — run it and the software
# that came off the cable does its thing. Following the house style, the first
# thing it does is read the input/ folder for any startup wishes, and the last
# thing it does is write a goodbye to output/.
#
# Usage:  launch.sh [command]
#   smoke              run a quick self-test that proves the delivered code runs (default)
#   mount|send|receive reserved for later builds
#
# Override the bundle root by exporting DIR=/path before running.

set -euo pipefail

# ${DIR} is the bundle root — where this launcher and its payload live. Self-located
# by default so the launcher works from any install location or straight off a mount.
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR="${DIR:-$SELF}"

COMMAND="${1:-smoke}"

# Ensure writable scratch and result areas exist wherever we happen to be running
# from (a freshly copied install has neither yet).
mkdir -p "$DIR/output"
mkdir -p "$DIR/tmp"

# House style: the first thing a program does is read its input/ folder. Today we
# only announce what is there; future commands will honor it as startup config.
if [ -d "$DIR/input" ]; then
    for wish in "$DIR/input"/*; do
        [ -e "$wish" ] && echo "[launch] input: $(basename "$wish")"
    done
fi

# Dispatch. The default proves the delivery actually delivered working software by
# running the ground-floor self-test out of the bundle itself.
case "$COMMAND" in
    smoke)
        echo "[launch] running smoke test from $DIR"
        LUA_PATH="$DIR/?.lua;$DIR/?/init.lua;;" luajit "$DIR/tests/00-ram-arena-test.lua"
        ;;
    mount|send|receive)
        echo "[launch] '$COMMAND' is not available in this build yet."
        ;;
    *)
        echo "usage: launch.sh [smoke|mount|send|receive]" >&2
        exit 2
        ;;
esac

# House style: the last thing a program does is write a goodbye to output/.
echo "goodbye — $(date -u +%Y-%m-%dT%H:%M:%SZ) — ran '$COMMAND'" >> "$DIR/output/goodbye"
