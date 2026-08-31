# 050-test-assembly-forward — info

Runs a whole forward pass on the assembly arithmetic and compares it against the recorded answer, bit for bit.

The small pieces were each shown correct on their own. This shows they are correct together, which is a different claim -- a piece can be right in isolation and be handed the wrong thing by the piece before it, and nothing about testing them separately would notice.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `050-test-assembly-forward.lua` and run the sweep again.*

## Invocation

```
luajit 050-test-assembly-forward.lua [--dir ROOT]
```

