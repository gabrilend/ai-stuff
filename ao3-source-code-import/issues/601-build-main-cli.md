# 601: Build Main CLI Interface

## Status
- [ ] Not started

## Current Behavior

No CLI exists.

## Intended Behavior

A command-line tool that:
- Accepts project path as argument
- Supports dry-run mode
- Provides verbose output option
- Runs the complete pipeline
- Integrates with TUI library for interactive mode

## Usage Examples

```bash
# Archive world-edit-to-execute
./run --project /path/to/world-edit-to-execute

# Dry run - show what would be uploaded
./run --project /path/to/project --dry-run

# Update existing archive
./run --project /path/to/project --update

# Interactive mode with TUI
./run -I

# Self-archive this project
./run --self
```

## Suggested Implementation Steps

1. Create src/main.lua as entry point
2. Implement argument parsing
3. Wire up all modules in pipeline order
4. Add dry-run mode (stop before upload)
5. Add verbose logging
6. Create wrapper bash script (run)
7. Add TUI mode using lua-menu.sh

## Related Documents

- All previous issues
- /home/ritz/programming/ai-stuff/scripts/libs/lua-menu.sh

## Notes

This is where it all comes together. The CLI is the user-facing interface.
