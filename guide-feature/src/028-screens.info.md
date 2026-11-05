# 028-screens — info

One canvas for each screen (issue 205): which canvases a context change
makes, the turns that paint them in batches, the rounds and the contexts
they hold, and what each screen shows meanwhile. The mode is
`screen-mode` in `input/screens`: `round`, `asynchronous` or `smallest`.

| Name | Type | Meaning |
|---|---|---|
| `read_mode(root)` | function | the mode from `input/screens`; read again at every round |
| `watched(list)` | function | the screen list `{ name, width, height, watched }` checked, and the watched ones largest first (cells, then width, then name) |
| `canvases(mode, watched)` | function | `{ name, width, height }` per canvas: one per screen, or in `smallest` one called `smallest` at the narrowest width and shortest height |
| `plan(mode, watched, voices)` | function | batches of turns `{ canvas, width, height, voice, slot }`: `round` a batch per canvas, largest first; the others one batch. `slot` numbers turns that need endpoints at once |
| `keeper({ mode = fn })` | function | a keeper of rounds |
| `keeper:context(context, list, voices)` | method | a context change: the first batch of a new round, or nil when it waits for the round under way. Only the newest waiting context is kept |
| `keeper:batch_done()` | method | the next batch (with `round`, `context`, `mode`), the first of a waiting round, or nil |
| `keeper.counts` | table | `rounds`, `batches`, `turns`, `contexts-held`, `contexts-skipped` |
| `display(screen, mode, made)` | function | `{ canvas, centred }` once the screen's canvas is made at its size (or, in `smallest`, fits it), else `{ loading = true }` |

The mode and the watched screens are taken when a round starts. Not built
yet, behind these seams: running the turns (405), a blitter and canvas
folder per screen's canvas, the screen list from the display programs
(801-803, 901-902), and an endpoint per asynchronous slot (402).
