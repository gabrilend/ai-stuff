# 026-read-blob — info

Reads a packed model and says what is in it. A separate program from the
packer on purpose: generation and viewing stay apart, so a blob gets checked
by something that did not make it and cannot share its assumptions.

**This is also the reference for the engine's own reading code** (issue 102).
Whatever the assembly does when it walks a blob, it should agree with this.

## Invocation

```
luajit src/026-read-blob.lua BLOB [--tensors] [--tokens] [--dir ROOT]
```

Exit status is non-zero when the blob is refused.

## What it prints

The format version and size; the model's shape in a sentence; **the size a
full key-and-value cache would reach**, computed rather than stated, because
that number decides how long a thought can get (issue 103c); the tensor and
token counts; and whether any two tensors share a byte.

`--tensors` lists every tensor with its precision, shape, size and offset.
`--tokens` shows the first two dozen tokens with their numbers.

## What it refuses, and why each matters

| Refusal | What it would otherwise cause |
|---|---|
| Wrong magic | reading rubbish as a model |
| A version it does not know | tensors full of neighbouring tensors — does not fail, just thinks badly |
| Header length disagreeing with actual length | a truncated blob believed whole until something reads past the end |
| A tensor whose data runs past the end | the same, one tensor at a time |
| An undefined precision code | arithmetic on bytes interpreted as the wrong kind of number |

Overlapping tensors are reported rather than refused, because a blob can be
worth inspecting even when it is wrong — but the overlap is the failure that
never announces itself, so it is checked on every read rather than on request.
