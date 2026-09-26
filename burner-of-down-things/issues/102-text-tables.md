# 102 — Text tables

Every table the machine keeps on disk is tab-separated text, one row per
line, and every record it keeps is a Lua file returning a table. This issue
is the one reader and writer for each, so no other module parses a line.

## Current Behavior

Nothing reads or writes tables.

## Intended Behavior

- **Escaping:** a field's backslash, tab and newline are written as `\\`,
  `\t`, `\n`, and read back exactly. A row is always one line.
- **Rows:** write an array of rows (each an array of strings) given a header
  (array of field names); read a file back into an array of tables keyed by
  the header. The first line of every table file is its header, prefixed
  `#`.
- **Records:** write a Lua table of strings, numbers, booleans and nested
  tables as a Lua file returning it, keys sorted so the same table always
  writes the same bytes; read one back with a loader that gives the file no
  access to any global (an empty environment).

| Decision | What each path leads to |
|---|---|
| A row has more or fewer fields than the header | Reading refuses, naming the file and line. A short row is a torn write, not a row with blanks |
| A record file does anything but return a table | Refused, naming the file |
| A value is a function or userdata | Writing refuses: a record is data |

## Suggested Implementation Steps

1. Escape and unescape. **Test:** round-trip of every byte value 0–255 and of
   strings of tabs, newlines and backslashes.
2. Table write and read. **Test:** round-trip; a short row refused with its
   line number.
3. Record write and read. **Test:** round-trip of nested tables; identical
   bytes on two writes; a record that calls `os.exit` is refused.

## Blocked by

None.
