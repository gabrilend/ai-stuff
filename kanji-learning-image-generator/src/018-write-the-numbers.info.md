# 018-write-the-numbers — info

Writes the data format the far end of this project reads, keeping the keys in the order they were put in.

For a general: the output of this whole project is a structured text file that another program opens. A plain table in this language has no order to its keys -- ask for them back and you get whichever arrangement the internals happened to land on, differently between runs. For a file a person is going to open and a version control system is going to compare, that is not acceptable, and sorting does not fix it: sorted keys put the settings before the name of the thing being configured, which is backwards for reading.

So there is an ordered table here, and every emitter in this project builds one. Arrays stay ordinary.

There is no reader. Nothing in this project opens one of these.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `018-write-the-numbers.lua` and
run the sweep again.*

## What it offers

| | |
|---|---|
| `M.object(...)` | A table that remembers the order its keys were given in. |
| `M.is_object(value)` |  |
| `M.keys(value)` | An ordered table's keys, in their order. |
| `M.encode(value, options)` | One value, as text. |

### `M.object(...)`

A table that remembers the order its keys were given in.

Pairs may be passed in directly, which is how most call sites use it:   M.object("class_type", "KSampler", "inputs", something)

### `M.encode(value, options)`

One value, as text.

options.indent  the string one level of nesting is indented by, or false for                 no line breaks at all. Indented by default: these files are                 meant to be opened.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `write_string(text, out)` |  |
| `write_number(value, out)` | A number, printed the way the far end expects to read it. |
| `write_value(value, out, indent, depth)` |  |

## Where it sits

Used by `020-test-the-ink`, `028-the-shape-of-a-graph`, `030-make-one-kanji`, `035-test-the-machine`, `044-run-the-pictures`.
