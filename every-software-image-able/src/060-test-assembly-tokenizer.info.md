# 060-test-assembly-tokenizer — info

Runs the readable tokenizer (038) and the assembly tokenizer (059) over the same awkward corpus and requires the same numbers, the same text back, and refusals at the same places.

A subtly wrong tokenizer is the worst failure available -- the machine just seems mildly stupid, and nobody suspects the right thing. So the assembly half is not tested for reasonableness; it is tested for exact agreement with the readable half, on the cases where tokenizers actually disagree with each other.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `060-test-assembly-tokenizer.lua` and run the sweep again.*

## Invocation

```
luajit 060-test-assembly-tokenizer.lua [--dir ROOT]
```

## What it describes

| Field | Value | |
|---|---|---|
| `text` | `table.concat(all_bytes) }` |  |
| `text` | `table.concat(long_parts) }` |  |

