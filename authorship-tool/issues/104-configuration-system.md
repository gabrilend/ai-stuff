# Issue 104: Configuration System

**Phase**: 1 - Foundation & Core Infrastructure
**Status**: Open
**Priority**: Medium
**Created**: 2026-01-08

---

## Current Behavior

No configuration system exists. The project needs to read configuration from the input/ directory to customize behavior.

---

## Intended Behavior

The system should:
- Read configuration file from input/ directory on startup
- Parse configuration into Lua table structure
- Provide configuration access to all modules
- Support configuration for:
  - Document input paths
  - Module-specific settings
  - UI preferences
  - Output locations
  - Logging levels
- Use sensible defaults when configuration missing
- Validate configuration values
- Report configuration errors clearly

---

## Suggested Implementation Steps

1. Create `src/config.lua` for configuration management
2. Define default configuration structure
3. Implement configuration file reading (input/config.lua or input/config.txt)
4. Implement Lua table-based configuration parsing
5. Add configuration validation (type checking, required fields)
6. Create configuration merge (defaults + user config)
7. Provide `get_config(key)` function for access
8. Add configuration error reporting
9. Create sample configuration file in input/config.lua.example
10. Document configuration options in docs/configuration.md
11. Write tests for various configuration scenarios
12. Document functions in src/config.info.md

---

## Related Documents

- docs/technical-design.md (Configuration system section)
- User's global instructions (program reads from input/)
- docs/roadmap.md (Phase 1)

---

## Implementation Notes

**Configuration Structure**:
```lua
Config = {
    paths = {
        input = "input/",
        output = "output/",
        temp = "tmp/",
        modules = "libs/"
    },
    document = {
        formats = {"txt", "md"},
        max_size_mb = 10,
        encoding = "utf-8"
    },
    ui = {
        theme = "dark",
        keybindings = "vim"
    },
    logging = {
        level = "info",  -- debug, info, warn, error
        output = "tmp/authorship-tool.log"
    },
    modules = {
        -- Module-specific configurations
        ["document-reader"] = {
            recursive = true,
            follow_symlinks = false
        }
    }
}
```

**File Format**:
Use Lua table syntax for configuration file:
```lua
-- input/config.lua
return {
    paths = {
        input = "input/stories/"
    },
    logging = {
        level = "debug"
    }
}
```

**Validation**:
- Check paths exist and are accessible
- Validate enum values (theme, keybindings, etc.)
- Ensure numeric values in valid ranges
- Warn on unknown configuration keys (typos)

---

## Testing Criteria

- [ ] Reads configuration file successfully
- [ ] Uses defaults when config file missing
- [ ] Merges user config with defaults correctly
- [ ] Validates configuration values
- [ ] Reports clear errors for invalid config
- [ ] Modules can access their configuration
- [ ] Handles missing optional values gracefully
- [ ] Sample configuration file works

---

## Dependencies

- 101 (module loading framework) - modules need config

---

## Blocks

- 103 (document reader may need config for paths)
- 105 (logging needs config for level/output)
