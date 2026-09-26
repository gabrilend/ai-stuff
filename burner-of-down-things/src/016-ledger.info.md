# 016-ledger.lua

A case's append-only memory, each line chained to the one before by SHA-256
(docs/003). A line: `seq`, `time`, `kind`, `about`, `text`, `prev`, `hash`,
tab-separated; `hash` covers the first six fields as written on disk.

| Function | In | Out |
|---|---|---|
| `create(path, text)` | a path with no file yet; a sentence | the first line (`case-opened`), as a table |
| `append(path, kind, about, text)` | ledger path; a kind from `KINDS`; what it is about (string, `-` for nothing); a sentence | the new line as a table; reads only the file's tail |
| `verify(path)` | ledger path | `{ok=true, count, head}` or `{ok=false, line, check, expected, found}`; `check` is `fields`, `seq`, `prev`, `hash`, `exists` or `empty` |
| `describe_failure(result)` | a failed verify result | one sentence |
| `read(path)` | ledger path | array of lines as tables (`seq` number; others strings), unescaped; does not verify |
| `head(path)` | ledger path | the last line's hash |
| `KINDS` | | set of every kind (docs/003's table) |
| `ZERO_HASH` | | 64 zeroes, the first line's `prev` |
