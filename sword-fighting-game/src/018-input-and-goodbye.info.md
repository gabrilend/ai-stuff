<!-- made by scripts/build-info-pages from the comments in 018-input-and-goodbye.lua; change the comments and rebuild, not this page -->
# 018-input-and-goodbye


The first and last things a run does.

First, it reads input/: every *.lua file there, in name order, returns a
table of run options, so a run can be set up by dropping a file into a
folder. Options given on the command line are laid over the files.

Last, it writes output/goodbye: the receipt. Its presence and fresh time
prove the run reached a clean ending (a crash never says goodbye); its
numbers say what happened without anyone watching. One writer serves the
window and the headless runner alike, so neither can forget it.

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.read_input` | `dir` | Returns the options from input/*.lua laid over the defaults. |
| `M.receipt_lines` | `run` | run: { seed, mode, ticks, seconds, frames, counters, rounds, result, draws (stream name -> count, from 003's add_draws), screenshots }. |
| `M.write_goodbye` | `dir, run, path` | Writes the receipt, making output/ when it is missing. |
| `M.read_receipt` | `path` | Reads a receipt back into name -> value strings, for the batch gatherer and the tests. |

## Tables of rows

| Name | What it is |
| --- | --- |
| `DEFAULTS` | Every option a run understands, with its default. An option in an input file that is not here stops the run. |

## Private helpers

| Name | Takes | What it does |
| --- | --- | --- |
| `line` | `out, name, value` | (no comment in the source) |
