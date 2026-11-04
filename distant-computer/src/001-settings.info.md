# 001-settings.lua

Reads a program's settings file from `input/` against what the program
declared, and refuses anything else. Format: `docs/settings-files.md`.

Load: `local settings = dofile(DIR .. "/src/001-settings.lua")`

## Data

**declaration**: a table from setting name (string) to a table:

| field | type | meaning |
| --- | --- | --- |
| `type` | string: `whole`, `decimal`, `text` or `words` | what kind of value |
| `required` | boolean | whether the file must give it |

**values** (returned): a table from setting name to its value. `whole` and
`decimal` give a Lua number, `text` gives a string, and `words` gives a list
of strings. An optional setting the file leaves out is absent from the table.

## Functions

| function | takes | gives |
| --- | --- | --- |
| `read(path, declaration)` | string, **declaration** | **values**; raises `"<path>:<line>: <reason>"` for a missing file, an undeclared or repeated name, a missing required name (line 0, all of them listed), a value of the wrong type, or a line that is not `name = value` |
| `read_program(project_dir, program, declaration)` | string, string, **declaration** | `read` of `<project_dir>/input/<program>` |

A declaration with an unknown type, or without `required`, is the program's
own error, raised before the file is opened.

## Rules worth remembering

- A bare word is letters, digits and `- _ . / :`. Anything else (spaces,
  `@`, quotes) must be in double quotes.
- Inside quotes, only `\"` and `\\` are escapes. `#` is a comment only
  outside quotes.
