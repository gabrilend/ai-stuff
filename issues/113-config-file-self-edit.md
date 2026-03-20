# 113 - Config File Self-Edit and Validation

## Status: awaiting-work

## Depends on

- 112 ✓ (Compile-time config system)

## Problem

Two issues with the current config system:

1. The `config.txt` file requires the user to manually open it in an editor. A more ergonomic approach would be to make the config file executable so that running it directly opens it in the user's preferred editor.

2. If `config.txt` is missing, the compile script errors out instead of generating a default. There's also no validation that required keys exist or have valid values.

## Current Behavior

```bash
# User must manually open config file
nvim config.txt

# If config.txt is missing, generate-config.sh fails:
# ERROR: Config file not found: /path/to/config.txt

# No validation of required keys - if MAX_BALLS is missing, compilation fails
# with cryptic "undeclared identifier" errors
```

## Intended Behavior

```bash
# Running the config file opens it in $EDITOR
./config

# If config is missing, auto-generate with defaults
scripts/compile  # Creates config with defaults, then compiles

# If config exists but missing keys, append missing keys with defaults
# User's existing values are preserved (non-destructive)

# Invalid values (non-integer, out of range) produce clear errors
```

## Suggested Implementation Steps

### Part 1: Self-Edit Executable

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
   CONFIG_FILE="${DIR}/config"
   ```

### Part 2: Auto-Generation and Validation

5. **Define required keys with defaults** in generate-config.sh:
   ```bash
   # Required keys and their default values
   declare -A REQUIRED_KEYS=(
       ["MAX_BALLS"]="1024"
       ["MAX_PARTICLES"]="1024"
       ["MAX_SPAWN_CREDITS"]="30"
       ["TRAJECTORY_HISTORY_FRAMES"]="4"
       ["EDITOR_ADVANCED_MODE"]="0"
       ["BACKGROUND_COLOR"]="0"
   )
   ```

6. **Generate default config if missing**:
   ```bash
   if [ ! -f "$CONFIG_FILE" ]; then
       echo "Config file not found, generating default: $CONFIG_FILE"
       generate_default_config
   fi
   ```

7. **Validate and append missing keys** (non-destructive):
   ```bash
   # Check each required key exists in config
   for key in "${!REQUIRED_KEYS[@]}"; do
       if ! grep -q "^${key}=" "$CONFIG_FILE"; then
           echo "# Auto-added missing key" >> "$CONFIG_FILE"
           echo "${key}=${REQUIRED_KEYS[$key]}" >> "$CONFIG_FILE"
           echo "Added missing key: ${key}=${REQUIRED_KEYS[$key]}"
       fi
   done
   ```

8. **Validate values are integers** (for integer keys):
   ```bash
   while IFS= read -r line; do
       # ... parse key=value ...
       if ! [[ "$value" =~ ^[0-9]+$ ]]; then
           echo "ERROR: Invalid value for $key: '$value' (expected integer)"
           exit 1
       fi
   done < "$CONFIG_FILE"
   ```

### Part 3: Update References

9. **Update .gitignore** if needed (config should be tracked, 000-config.h should not)

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
- `scripts/generate-config.sh` - Update CONFIG_FILE path, add validation logic

## Testing

### Self-Edit Tests
1. Run `./config` - should open in nvim (or $EDITOR)
2. Run `scripts/compile` - should still generate src/000-config.h correctly
3. Verify config values appear in compiled binary

### Auto-Generation Tests
4. Delete config file, run `scripts/compile` - should regenerate with defaults
5. Verify regenerated config has all required keys
6. Verify compilation succeeds with regenerated config

### Validation Tests
7. Remove a required key from config, run `scripts/compile` - should auto-append missing key
8. Set invalid value (e.g., `MAX_BALLS=abc`), run `scripts/compile` - should error with clear message
9. Verify user's existing values are preserved when keys are appended
