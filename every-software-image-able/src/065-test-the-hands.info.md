# 065-test-the-hands — info

Checks the boundary between thinking and doing: that the door and the catalogue really are one object, that every refusal is a sentence a machine could act on, that a large answer does not cross into a context that cannot hold it, and that a real thinking machine asking for something gets it and carries on.

This is where the machine's hands are tested before any of them touch anything. The hands here are pretend -- they add numbers and echo text -- because what is being checked is the shape of asking, not what any particular hand does.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `065-test-the-hands.lua` and run the sweep again.*

## Invocation

```
luajit 065-test-the-hands.lua [--dir ROOT]
```

## What it describes

| Field | Value | |
|---|---|---|
| `name` | `"add", takes = { "a", "b" }, gives = "a number"` |  |
| `note` | `"adds two numbers"` |  |
| `does` | `function(arguments)` |  |
| `name` | `"shout", takes = { "word" }, gives = "text"` |  |
| `does` | `function(arguments) return arguments[1]:upper() end` |  |
| `name` | `"flood", takes = {}, gives = "a great deal of text"` |  |
| `does` | `function() return string.rep("x", 100000) end` |  |
| `name` | `"unplug", takes = {}, gives = "nothing good", dangerous =...` |  |
| `note` | `"the sort of thing that ends a board"` |  |
| `does` | `function() return "the board is gone" end` |  |
| `name` | `"trip", takes = {}, gives = "text"` |  |
| `does` | `function() error("a hand that came apart") end` |  |
| `does` | `function() return "made later" end })` |  |
| `reader` | `function(whole, call)` |  |
| `name` | `"curly"` |  |
| `find` | `function(text)` |  |
| `render` | `function(result) return "[" .. result.name .. ": " .. res...` |  |
| `model` | `model, kernels = kernels, conduct = conduct, sampler = sa...` |  |
| `tokenizer` | `tokenizer, tables = { tokens = tokens, merges = {} }` |  |
| `carried` | `sampler_reference.generate_file(20260802, 64)` |  |
| `settings` | `{ temperature = 1.0 }` |  |
| `hands` | `catalogue` |  |
| `name` | `"one byte"` |  |
| `find` | `function(text)` |  |
| `render` | `function(result) return "\4" .. result.text .. "\5" end` | the answer is written in bytes this vocabulary can say, and in none that would be mistaken for another asking. |
| `name` | `"beep", takes = {}, gives = "a short sound"` |  |
| `does` | `function()` |  |
| `does` | `function() outsider_moved = true return "\6" end })` |  |
| `grammar` | `a table below` |  |
| &nbsp;&nbsp;↳ `name` | `"everything is a call"` |  |
| &nbsp;&nbsp;↳ `find` | `function(text)` |  |
| &nbsp;&nbsp;↳ `render` | `function(result) return "\4" .. result.text .. "\5" end` |  |
| `does` | `function() return "\6" end })` |  |

