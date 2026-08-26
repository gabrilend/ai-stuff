# Phase 3 — The Machine

**Goal.** A scene becomes a file somebody can run — then every character at once,
then a way to look at what came out.

`303` is the point of the project. Everything before it makes one recipe; that
one makes all of them, and makes them without a person choosing which, which is
the difference between a demonstration and a learning material.

## Issues

| | | Status |
|---|---|---|
| `301` | The shape of a ComfyUI graph | not started |
| `302` | The workflow for one kanji | not started |
| `303` | The whole alphabet at once | not started |
| `304` | A gallery you can page through | not started |
| `305` | The documentation as a website | not started |
| `306` | The demos, and the thing that runs them | not started |

## Where the risk is

**The far end is not here.** There is no ComfyUI on this machine, so a workflow
this project calls correct is a workflow that has never been opened by the
program it is for. The catalogue in `301` is written from the format's
requirements and the internal check is that both emitted formats describe the
same graph — which catches this project disagreeing with itself, and cannot catch
this project disagreeing with ComfyUI.

The named model files are the same situation and worse: they are strings that
must match some other machine's `models/` directory, and nothing here can look.
`302` states the assumption in its report rather than pretending to check it.

**The interface-only widget is the specific trap** (`docs/005`). It produces a
file that loads without complaint and samples with the wrong settings.
