# 096-test-watching-and-power — info

Checks the two tools that let a machine be inspected from outside while it does things nobody can inspect from inside: naming code the model wrote (703), and cutting the power at a chosen instant (704).

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `096-test-watching-and-power.lua` and run the sweep again.*

## Invocation

```
luajit 096-test-watching-and-power.lua [--dir ROOT]
```

## What it describes

| Field | Value | |
|---|---|---|
| &nbsp;&nbsp;↳ `text` | `"move a di\nadd a si\nreturn" }` |  |
| &nbsp;&nbsp;↳ `text` | `"set a 0\nagain:\nadd_number a 1\njump always again" }` |  |
| &nbsp;&nbsp;↳ `text` | `"return" }` |  |
| `snapshot` | `function() return { at = 0 } end` |  |
| `restore` | `function(from) state.at = from.at end` |  |
| `run_for` | `function(instructions) state.at = instructions end` |  |
| `kill` | `function() state.killed_at = state.at end` |  |
| `restart` | `function() return outcome_at(state.killed_at) end` |  |

