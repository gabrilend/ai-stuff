# 1310 - Compile-Time Config System

## Status: Open

## Parent Phase: Phase 13

## Problem

System-level constants like MAX_BALLS are scattered across header files. A central config file would make tuning easier and provide a single source of truth for capacity limits.

## Current Behavior

Constants defined in various headers:
- `MAX_BALLS = 1024` in `src/006-ball.h`
- `particle_system_create(1024)` hardcoded in `src/001-main.c`
- `MAX_SPAWN_CREDITS = 3.0f` in `src/006-ball.h`

## Intended Behavior

Single `config.txt` file with key=value pairs:
```
# System capacities
MAX_BALLS=1024
MAX_PARTICLES=1024
MAX_SPAWN_CREDITS=3
```

Compile script parses this and generates `src/000-config.h`:
```c
// Auto-generated from config.txt - do not edit manually
#ifndef CONFIG_H
#define CONFIG_H

#define MAX_BALLS 1024
#define MAX_PARTICLES 1024
#define MAX_SPAWN_CREDITS 3.0f

#endif // CONFIG_H
```

## Why Compile-Time (Not Runtime)

- Zero runtime overhead (values are literals)
- Compiler can optimize based on known constants
- No file I/O or parsing at startup
- Values that affect array sizes must be compile-time anyway
- Simple deployment (no config file to distribute)

## Implementation

### Config File Format (config.txt)

```
# Comments start with #
# Blank lines ignored
# Format: KEY=VALUE (no spaces around =)

# System capacities
MAX_BALLS=1024
MAX_PARTICLES=1024

# Spawning limits
MAX_SPAWN_CREDITS=3

# Future values go here as needed
```

### Generator Script (scripts/generate-config.sh or .lua)

```bash
#!/bin/bash
# Generate src/000-config.h from config.txt

CONFIG_FILE="${DIR}/config.txt"
OUTPUT_FILE="${DIR}/src/000-config.h"

echo "// Auto-generated from config.txt - do not edit manually" > "$OUTPUT_FILE"
echo "#ifndef CONFIG_H" >> "$OUTPUT_FILE"
echo "#define CONFIG_H" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

while IFS= read -r line; do
    # Skip comments and blank lines
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue

    # Parse KEY=VALUE
    key="${line%%=*}"
    value="${line#*=}"

    # Detect if value needs .0f suffix (for floats)
    if [[ "$key" == *"CREDITS"* ]]; then
        echo "#define $key ${value}.0f" >> "$OUTPUT_FILE"
    else
        echo "#define $key $value" >> "$OUTPUT_FILE"
    fi
done < "$CONFIG_FILE"

echo "" >> "$OUTPUT_FILE"
echo "#endif // CONFIG_H" >> "$OUTPUT_FILE"
```

### Integration with Compile Script

Add to `scripts/compile`:
```bash
# Generate config header before compilation
"${DIR}/scripts/generate-config.sh"
```

### Source File Updates

Files include `000-config.h` and remove local definitions:

```c
// src/006-ball.h
#include "000-config.h"
// Remove: #define MAX_BALLS 1024
// Remove: #define MAX_SPAWN_CREDITS 3.0f

// src/001-main.c
#include "000-config.h"
// Change: particle_system_create(1024)
// To: particle_system_create(MAX_PARTICLES)
```

## Implementation Steps

1. Create `config.txt` in project root with initial values
2. Create `scripts/generate-config.sh` (or Lua version)
3. Create initial `src/000-config.h` (generated)
4. Update `scripts/compile` to run generator before gcc
5. Update `src/006-ball.h` to include config.h, remove MAX_BALLS and MAX_SPAWN_CREDITS
6. Update `src/001-main.c` to use MAX_PARTICLES constant
7. Add `src/000-config.h` to .gitignore (generated file)
8. Test compilation works with generated header
9. Test changing config.txt values propagates correctly

## Files to Create

- `config.txt` - Central configuration file
- `scripts/generate-config.sh` - Config parser/generator
- `src/000-config.h` - Generated header (gitignored)

## Files to Modify

- `scripts/compile` - Run generator before compilation
- `src/006-ball.h` - Include config.h, remove moved defines
- `src/001-main.c` - Use MAX_PARTICLES instead of hardcoded 1024
- `.gitignore` - Add src/000-config.h

## Future Values

As the project grows, candidates for config.txt:
- `MAX_PEGS` - Maximum pegs per board
- `MAX_ZONES` - Maximum zones per board
- `MAX_STAGES` - Maximum stages in stage pool
- `WINDOW_WIDTH` / `WINDOW_HEIGHT` - Default window size
- `THREAD_COUNT` - Worker thread pool size

Values that should NOT go in config:
- Physics constants (should be upgradeable or board-specific)
- Spawn rates (should be shared via unified spawner)
- Visual constants (should be themeable eventually)

## Troubleshooting

### "config.h not found"
- Generator script not run before compilation
- Check scripts/compile calls generate-config.sh

### "Redefinition of MAX_BALLS"
- Old #define still exists in source file
- Remove duplicate definition, use config.h version

### "Value didn't change after editing config.txt"
- Need to recompile (config is compile-time)
- Check generator script ran (look at 000-config.h timestamp)

### "Float value missing .0f suffix"
- Generator needs to detect float keys
- Add key pattern to float detection in script

## Notes

- File numbered 000 so it's first in include order
- Generated files should be gitignored
- Keep config.txt in version control (it's the source of truth)
- Lua generator preferred if complex parsing needed later
