# 037-test-forward — info

Checks the reference forward pass against the recorded fixture, and against a handful of things that must be true of any implementation of this arithmetic whether or not the fixture is right.

This asks whether the model still gives the answer it gave before, and whether the answer has the properties an answer of this kind must have. The second half is the more interesting one -- a fixture only catches change, and these catch being wrong from the start.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `037-test-forward.lua` and run the sweep again.*

## Invocation

```
luajit 037-test-forward.lua [--dir ROOT]
```

