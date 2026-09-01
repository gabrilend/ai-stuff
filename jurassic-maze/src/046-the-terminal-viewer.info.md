# 046-the-terminal-viewer

One layer of the maze as characters, held at a gate.

Read this page rather than the source.

## What it is for

**Not a lesser window.** It exists for the case where a number says something is
wrong and you need to see *where*, over ssh, with no graphics — and the window is
worse at that, because in the window you have to find the thing first.

It holds at a gate and advances only when told. A simulation you can hold still
is a simulation you can read.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `slice(Stone, store, layer, x0, y0, w, h)` | | one horizontal slice, as an array of strings |
| `overlay_bodies(rows, Stone, store, bodies, creatures, layer, x0, y0)` | | the same rows, with bodies as letters |
| `run(root, argv)` | | the gate loop |
| `GLYPH` | | the four characters |

`slice` is a function from a store and a layer to text with no terminal anywhere
in it, so it can be tested against a picture written out by hand in a test file.
A rendering test whose expectation is a picture is a test somebody can read.

## The glyphs

| | |
| --- | --- |
| `#` | solid at this layer, and buried |
| `-` | solid at this layer with air above: somewhere to stand |
| `.` | air here, but stone somewhere above: you are under an arch |
| ` ` | nothing at all |

Bodies are the first letter of their kind, upper case, over the top.

## Commands

Return for one tick; `10` and `100` for more; `u` and `d` to change layer; `w`
`a` `s` `f` to pan; `b` to jump to the lowest body; `r` for the report so far;
`q` to leave. A table, printed from itself, so the help cannot drift from what
the keys do.

## It is also a program

Invoked directly as `luajit src/046-the-terminal-viewer.lua <root> <args>`, for
the same reason as the headless runner: there is no spelling of `luajit -e` that
survives a command line of its own. Without `--`, luajit reads the run's `--seed`
as an option meant for itself; with `--`, it treats the next argument as a script
to open.
