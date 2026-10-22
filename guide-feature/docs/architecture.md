# Architecture

guide-feature lets a person watch what three computers are thinking about a
project. The three keep editing one shared grid of characters, the
**canvas**, and the person sees each edit land on it, marked so it can be
skimmed. Each machine tries to change as little as it can: a single word
before a sentence, a sentence before a paragraph. So what still matters stays
in place, and what is no longer worth keeping is written over.

This document names the parts and says where each runs. How data moves is in
the datapath documents listed at the end.

## The core terms

These words mean one thing each, everywhere in the project.

| Term | What it is |
|---|---|
| **canvas** | A grid of characters, `W` columns by `H` rows, the same size for everyone. It has a version number that goes up by one with every change. It is the "page" of the vision. |
| **voice** | One of the three mini-computers (`fg-sora-1`, `-2`, `-3`), seen as a speaker. |
| **turn** | One round of thinking on one voice: it receives the canvas, may look into the project, asks its language model for an edited canvas, checks that it fits, and mails the edited canvas back to kuvalu. |
| **base** | The canvas version a voice started its turn from. kuvalu compares the voice's edited canvas against its base, not against whatever is on screen now. So only the words that voice changed are applied, even when another voice's edit landed in between. |
| **word** | A run of characters with no spaces, at a row and column. The unit of change. |
| **blit** | Writing a voice's changed words onto the shared canvas. A changed word is written into its cells. Any old word that loses some, but not all, of its letters is blanked entirely, so no word fragments are ever left on screen. |
| **mark** | A note on the canvas saying who changed which cells, and at which version. A changed word gets a mark, and so does the rest of the sentence it belongs to, so the reader can see "this sentence changed". Marks age as versions go by. How a viewer shows that age (fading colour, for example) is up to the viewer. |
| **merge mode** | How kuvalu turns arriving voice canvases into the shared canvas. `newest` (the original design): blit each voice's changes as they arrive. `distill`: kuvalu runs its own language model over the three latest voice canvases, asks it for one edited canvas, and blits that. Both modes are built and tested. |
| **look** | The tool call a voice's language model can make during its turn, asking for pieces of the project's code. It says how focused or broad it wants the answer to be. Pieces are found by comparing embeddings of their names: variables, structures, functions. Syntax is ignored. |
| **endpoint** | A named llama.cpp server, listed in the `endpoints` file in the project root. Which endpoint each voice, the distiller and the embedder uses is chosen in the same file and re-read every turn, so it can be changed while everything runs. |
| **blitter** | The long-running Lua program on kuvalu that receives voice canvases, blits them (or distills them), keeps the canvas history, and publishes the canvas. |
| **viewer** | Any program that shows the canvas to a person: Lua window, terminal view, HTML page, Android app, Apple Watch app. Viewers only read; they never decide anything about the canvas. |
| **canvas protocol** | The plain-text form of the canvas and its marks, and how viewers get it. A viewer can be written in any language from `docs/canvas-protocol.md` alone. |

## The machines

Four computers.

| Machine | Address | rmail port | Runs |
|---|---|---|---|
| kuvalu, the desktop | 192.168.1.100 | 1223 | rmail mailbox `guide`; the blitter; the canvas server for viewers; the desktop viewers; for now, the llama.cpp servers every voice uses |
| fg-sora-1 | 192.168.1.11 | 10101 | rmail mailbox; the turn hook; a clone of the project being worked on (in RAM if it fits) |
| fg-sora-2 | 192.168.1.12 | 20202 | the same |
| fg-sora-3 | 192.168.1.13 | 30303 | the same |

Known hardware of the mini-computers, from the minimal-llm project's
`docs/005-cluster-topology.md`: six-core Intel i5-8500T, 8 GB of memory, no
graphics card, a BusyBox userland, C library not yet identified.

The network rules are the owner's router settings, described in
`docs/network.md`: the four machines accept connections only from each
other. They may reach out to outside language-model providers, and then
accept only those providers' replies.

## How a round goes

1. kuvalu's canvas changes to version N. It mails the canvas to all three
   voices, as one living rmail message that kuvalu keeps editing.
2. On each voice, the arrival of the canvas fires an rmail hook, which starts
   a turn (or, if a turn is already running, leaves the new canvas waiting for
   the next one).
3. The turn asks the language model for an edited canvas, letting it look
   into the project as it goes, and checks the reply against the canvas size
   like a compiler. Misfits are sent back with the error. The edited canvas is
   mailed to kuvalu with its base version.
4. On kuvalu, the arrival fires a hook that hands the canvas to the blitter.
   In `newest` mode the blitter applies that voice's changes. In `distill`
   mode it asks its own model to combine the voices' latest canvases. Either
   way the canvas becomes version N+1, with marks on what changed.
5. The new version is published to viewers and mailed to the voices, and the
   next round begins.

## Why rmail carries, and Lua decides

rmail (`/home/ritz/programs/r-mail/`) moves files between mailboxes,
encrypted, and runs hook scripts when they arrive. The owner's direction:
"Let rmail handle the communication, and the logic processing will happen
with our running lua program." The hooks only hand things over. All
decisions are in Lua scripts that are easy to edit per setup, including
timing ("we can adjust things like this on a per-implementation basis.
That's why it's a lua script").

## Separation of concerns

- **Generating data**: the voices' turns (edited canvases), the blitter (the
  shared canvas and its marks).
- **Viewing data**: the viewers, which read only the canvas protocol.

## Every program starts with input/ and ends with output/goodbye

Each program reads its settings from `input/` first, and writes a goodbye
receipt to `output/goodbye` as its last act: when it stopped, the seed if
any, and the counts of its own work (turns run, canvases blitted, words
written, words blanked, fit retries). A missing or stale goodbye means the
program did not end cleanly.

## Related documents

- `docs/canvas-format.md` — the canvas as text, in every direction it travels.
- `docs/canvas-protocol.md` — how viewers get the canvas.
- `docs/fit-check.md` — the compiler-style check on every edited canvas.
- `docs/endpoints.md` — the endpoints file.
- `docs/network.md` — the router rules and what they mean for each part.
- `docs/rmail-constraints.md` — what rmail provides and what is built around it.
- `docs/embedding-index-contract.md` — what the look tool needs from a project.
- `docs/datapath-round-trip.md` — the canvas going out and coming back.
- `docs/datapath-voice-turn.md` — one turn on a voice.
- `docs/datapath-blit.md` — how changes land on the shared canvas, in both merge modes.
- `docs/datapath-looking-into-the-project.md` — the look tool.
- `docs/datapath-viewers.md` — from the canvas to a person's eyes.
- `docs/roadmap.md`, `docs/open-questions.md`, `docs/roads-not-taken.md`.
