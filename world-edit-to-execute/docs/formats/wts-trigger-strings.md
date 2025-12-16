# war3map.wts - Trigger Strings Format Specification

The war3map.wts file contains a string table for localized text. Other map files
reference strings by ID using `TRIGSTR_XXX` placeholders.

---

## Overview

Unlike other WC3 map files, war3map.wts is a plain text file (not binary).
It provides a simple key-value mapping of string IDs to text content.

Key features:
- Human-readable text format
- Supports multi-line strings
- Preserves WC3 color codes and formatting
- No version number or binary header

---

## File Format

### Basic Syntax

```
STRING <id>
{
<content>
}
```

Each string definition consists of:
1. `STRING` keyword followed by numeric ID
2. Opening brace `{` on a new line
3. String content (may span multiple lines)
4. Closing brace `}` on a new line

### Example File

```
STRING 0
{
My Custom Map
}

STRING 1
{
Created by Author Name
}

STRING 2
{
This is a longer description
that spans multiple lines.

It can even have blank lines in it.
}

STRING 100
{
|cff00ff00Green colored text|r and normal text.
}
```

---

## String IDs

### Valid IDs

- Must be non-negative integers (0, 1, 2, ...)
- IDs do not need to be sequential
- If duplicate IDs exist, the first definition is used

### ID Ranges

| Range | Typical Usage |
|-------|---------------|
| 0-99 | Map metadata (name, description) |
| 100-999 | Trigger strings |
| 1000+ | Object editor strings |

Note: These ranges are conventions, not enforced by the format.

---

## TRIGSTR_ References

Other map files reference strings using the `TRIGSTR_` prefix.

### Reference Format

```
TRIGSTR_<id>
```

The ID is zero-padded to 3 digits minimum:

| String ID | Reference |
|-----------|-----------|
| 0 | TRIGSTR_000 |
| 1 | TRIGSTR_001 |
| 42 | TRIGSTR_042 |
| 1000 | TRIGSTR_1000 |

### Resolution Behavior

1. When WC3 encounters `TRIGSTR_XXX`, it looks up ID XXX in the string table
2. If found, the placeholder is replaced with the string content
3. If not found, the placeholder remains as literal text

### Negative IDs

`TRIGSTR_` references with negative IDs resolve to empty strings:
- `TRIGSTR_-001` → empty string

---

## Color Codes

WC3 strings support inline color formatting:

### Color Syntax

```
|cffRRGGBB<text>|r
```

| Component | Description |
|-----------|-------------|
| `|c` | Color start marker |
| `ff` | Alpha (always ff for opaque) |
| `RR` | Red component (hex 00-FF) |
| `GG` | Green component (hex 00-FF) |
| `BB` | Blue component (hex 00-FF) |
| `<text>` | Colored text content |
| `|r` | Reset to default color |

### Examples

```
|cffff0000Red text|r
|cff00ff00Green text|r
|cff0000ffBlue text|r
|cffffd700Gold text|r
|cff808080Gray text|r
```

### Nesting

Colors can be nested but don't stack - the innermost color applies:

```
|cffff0000Red |cff00ff00Green|r still red|r
```

---

## Special Characters

### Escape Sequences

| Sequence | Result |
|----------|--------|
| `\n` | Newline (in some contexts) |
| `\\` | Literal backslash |
| `|n` | Newline (WC3 specific) |

### Character Encoding

- UTF-8 is the expected encoding for modern maps
- Legacy maps may use Windows-1252 or other encodings
- Implementation should handle both gracefully

---

## Parsing Algorithm

```lua
-- {{{ parse_wts
local function parse_wts(content)
    local strings = {}
    local pattern = "STRING%s+(%d+)%s*\n{(.-)}"

    for id, text in content:gmatch(pattern) do
        local string_id = tonumber(id)
        if string_id and not strings[string_id] then
            -- Trim leading/trailing newlines from content
            text = text:gsub("^\n", ""):gsub("\n$", "")
            strings[string_id] = text
        end
    end

    return strings
end
-- }}}
```

### Edge Cases

1. **Empty strings**: Valid - just empty braces `{}`
2. **Braces in content**: Inner braces are allowed (non-greedy match)
3. **Whitespace**: Preserve whitespace within braces
4. **Comments**: No comment syntax defined in format

---

## TRIGSTR Resolution

```lua
-- {{{ resolve_trigstr
local function resolve_trigstr(text, strings)
    return text:gsub("TRIGSTR_(-?%d+)", function(id)
        local num = tonumber(id)
        if num and num >= 0 and strings[num] then
            return strings[num]
        elseif num and num < 0 then
            return ""  -- Negative IDs resolve to empty
        else
            return "TRIGSTR_" .. id  -- Keep unresolved
        end
    end)
end
-- }}}
```

---

## Usage in Other Files

### war3map.w3i

Map name, author, and description often use TRIGSTR references:

```
Map Name: TRIGSTR_000
Author: TRIGSTR_001
Description: TRIGSTR_002
```

### war3map.j (JASS)

Script strings may reference trigger strings:

```jass
call DisplayTextToPlayer(Player(0), 0, 0, "TRIGSTR_100")
```

### Object Editor Files

Unit names, tooltips, and descriptions can use TRIGSTR:

```
[h000]
Name=TRIGSTR_500
Tip=TRIGSTR_501
Ubertip=TRIGSTR_502
```

---

## Implementation Notes

### StringTable Class

```lua
-- {{{ StringTable class
local StringTable = {}
StringTable.__index = StringTable

function StringTable.new()
    return setmetatable({strings = {}}, StringTable)
end

function StringTable:load(wts_content)
    self.strings = parse_wts(wts_content)
end

function StringTable:get(id)
    return self.strings[id]
end

function StringTable:resolve(text)
    return resolve_trigstr(text, self.strings)
end

function StringTable:count()
    local n = 0
    for _ in pairs(self.strings) do n = n + 1 end
    return n
end
-- }}}
```

### Lazy Resolution

For performance, consider lazy resolution - only resolve TRIGSTR when
the string is actually displayed, not during initial parsing.

---

## File Validation

A valid wts file:
1. Contains zero or more STRING definitions
2. All IDs are non-negative integers
3. All braces are properly matched
4. File encoding is consistent (UTF-8 preferred)

Invalid conditions to handle:
- Missing closing brace → skip malformed entry
- Non-numeric ID → skip entry
- Duplicate ID → use first occurrence

---

## References

- [W3X Files Format - 867380699.github.io](https://867380699.github.io/blog/2019/05/09/W3X_Files_Format)
- [WC3MapTranslator - GitHub](https://github.com/ChiefOfGxBxL/WC3MapTranslator)
- [W3M and W3X Files Format - XGM](https://xgm.guru/p/wc3/warcraft-3-map-files-format)
