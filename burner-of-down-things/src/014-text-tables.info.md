# 014-text-tables.lua

The one reader and writer of tables (tab-separated text, header line first,
prefixed `#`) and records (Lua files returning one table).

| Function | In | Out |
|---|---|---|
| `escape(field)` | string or number | the field with `\`, tab, newline, carriage return written as `\\`, `\t`, `\n`, `\r` |
| `unescape(field)` | escaped string | the original; refuses an unknown escape |
| `split_line(line)` | one line | array of raw (still escaped) fields |
| `row_line(row)` | array of fields | one escaped line, no newline |
| `write(path, header, rows)` | path; array of field names; array of arrays | writes through a neighbour file and a rename; refuses a row of the wrong width |
| `parse(text, where)` | a table file's text; a name for errors | rows (arrays of tables keyed by field name), header |
| `read(path)` | path | rows, header; refuses a short row naming its line, or a torn last line |
| `write_record(path, table)` | path; table of strings, numbers, booleans, tables | a Lua file with keys sorted, so the same table always writes the same bytes |
| `read_record(path)` | path | the table; the file runs with no globals at all, so it cannot do anything but build a table |
