# 113 - Config File Self-Edit

## Status: awaiting-work

## Problem

The `config.txt` file requires the user to manually open it in an editor. A more ergonomic approach would be to make the config file executable so that running it directly opens it in the user's preferred editor.

## Current Behavior

```bash
# User must manually open config file
nvim config.txt
# Or find it and open it
$EDITOR /path/to/project/config.txt
```

## Intended Behavior

```bash
# Running the config file opens it in $EDITOR
./config

# Still works as config source (comments ignored by parser)
scripts/generate-config.sh  # Parses key=value lines, skips script header
```

## Suggested Implementation Steps

1. **Rename config.txt to config**
   ```bash
   mv config.txt config
   ```

2. **Add polyglot header** to config file:
   ```bash
   #!/bin/bash
   # config - Compile-time configuration for physics-sim
   # Run this file to edit: ./config
   # Parsed by scripts/generate-config.sh → src/000-config.h
   exec ${EDITOR:-${VISUAL:-vi}} "$0"
   exit
   # --- Configuration below ---

   # System capacities
   MAX_BALLS=1024
   ...
   ```

   The trick:
   - Bash executes the shebang, runs `exec $EDITOR "$0"` which opens the file itself
   - The config parser (generate-config.sh) skips lines starting with `#` and blank lines
   - `exit` ensures bash never reaches the config lines

3. **Make config executable**
   ```bash
   chmod +x config
   ```

4. **Update generate-config.sh** to read from `config` instead of `config.txt`:
   ```bash
   # Change line 15:
   CONFIG_FILE="${DIR}/config"
   ```

5. **Update .gitignore** if needed (config should be tracked)

## Environment Variable Fallback Chain

The `$EDITOR` variable is standard, but we should handle missing values:
```bash
exec ${EDITOR:-${VISUAL:-vi}} "$0"
```

- `$EDITOR` - User's preferred editor (most common)
- `$VISUAL` - Fallback for visual editors
- `vi` - Ultimate fallback (available on all Unix systems)

For the user's nvim setup, `$EDITOR` is typically set to `nvim`.

## Files to Modify

- `config.txt` → `config` (rename + add header + chmod +x)
- `scripts/generate-config.sh` - Update CONFIG_FILE path

## Testing

1. Run `./config` - should open in nvim (or $EDITOR)
2. Run `scripts/compile` - should still generate src/000-config.h correctly
3. Verify config values appear in compiled binary
