# 035-test-the-machine — info

Everything phase three claims, checked.

For a general: phase three turns a scene into a file somebody else's program can run, then does it for every character at once.

The far end is not on this machine. A workflow this project calls correct has never been opened by the program it is for, so these tests can only catch this project disagreeing with itself -- which they do thoroughly, because the two file formats are two descriptions of one graph and comparing them is a real check. They cannot catch this project disagreeing with ComfyUI.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `035-test-the-machine.lua` and
run the sweep again.*

## Invocation

```
luajit src/035-test-the-machine.lua [--dir ROOT]
```

## What it offers

| | |
|---|---|
| `M.run(options)` |  |

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `test_the_graph(t)` |  |
| `test_the_workflow(t)` |  |
| `test_making_one(t)` |  |
| `main(argv)` |  |
