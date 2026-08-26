# 036 — A walkthrough

Everything a person can run, in the order they would run it, and what each one
leaves behind.

Every one of them takes `--dir PATH` to point at a copy of this project
somewhere other than where it was written.

## Start here

```
luajit src/010-fetch-the-archives.lua
```

Takes the two archives this project reads and puts them in `assets/`, then
writes down which editions arrived. About thirty megabytes. Nothing else works
until this has run, and everything that needs them says so by name if they are
missing.

```
./run-demo
```

Lists the three demonstrations and asks which. The second one ends with six
characters side by side at two sizes and tells you to look at the small one;
that picture is the whole specification of this project.

```
./run-tests
```

Every test file, plus a check that the page beside each source file still
matches that file's comments.

## Making things

```
luajit src/030-make-one-kanji.lua --chars 休森
```

One folder per character holding the grey picture that hides it, the
stroke-order arrows, the recipe in both the shapes ComfyUI reads, and a card
recording every decision that went into them.

```
luajit src/031-make-them-all.lua --grade 1
luajit src/031-make-them-all.lua --jlpt 5
luajit src/031-make-them-all.lua --frequent 500
luajit src/031-make-them-all.lua --chars 木火水
luajit src/031-make-them-all.lua --all
```

The same thing for a whole set, in parallel, with a report at the end saying
what was made, what could not be, which worlds everything landed in, and which
pieces of characters still cannot be pictured. `--out DIR` puts it somewhere
other than the RAM scratch area; `--workers N` overrides how many run at once.

```
luajit src/032-a-gallery-you-can-page.lua --set DIR
```

Turns a set into a page. Open the `index.html` it names.

## Looking at how it decided

Each of these prints its reasoning for characters you name, and most also have a
mode that reports across the whole archive.

| | |
|---|---|
| `src/019-the-kanji-record.lua --report` | what the two archives joined into, and everything that fell out of the join |
| `src/021-the-shape-of-a-stroke.lua --chars 休` | every stroke measured: direction, size, bend, hook, place, share of the ink |
| `src/021-the-shape-of-a-stroke.lua --calibrate` | the numbers every boundary in that file was set from |
| `src/023-the-component-lexicon.lua --chars 語` | what each piece of a character is taken to depict, and where that came from |
| `src/023-the-component-lexicon.lua --coverage` | how much of the archive can be pictured, and the queue of what cannot |
| `src/024-the-scene-grammar.lua --chars 時` | the world, the runner-up, the cast, the ground, and a role for every stroke |
| `src/024-the-scene-grammar.lua --spread` | which world every character in the archive landed in |
| `src/025-the-words-the-machine-reads.lua --chars 川` | the finished sentence, and what every prompt refuses |
| `src/022-the-structure-field.lua --chars 鬱` | the grey pictures themselves, written out to be looked at |
| `src/026-arrows-that-teach-the-order.lua --chars 語` | the arrow layer, and a field beside it to lay it over |
| `src/031a-when-the-machine-runs-hot.lua` | what this machine will let a run take, and how hot it is now |

## Documentation

```
luajit src/033-the-documentation-site.lua
luajit src/034-the-companion-pages.lua
```

The first builds every document, ticket and source page into one cross-linked
site under `docs/HTML/`, and refuses to finish if a link it wrote does not
resolve. The second regenerates the `.info.md` page beside each source file out
of that file's own comments; `--check` reports what has drifted and writes
nothing.

## What to do with a set once you have one

Nothing here draws a picture. Each folder holds a recipe, and running it needs a
machine with ComfyUI and a graphics card:

1. Copy every `field.png` and `arrows.png` into that installation's `input/`
   folder, under `kanji/`, named as the workflow names them — the card says what
   each is called there.
2. Make sure the checkpoint and the control net named in `input/settings.lua` are
   in that installation's `models/` directory. The control net has to be one of
   the family that reads a grey picture as a map of light and dark.
3. Drag `workflow.ui.json` onto the canvas, or post `workflow.api.json` to the
   `/prompt` endpoint.

Every run prints those three assumptions, because nothing on this side can
check any of them.
