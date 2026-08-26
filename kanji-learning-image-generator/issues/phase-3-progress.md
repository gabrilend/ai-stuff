# Phase 3 — The Machine

**Goal.** A scene becomes a file somebody can run — then every character at once,
then a way to look at what came out.

`303` is the point of the project. Everything before it makes one recipe; that
one makes all of them, and makes them without a person choosing which, which is
the difference between a demonstration and a learning material.

## Issues

| | | Status |
|---|---|---|
| `301` | The shape of a ComfyUI graph | **completed** — a catalogue of a dozen node types, and both formats checked against each other |
| `302` | The workflow for one kanji | **completed** — thirteen nodes, two files, and a card holding every decision |
| `303` | The whole alphabet at once | **completed** — every character, in parallel, with a report that found ten real gaps on its first run |
| `304` | A gallery you can page through | **completed** — thumbnails first, because thumbnail is where the illusion has to work |
| `305` | The documentation as a website | **completed** — every reference a link, and the build fails if one does not resolve |
| `306` | The demos, and the thing that runs them | **completed** — three demonstrations, a runner, and one command that runs every test |
| `307` | Slow down when the machine runs hot | **completed** — a share of the machine, politely asked for, resting when it climbs |

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

## What `301` turned up

**A bug whose symptom was nowhere near its cause.** The first workflow came out
with every node written as an empty array, and nothing errored anywhere along
the way.

Every file here loads `src/009` by *running* it, because these filenames carry
their index and their hyphens and bending them into module identifiers would
mean the name a person opens and the name a program uses are two different
strings. Run once per file, it produced one module cache per file — and so
several copies of the ordered-table module. An ordered table is recognised by
its metatable, a second copy has a second metatable, and a table built through
one copy is invisible as such to the other. The writer concluded it was an empty
array and said so.

It had also been rebuilding the record store once per module, which nobody had
noticed because the store caches to disk.

## What `303` turned up

**The report paid for itself on its first real run.** Ten of the five hundred
commonest characters could not be made at all, and the cause was one thing wearing
three faces: a meaning-bearing piece with no entry. Three characters shared the
jade radical. Three more failed on a left-hand form of the bank radical that has
a **different Unicode number** from the form that stands alone and is visually
identical — the lists held one of the two, and no amount of staring at the file
would have shown it.

## What `307` turned up

**A cost nobody in this project had thought about at all.** Every design note
here weighs correctness against clarity and none of them weighed anything
against the machine the work runs on. Asking for every processor is the obvious
thing to do and it held the chip at the top of its thermal range for the length
of a run, while leaving nothing for the person at the keyboard.

The fix that mattered was not a smaller number. It was reading the temperature
and resting when it climbs — the machine already reports it, as a file, and
nothing had ever asked.
