# 028-the-shape-of-a-graph — info

Builds a ComfyUI workflow, and writes it in the two shapes ComfyUI accepts.

For a general: the program that actually makes the pictures reads a graph -- boxes with sockets, wired together. It reads that graph in two different file formats which are not interchangeable. One is what a script posts to it when nobody is watching; the other is what its editor opens when somebody drags a file onto the canvas. A learner wants the second. A batch of six thousand wants the first. This describes the graph once and writes both.

`docs/005` has the formats. What this file adds is the thing neither format contains: a catalogue of what each kind of box actually looks like.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `028-the-shape-of-a-graph.lua` and
run the sweep again.*

## What it offers

| | |
|---|---|
| `M.known(kind)` |  |
| `M.catalogue()` |  |
| `M.new()` | An empty graph. |
| `M.connections_from_api(text_object)` | The wires an emitted posting-format graph describes. |
| `M.connections_from_ui(ui)` | The same, read back out of the editor-format graph. |

### `M.connections_from_api(text_object)`

The wires an emitted posting-format graph describes.

Read back out of what was written rather than off the graph it came from, which is what makes comparing the two formats a real check.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `find_socket(list, name)` | Which numbered socket a named one is, and what type it carries. |
| `Graph:add(kind, values, label)` | One node, with its controls set by name. |
| `Graph:link(from, output_name, to, input_name)` | One wire, named at both ends. |
| `Graph:connections()` | Every wire, as text, for comparing one description of a graph against another. |
| `Graph:lay_out()` | Where each node sits on the canvas. |
| `Graph:api()` | The graph in the shape the endpoint accepts. |
| `Graph:ui()` | The graph in the shape the editor opens. |

## Where it sits

Used by `029-the-workflow-for-one-kanji`, `035-test-the-machine`.
