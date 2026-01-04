#!/bin/bash
# History Viewer - Wrapper script
# Invokes the Lua-based history viewer for browsing commit history as a narrative.

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec luajit "${SCRIPT_DIR}/history-viewer.lua" "$@"
