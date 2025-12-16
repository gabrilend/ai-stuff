# Pattern Attribution System

## Attribution Format

### Standard Format
```gitignore
pattern_name           # Source: project-name (reason if applicable)
```

### Multiple Sources
```gitignore
pattern_name           # Universal (count sources)
```

### Conflict Resolution
```gitignore
pattern_name           # Resolution: explanation
!exception_pattern     # Conflict resolution for project-x
```

## Examples

### OS Patterns
```gitignore
.DS_Store              # Universal (macOS - 12 sources)
Thumbs.db              # Universal (Windows - 8 sources)
```

### Build Patterns
```gitignore
*.o                    # Universal (C compilation - 12 sources)
target/                # Source: handheld-office (Rust builds)
```

### Project Patterns
```gitignore
# Project: adroit (Character system)
save_*.dat             # Game save files
character_cache/       # Character data cache

# Project: console-demakes (Gameboy development)
*.gb                   # ROM files
tools/rgbds/           # Build tools
```

### Conflict Resolutions
```gitignore
*.log                  # Universal (multiple sources)
!debug.log             # Resolution: console-demakes needs debug logs
```

## Implementation Guidelines

1. Keep comments concise but informative
2. Group related patterns together
3. Use consistent formatting
4. Include rationale for non-obvious patterns
5. Document all conflict resolution decisions
