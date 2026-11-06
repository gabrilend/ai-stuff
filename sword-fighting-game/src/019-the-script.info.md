<!-- made by scripts/build-info-pages from the comments in 019-the-script.lua; change the comments and rebuild, not this page -->
# 019-the-script


Run options, and input scripted on a timeline. A scripted event is handed,
on the tick its moment arrives, to the same handler a real key, click or
mouse motion goes to, so a scripted run exercises exactly the code a
person's run does. Times are simulated seconds, so a script means the same
thing at any frame rate and with no window at all.

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.parse` | `argv, opts` | Lays the command line over `opts` (from 018's read_input) and returns the script. An unknown option or a missing argument stops the run. |
| `M.due` | `script, now, out` | Appends to `out` every event whose moment has come, each once. |
| `M.help` | nothing | (no comment in the source) |

## Tables of rows

| Name | What it is |
| --- | --- |
| `OPTIONS` | Each option: how many arguments it takes, and what it does with them. `opts` is the run-options table (018); `events` the scripted timeline. |

## Private helpers

| Name | Takes | What it does |
| --- | --- | --- |
| `number` | `s, option` | (no comment in the source) |
