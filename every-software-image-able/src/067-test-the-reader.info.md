# 067-test-the-reader — info

Checks that something too big to hold can be read: cut on meaningful boundaries, walked a window at a time, and returned as a few valuable pieces that say where they came from -- with the machine's own judgement doing the deciding rather than the reader.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `067-test-the-reader.lua` and run the sweep again.*

## Invocation

```
luajit 067-test-the-reader.lua [--dir ROOT]
```

## What it describes

| Field | Value | |
|---|---|---|
| `context` | `4000` |  |
| `ask` | `function(question, window, numbers)` |  |
| `windows_seen` | `windows_seen + 1` |  |
| `found` | `true` |  |
| `pages` | `pages or {}` |  |
| `context` | `4000` |  |
| `ask` | `function() return { found = false } end` |  |
| `context` | `4000` |  |
| `ask` | `function() return { found = true } end` |  |
| `summarise` | `function(question, pages)` |  |
| `context` | `4000` |  |
| `resident` | `8` |  |
| `ask` | `function(question, window)` |  |
| &nbsp;&nbsp;↳ `question` | `"the same thing, asked wider" }` |  |
| `budget` | `2048` |  |
| `reader` | `reader_module.for_hands(reader_module.new({` |  |
| &nbsp;&nbsp;↳ `context` | `4000` |  |
| &nbsp;&nbsp;↳ `ask` | `function(question, window)` |  |
| `name` | `"read", takes = {}, gives = "far too much text"` |  |
| `does` | `function() return document end` |  |

