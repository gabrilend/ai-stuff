# 005 — Datapath: the workflow

The deliverable. Everything upstream produces a field, a prompt and an overlay;
this turns those into the file you hand to ComfyUI.

## The two formats, and why both are written

ComfyUI reads workflows in two different shapes and they are not
interchangeable.

**The API format** is what the `/prompt` endpoint accepts. It is a flat object
keyed by node id, and it is what a script posts when it wants pictures made
without a human present:

```json
{ "7": { "class_type": "KSampler",
         "inputs": { "seed": 41011, "steps": 24, "cfg": 6.5,
                     "sampler_name": "dpmpp_2m", "scheduler": "karras",
                     "denoise": 1.0,
                     "model": ["1", 0], "positive": ["6", 0],
                     "negative": ["6", 1], "latent_image": ["5", 0] } } }
```

A value is either a literal or a two-element array `[node_id, output_slot]`
naming where it comes from.

**The UI format** is what the canvas loads when a file is dragged onto it. It is
an explicit graph — an array of nodes carrying their own screen positions, and a
separate array of links:

```json
{ "nodes": [ { "id": 7, "type": "KSampler", "pos": [1180, 60],
               "inputs":  [ {"name":"model","type":"MODEL","link":1}, ... ],
               "outputs": [ {"name":"LATENT","type":"LATENT","links":[9]} ],
               "widgets_values": [41011, "fixed", 24, 6.5, "dpmpp_2m", "karras", 1.0] } ],
  "links": [ [1, 1, 0, 7, 0, "MODEL"], ... ] }
```

The API format cannot be opened in the editor and the UI format cannot be posted
to the endpoint. A learner wants the first thing they can see and adjust; a batch
of six thousand wants the thing a script can submit. Both are written, from one
description, by `src/028-the-shape-of-a-graph.lua`.

## The node catalogue, and the thing that makes it necessary

The two formats do not merely differ in layout — the UI format needs facts about
each node type that the API format never states:

- the **names and types of every input socket**, in slot order, because links are
  identified by slot index and a link into the wrong slot is a silently different
  graph
- the **names and types of every output socket**, same reason
- the **order of the widget values**, because `widgets_values` is a bare array
  with no keys in it and the order is the order the node draws its controls in

And one asymmetry that will bite anybody who assumes the formats are the same
data twice: **the UI format's widget list contains entries the API format has
no field for.** `KSampler` draws a control immediately after its seed — the
*fixed / increment / randomize* selector — and it occupies a slot in
`widgets_values` while corresponding to nothing in `inputs`. Emit the widget
array without it and every value after the seed is off by one: the step count
lands in the CFG scale, and the workflow loads without complaint and is wrong.

So `src/028` carries a catalogue of the node types this project uses, stating
sockets and widget order for each, with the interface-only widgets marked. It is
the one place in the project that knows ComfyUI's schema, and it knows it for
about a dozen node types rather than for all of them, which is the correct
ambition.

**It has now been checked against the real thing**, which it could not be when
it was written — `404` installs ComfyUI inside this project, so its own source
is on disk and can be read. All eleven node types exist. `ControlNetApplyAdvanced`
declares exactly the sockets the catalogue claims, plus an optional one the
catalogue correctly omits. And the trap is real and is where it was predicted:
the sampler's seed is declared with `control_after_generate` set, which is the
flag that makes the editor draw a selector after it — so the widget array really
does carry an entry the posted format has no field for, and the catalogue's
order matches the declared one exactly.

That is a check against a program rather than against a specification, and it is
worth more than everything above it.

## The graph

```
  CheckpointLoaderSimple ──MODEL──────────────────────────────┐
        │                                                     │
        ├──CLIP──┬── CLIPTextEncode (the scene) ──────┐        │
        │        └── CLIPTextEncode (the refusals) ──┐│        │
        │                                            ││        │
        └──VAE───────────────────────────────┐       ││        │
                                             │       ▼▼        │
  ControlNetLoader ──CONTROL_NET──────────► ControlNetApplyAdvanced
                                             ▲       │ │       │
  LoadImage (the structure field) ──IMAGE────┘       │ │       │
                                                     │ │       ▼
  EmptyLatentImage ──LATENT──────────────────────────┼─┼──► KSampler
                                                     │ │        │
                                              positive negative │
                                                                ▼
                                             VAEDecode ◄────LATENT
                                                  │
                                                IMAGE
                                                  │
  LoadImage (the arrows) ──IMAGE──┐               │
              └──MASK── InvertMask─┼──► ImageCompositeMasked ──► SaveImage
                                   └──────────────┘
```

Built by `src/029-the-workflow-for-one-kanji.lua`.

**The control net is applied to both conditionings.** `ControlNetApplyAdvanced`
takes the positive and the negative and returns both, which is what makes the
field a constraint on the whole sampling rather than a suggestion attached to the
prompt.

**Strength, start and end are three separate dials and they do different work.**
Strength is how hard the field pushes. Start and end are *when* in the denoising
it pushes at all, as fractions of the run. Composition is decided early and
detail late, so a field applied from the beginning and released near the end
places the strokes and then lets the model finish the scene without them. Holding
it to the last step gives a picture with the character stamped through it. These
are knobs and they live in `docs/balance-updates.md`.

**The arrow layer can be composited inside the workflow, and by default is
not.** The argument for doing it was that what lands in ComfyUI's output
directory should be the finished learning card rather than a picture that still
needs assembling. That argument lost to two things the first real run showed.
The machine grader squints at what was saved, and with the arrows in it, it is
squinting at arrows as well as at scenery. And the stroke-order animation draws
arrows onto the saved picture, so with arrows already in it every frame looks
the same. The pool holds what the model drew, unmodified; everything that wants
the arrows composites them itself.

The nodes are still here and still correct, because a run that wants a
self-contained card is a legitimate thing to ask for. One detail decides whether this works: `LoadImage`'s `MASK` output is
the **inverse** of the image's alpha — one where the PNG is transparent, zero
where it is opaque. `ImageCompositeMasked` pastes the source where the mask is
one. Wire those together directly and you paste the arrows exactly where the
arrows are not. `InvertMask` sits between them, and it is there for that reason
and no other.

The compositing stage is optional. A run that wants the plain illusion asks for
it off and the graph is emitted without those three nodes rather than with them
bypassed, because a workflow full of disabled nodes is a workflow somebody will
re-enable by accident.

## What the workflow names, and what it does not carry

The workflow refers to files by name — a checkpoint, a ControlNet, the field PNG,
the arrow PNG. It does not contain them. Model weights are not this project's to
ship and the images are beside the workflow on disk.

Which checkpoint and which ControlNet are *settings*, read from `input/` at
startup like everything else this project decides (`docs/006`). They are named as
strings because that is what ComfyUI wants, and the names have to match what is
in that installation's `models/` directory. A run therefore checks nothing about
them and cannot: this machine has no ComfyUI on it and the workflow is being
written for a machine that does. What it *can* do is state the assumption in the
run report, which it does.

## Reproducibility

The seed is derived from the character's own codepoint rather than drawn at
random, so a given character regenerates identically, and two runs of the whole
set differ only where the code changed. Batch runs of six thousand images are
otherwise impossible to compare.

The UI format is emitted with the seed control set to *fixed* for the same
reason. A workflow that arrives with *randomize* selected quietly stops being the
picture that was tested the moment a human presses the button.
