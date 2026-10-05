# 415 — A kitchen in another house

## Current behavior

**Done, and pictures exist** — 休 drawn at `192.168.0.88` on 2026-10-04 by
Juggernaut XL at 1024, through both routes of `416`, in about 35 seconds a
character.

- **`--kitchen across`** lays the `kitchens.across` block of
  `input/settings.lua` over the kitchen, workflow and field sections — a copy,
  never the shared table. An unknown name is an error listing the known ones,
  never a quiet return to the local kitchen (`044.for_kitchen`).
- **Inputs are uploaded**, to the program's `/upload/image` with overwrite on,
  and the filename it answers with is checked against the one the recipe uses
  (`044.upload`). The copy into a local folder is retired, and the
  `kitchen.input` setting with it: the local kitchen is the same program and
  takes uploads the same way.
- **Before the first picture of each route, the far end is asked what it has.**
  The recipe's own box types and model names are read out of it
  (`044.wanted_by`) and compared with `/object_info` and `/models/<folder>`;
  every absence is named at once and the run says nothing was installed
  (`044.inventory`). Asked once per route per run.
- **The far card's memory** comes from its own `/system_stats` (`044.card` with
  a kitchen whose `here` is false). Whether it also draws a screen cannot be
  asked from here, so the kitchen declares it (`shares_a_screen = true`, the
  kinder assumption) and the run says that it is assumed.
- **A far kitchen that is silent** is reported as started by its owner — not
  with the command for starting the local one.
- **The pool records `route`, `drawn_by` and `checkpoint`**, and the first two
  are in the picture's name, added only when they are not the original (local
  kitchen, illusion route), so every name already in the pool still means what
  it meant (`045.stem`).
- **Tested** in `035` under *another kitchen*: the overlay, inheritance, the
  refusal of an unknown name, the declared screen, and reading a recipe's needs.

### What was there to begin with

There is a second ComfyUI at `192.168.0.88:8188`, on a machine that belongs to
someone else. Asked on 2026-10-04 what it holds (its `/object_info` and
`/models/*` endpoints, read-only):

| | there? |
|---|---|
| checkpoints | Chroma1-HD, NetaYume v4, Juggernaut XL (Ragnarok), three waiIllustrious SDXL |
| SD 1.5 and the QR-monster control net this project's illusion route uses | **no** — the control-net folder is empty |
| core masking nodes — `ImageToMask`, `InvertMask`, `GrowMask`, `FeatherMask`, `ConditioningSetMask`, `ConditioningCombine`, `SetLatentNoiseMask`, `VAEEncodeForInpaint`, `InpaintModelConditioning`, `DifferentialDiffusion`, `ImageCompositeMasked` | yes, all |
| style models, CLIP-vision models | none |

So the existing illusion route cannot run there. The two mask routes of `416`
can, with nothing installed.

## Intended behavior

**Nothing is installed on that machine without its owner's consent.** The
project works with what the far kitchen has, and when it lacks something, the
run says what and stops — it never fetches, downloads or copies a model there.

**A kitchen is an address, and the submitter does not care which house it is
in.** The same run can be pointed at the local kitchen or the far one by one
setting, and nothing else in the pipeline changes.

**The far kitchen draws with Juggernaut XL or Chroma.** Juggernaut XL is an SDXL
model and composes at 1024; Chroma is a Flux-family model with its own sampler
habits. Which one is a setting per kitchen, and both get tried; the waiIllustrious
models are not used.

**Inputs travel by upload, not by copy.** ComfyUI accepts a picture posted to its
`/upload/image` endpoint and answers with the name it filed it under; the recipe
names that. If upload works against the local kitchen too (it is the same
program), the copy is retired so there is one route rather than two.

**Before posting anything, ask the kitchen what it has.** The run reads the far
end's model lists and node catalogue once, compares them against what the recipe
names, and refuses with a list of every missing part — all at once, not the first
one. This is `404`'s *ask the thing, do not reason about it* applied to a machine
this project did not install.

**Which machine and which checkpoint made a picture is recorded in the pool**,
beside the style and the seed. The same recipe on a different checkpoint is a
different picture, and `406`'s agreement numbers mean nothing if the two mix.

## Suggested implementation steps

1. **A list of kitchens in `input/settings.lua`**, each with its address, its
   checkpoint, its frame size (`414`: SDXL at 1024, and every pixel number
   already scales with that), and whether it shares a card with a desktop (the
   `409` rest times become per kitchen). `--kitchen <name>` on the command line.
2. **Upload instead of copy** in `044`. Multipart POST to `/upload/image`; the
   reply's filename goes into the `LoadImage` node.
3. **The inventory check** — one pass over `/object_info` and the model lists,
   compared against the recipe; every absence named.
4. **Free memory asked of the far end** (`/system_stats` reports its device
   memory), or the run says it cannot know — never assumes.
5. **The pool record gains kitchen and checkpoint** (`045`).
6. **Tests in `035`**: an inventory lacking two parts is refused naming both; an
   upload reply's filename is the one the recipe carries.

## Related

`404` — the submitter and the local kitchen. `409` — rest times on a shared card.
`414` — why frame size is not a free choice. `416` — the two routes that need no
control net and so can run here first.
