# 062-test-thinking-loop — info

Closes the loop and checks what stops it. Text becomes tokens, tokens run through the assembly engine, a token is drawn and joins the input -- and each of the four stoppers is exercised by name, because a machine that cannot be stopped cannot be told to stop doing something.

Every part of the engine was proven alone against a readable twin. This proves they are one machine: it can be spoken to, it speaks back, it does not redo thinking it has already done, and it stops when told, when finished, and when it runs out of room -- saying which.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `062-test-thinking-loop.lua` and run the sweep again.*

## Invocation

```
luajit 062-test-thinking-loop.lua [--dir ROOT]
```

## What it describes

| Field | Value | |
|---|---|---|
| `model` | `model` |  |
| `kernels` | `kernels` |  |
| `conduct` | `conduct` |  |
| `sampler` | `sampler` |  |
| `tokenizer` | `tokenizer` |  |
| `tables` | `tables` |  |
| `carried` | `carried` |  |
| `settings` | `{ temperature = 1.0 }` |  |
| `max_tokens` | `50` |  |
| `interrupt` | `function(spoken) return spoken >= 3 end` |  |

## Worth knowing

The model is the tiny fixture model, whose words are numbers rather than English. The loop neither knows nor cares; what is tested here is the machinery of thought, not its quality.

