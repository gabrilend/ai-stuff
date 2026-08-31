# 072-test-touch-memory — info

Checks the memory hands. It used to check one refusal above all -- that a machine could not overwrite itself. That refusal is gone; what is checked now is that the write happens AND that the machine is told, which is what lets it reload itself from disk. Formerly: that a machine cannot write over its own mind. Everything else here is recoverable by writing more software; that one is not.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `072-test-touch-memory.lua` and run the sweep again.*

## Invocation

```
luajit 072-test-touch-memory.lua [--dir ROOT]
```

## What it describes

| Field | Value | |
|---|---|---|
| `usable` | `{ { base = BASE, length = SIZE } }` |  |
| `ours` | `{ ENGINE, WEIGHTS }` |  |
| `read` | `read, write = write` |  |

## Worth knowing

The memory is pretend -- a region on the host with the same rules applied to it -- because what is being tested is the rules, not the three instructions underneath them.

