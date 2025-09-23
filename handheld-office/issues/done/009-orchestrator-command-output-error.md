# Issue #009: Orchestrator Command Output Formatting Error

## Description

The orchestrator script has a formatting error in the help output for the start-handheld command.

## Issue Details

**In scripts/orchestrator.lua:**
```lua
print("  lua scripts/orchestrator.lua start-handheld- Start handheld client")
```

**Problem:** Missing space between "start-handheld" and the description

**Should be:**
```lua
print("  lua scripts/orchestrator.lua start-handheld - Start handheld client")
```

## Impact

- Help output looks unprofessional: "start-handheld- Start handheld client"
- Inconsistent with other command formatting
- Makes CLI interface appear buggy

## Documentation Reference

**In README.md lines 64-65:**
```bash
# Start handheld client
lua scripts/orchestrator.lua start-handheld
```

The command itself works correctly, but the help text is malformed.

## Suggested Fix

Add space before the hyphen in the help output:
```lua
print("  lua scripts/orchestrator.lua start-handheld - Start handheld client")
```

## Line Numbers

- scripts/orchestrator.lua: Help output formatting (exact line number needs verification)

## Priority

Low - Cosmetic issue but affects user experience when using --help or similar commands