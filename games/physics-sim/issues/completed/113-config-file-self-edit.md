# 113 - Config File Self-Edit and Validation

## Status: completed

## Depends on

- 112 ✓ (Compile-time config system)

## Problem

Two issues with the current config system:

1. The `config.txt` file requires the user to manually open it in an editor. A more ergonomic approach would be to make the config file executable so that running it directly opens it in the user's preferred editor.

2. If `config.txt` is missing, the compile script errors out instead of generating a default. There's also no validation that required keys exist or have valid values.

## Implementation Summary

### Part 1: Self-Edit Executable

- Renamed `config.txt` to `config`
- Added polyglot bash header that opens itself in $EDITOR:
  ```bash
  #!/bin/bash
  exec ${EDITOR:-${VISUAL:-vi}} "$0"
  exit
  ```
- Made config executable with `chmod +x`

### Part 2: Auto-Generation and Validation

Updated `scripts/generate-config.sh` with:

1. **Required keys registry** - Centralized list of all required config keys with defaults
2. **Auto-generation** - Creates config with defaults if missing
3. **Missing key detection** - Non-destructively appends missing keys to existing config
4. **Value validation** - Validates all values are non-negative integers

### Usage

```bash
# Edit config in your preferred editor
./config

# Compile (auto-generates config if missing)
scripts/compile

# Config missing → auto-creates with defaults → compiles
# Config exists but missing keys → appends missing keys → compiles
# Config has invalid values → error with clear message
```

## Files Modified

- `config.txt` → `config` (renamed, added polyglot header, made executable)
- `scripts/generate-config.sh` - Updated CONFIG_FILE path, added validation functions

## Files Removed

- `config.txt` (superseded by `config`)

## Testing Performed

1. `./config` opens in $EDITOR
2. `scripts/compile` generates src/000-config.h correctly
3. Deleting config and running compile auto-generates with defaults
4. Missing keys get auto-appended with defaults
5. Compilation succeeds with new config system
