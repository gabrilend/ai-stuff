# 302 — The workflow for one kanji

## Current behavior

A graph can be built and emitted. Nothing says what graph.

## Intended behavior

**One character in; a directory out, holding everything needed to make its
picture.**

```
output-set/<codepoint>-<character>/
    field.png            the structure field           (202)
    arrows.png           the stroke-order layer        (206)
    workflow.api.json    what a script posts           (301)
    workflow.ui.json     what a person opens           (301)
    card.json            the record, scene and prompt, for the gallery
```

This is the unit of work. `303` runs it many times and does nothing else
interesting; everything that makes a picture happen is decided here.

The graph is in `docs/005`. What this ticket adds is everything around it:

**The seed comes from the character's codepoint**, not from a clock. A given
character regenerates identically, and two runs of the whole set differ only where
the code changed. Without that, comparing six thousand images to six thousand
images is impossible and every change looks like it changed everything.

**The arrow compositing is emitted or it is not.** A run that wants the plain
illusion gets a graph without those three nodes rather than a graph with them
disabled, because a disabled node is a node somebody will re-enable by accident
and then wonder about.

**Image paths are relative to ComfyUI's input directory, not to this project.**
`LoadImage` names a file inside the installation's `input/` folder — it does not
take a path. So the emitted workflow names the file, the run report says where the
files need to be copied to, and a `--comfy-input` setting can copy them there
directly for a person who has ComfyUI on the same machine. Getting this wrong
produces a workflow that is correct and cannot find its own images, which is a
confusing failure and worth spending a paragraph on.

**Nothing about the model is verified, and the report says so.** The checkpoint
and ControlNet are named strings that must match that installation's `models/`
directory. There is no ComfyUI here to ask. Stating the assumption is the whole
of what can be done, and it is done rather than skipped.

**`card.json` exists for the gallery and for people.** The record, the chosen
biome, the subjects and their glosses, the per-stroke roles, and the final
prompts. It is what makes a generated set inspectable without opening a workflow,
and it is what `304` reads.

## Suggested implementation steps

1. **`src/029-the-workflow-for-one-kanji.lua`** — the graph.
   **`src/030-make-one-kanji.lua`** — the runnable program: takes a character,
   writes the directory. Two files because one is a library and one is a command,
   and the command is what a person debugging a single character reaches for.

2. **Write to a temporary name and rename into place.** A killed run leaves a
   half-written PNG that looks complete, and the gallery renders it as a broken
   image somebody spends an hour investigating.

3. **Test end to end on a character with known structure**, checking the directory
   holds all five files, the workflow parses, the graph contains the expected node
   types, and the field PNG has the dimensions asked for.

## Related

`docs/005` — the graph. `202`, `206`, `205`, `301` — everything it assembles.
