#!/usr/bin/env bash
# test-lua-menu.sh - Test the Lua TUI menu implementation
# Run this to verify the Lua menu works correctly.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Build test config as JSON
config='{
    "title": "Test Menu",
    "subtitle": "Lua TUI Demo",
    "sections": [
        {
            "id": "mode",
            "title": "Mode",
            "type": "single",
            "items": [
                {"id": "analyze", "label": "Analyze", "type": "checkbox", "value": "1", "description": "Analyze issues for splitting"},
                {"id": "review", "label": "Review", "type": "checkbox", "value": "0", "description": "Review existing sub-issues"},
                {"id": "execute", "label": "Execute", "type": "checkbox", "value": "0", "description": "Create sub-issue files"},
                {"id": "implement", "label": "Implement", "type": "checkbox", "value": "0", "description": "Auto-implement via Claude"}
            ]
        },
        {
            "id": "options",
            "title": "Options",
            "type": "multi",
            "items": [
                {"id": "skip", "label": "Skip Existing", "type": "checkbox", "value": "0", "description": "Skip already-analyzed issues"},
                {"id": "dry", "label": "Dry Run", "type": "checkbox", "value": "0", "description": "Show what would be processed"},
                {"id": "archive", "label": "Archive", "type": "checkbox", "value": "0", "description": "Save analysis copies"}
            ]
        },
        {
            "id": "streaming",
            "title": "Streaming",
            "type": "multi",
            "items": [
                {"id": "parallel", "label": "Parallel", "type": "flag", "value": "3", "config": "3", "description": "Number of parallel workers"},
                {"id": "delay", "label": "Delay", "type": "flag", "value": "5", "config": "3", "description": "Delay between outputs"}
            ]
        }
    ]
}'

# Run the menu
result=$(echo "$config" | luajit "${DIR}/menu-runner.lua")
exit_code=$?

if [[ $exit_code -ne 0 ]]; then
    echo "Menu exited with error code: $exit_code"
    exit $exit_code
fi

echo "Result: $result"

# Parse the action from result
action=$(echo "$result" | sed -n 's/.*"action":"\([^"]*\)".*/\1/p')
echo "Action: $action"
