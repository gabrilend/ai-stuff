# Lua Menu TUI Library

A framebuffer-based terminal UI library for interactive menus in bash scripts.
Features vim-style navigation, checkbox/radio selection, numeric input fields,
and keyboard shortcuts for quick item access.

## Documentation

- **[User Guide](README-lua-menu-user.md)** - Keyboard controls, navigation, and shortcuts
- **[Developer Guide](README-lua-menu-dev.md)** - API reference and integration instructions

## Features

- Vim keybindings (j/k/h/l/g/G)
- Checkbox and radio button selection
- Numeric input fields with LEFT/RIGHT shortcuts
- Multi-state cycling options
- Quick jump to any checkbox via repeated digit keys (1, 22, 333, etc.)
- SHIFT+digit to go back one tier
- Framebuffer rendering (flicker-free updates)
- Direct /dev/tty I/O (works in command substitution)

## Quick Example

```bash
source "/path/to/libs/lua-menu.sh"

menu_init
menu_set_title "My Tool"

menu_add_section "opts" "multi" "Options"
menu_add_item "opts" "verbose" "Verbose" "checkbox" "0" "Enable verbose output"

menu_add_section "actions" "single" "Actions"
menu_add_item "actions" "run" "Run" "action" "" "Execute"

if menu_run; then
    [[ "$(menu_get_value "verbose")" == "1" ]] && echo "Verbose mode"
fi
```

## Requirements

- LuaJIT 2.0+
- dkjson library
