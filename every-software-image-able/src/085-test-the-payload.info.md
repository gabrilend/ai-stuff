# 085-test-the-payload — info

Checks what the machine wakes up holding, and that everything else can be reached when it becomes relevant. Issues 301 through 304 together, since the instruction, the patterns and the descriptions are only useful as the payload they form.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `085-test-the-payload.lua` and run the sweep again.*

## Invocation

```
luajit 085-test-the-payload.lua [--dir ROOT]
```

## What it describes

| Field | Value | |
|---|---|---|
| `x86_64` | `{ own = "di, si, d, c", others = { "x0 through x7", "a0 t...` |  |
| `aarch64` | `{ own = "x0 through x7", others = { "di, si, d, c", "a0 t...` |  |
| `riscv64` | `{ own = "a0 through a7", others = { "di, si, d, c", "x0 t...` |  |
| `interface` | `0x01, revision = 2 }` |  |
| `revision` | `2 }` |  |
| `revision` | `2 }` |  |
| `revision` | `2 }` |  |
| `instruction` | `instruction, patterns = patterns, descriptions = descript...` |  |
| `architecture` | `"x86_64"` | which processor this card is for. Required rather than defaulted: the calling convention is different on every machin... |
| `removable` | `false` |  |
| `read` | `function(block, count)` |  |
| `write` | `function(block, text)` |  |
| `context` | `context, context_module = context_module, atoms = atoms` |  |
| `store` | `store, keep = keep, on = "disk"` |  |
| `name` | `"pattern", arguments = { "the-four-rungs" } })` |  |
| `name` | `"describe", arguments = { "serial" } })` |  |

## Worth knowing

The uncomfortable checks are here on purpose: the machine can rewrite what it wakes up believing, including the prohibitions, and nothing prevents it. That follows from everything about the machine being mutable, and a test is where it stops being an assumption somebody might quietly build against.

## Where it sits

**Belongs to** `301`.

