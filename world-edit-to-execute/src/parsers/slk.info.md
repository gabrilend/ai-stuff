# slk.lua

Parses SYLK (`.slk`) text spreadsheets, the format of Warcraft III's stock
object tables.

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `parse(text)` | the file's text (string) | `{columns, rows, order}`; raises an error if the `ID;` header or the row-1 column names are missing |

## Result

| Field | Type | Meaning |
|-------|------|---------|
| `columns` | table: column number → name (string) | from row 1 |
| `rows` | table: id (string) → row table (column name → value) | id is column 1; values are numbers when unquoted and numeric, strings otherwise |
| `order` | list of ids (strings) | file order |

## Rules

A cell record that leaves out X or Y keeps the previous one; fields may come
in any order; `;;` inside a quoted value is `;`; formatting and other record
kinds are skipped; `E` ends the file.
