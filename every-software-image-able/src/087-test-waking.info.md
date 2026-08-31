# 087-test-waking — info

Checks the first thing that runs: that the machine finds out what processor it is on, says so before handing over, and picks the engine that matches what that processor actually has. Issue 402.

The computer is switched on and asked to describe itself. What it says is compared against what the host knows about the same processor, because a detection that agrees with nothing is a detection nobody can trust.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `087-test-waking.lua` and run the sweep again.*

## Invocation

```
luajit 087-test-waking.lua [--dir ROOT] [--seconds N]
```

## Where it sits

**Belongs to** `402`.

