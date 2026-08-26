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
| `test_the_heat_governor(t)` |  |
| `test_the_two_sites(t)` |  |
| `test_the_paintbrush(t)` | The mechanism for arguing with a picture that came out wrong. Its whole value |
| `test_the_pool_and_the_graders(t)` |  |
| `test_reading_a_picture(t)` | The decoder, which is what makes grading possible at all -- everything else |
| `ungif(text)` | Enough of a reader to check the writer, written from the format description. |
| `test_the_animation(t)` |  |
| `test_the_dial(t)` |  |
| `main(argv)` |  |
