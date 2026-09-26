# 027-the-language-table.lua

Decides a file's language, role and include scanner from its name and first
8 KiB. A **row**: `language` (string), `role` (`code`, `doc`, `data`,
`build`, `binary`), `scanner` (a scanner name in 028, or nil).

| Name | In | Out |
|---|---|---|
| `classify(path, head)` | the file's path; its first 8 KiB | a row. Order: whole name, extension (as written, then lower-cased), NUL byte → binary, `#!` interpreter, else `other`/`data` |
| `BY_EXTENSION`, `BY_NAME`, `BY_INTERPRETER` | | the tables; adding a language is adding a row |
