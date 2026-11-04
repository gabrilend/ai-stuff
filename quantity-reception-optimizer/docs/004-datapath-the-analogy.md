# 004 — Datapath: the analogy

How a quantity record and a weighted paragraph become an **analogy**: which
thing to draw, how many of it, and what to say.

```
quantity record + weighted paragraph + kinds already shown for this hover
  ├─ measured quantity:
  │    └─ reference catalogue: every object of the same dimension
  │         └─ drop objects whose kind was already shown
  │              └─ for each: count = si_value / object's si_value
  │                   └─ keep the drawable ones (1 up to the layout's ceiling)
  └─ bare count: no candidates; the model will name the object
       └─ language model (in ComfyUI, or on the reader's machine)
            picks one, or names one; resolves an ambiguous reading;
            writes the sentence and the setting
                 └─ analogy record
```

## The division of labour

The arithmetic is done in Lua, before the model is asked anything. The model
receives candidates that are already correct — "11.2 sacks of flour", "1.6
horses pulling", "0.8 small cars" — and chooses among them using the paragraph.
A language model asked to work out how many 25 kg sacks make 280 kg will
sometimes say twelve. A language model asked whether a sentence about a bakery
suits flour sacks or horses will not get that wrong.

**Bare counts are the exception the owner asked for**: for `55` or `99` the
model chooses *what* to draw — "55 crocodiles", "99 marbles" — and the number
stays exactly the one on the page. If the page already said what is counted
(`55 crocodiles`), the model is told to draw that.

## Where the model runs

A setting with two routes, both built and both tested:

- **`comfyui`** (preferred) — a small graph on the ComfyUI server: a language
  model loaded through `CLIPLoader`, the core `TextGenerate` node, and
  `PreviewAny` to hand the text back through the server's history. Needs a
  text-writing model installed on the server; as of 2026-10-04 it has only a T5
  encoder, which cannot write.
- **`local`** — an HTTP language-model server on the reader's machine; only the
  finished scene goes to ComfyUI.

The host never switches route on its own. An unreachable route is an error
naming it.

## The reference catalogue

A data file. One entry per reference object.

| Field | Type | Meaning |
|---|---|---|
| `name` | string | `sack of flour (25 kg)`. |
| `kind` | string | Its family: `food`, `animals`, `vehicles`… |
| `dimension` | string | Same vocabulary as the unit lexicon. |
| `si_value` | number | Its amount in that dimension, in SI. |
| `picture_phrase` | string | How to ask an image generator for one: `a white paper sack of flour, printed label`. |
| `packing` | string | `grid` or `hex`: how many of them sit together in the layout. |
| `footprint_aspect` | number | Width ÷ height of one, as seen in the picture. |
| `source` | string | Where the number came from, so it can be checked. |

An object may appear more than once under different dimensions (a horse has a
mass and a pulling force).

## How the context policy reaches the model

The weighted paragraph is not sent as raw numbers. Words above a threshold are
sent in full; words below it are elided to `…`. Under *encouraged* most of the
paragraph survives; under *discouraged* only the sentence holding the quantity
does, and the model is told to choose the plainest candidate rather than the
most fitting one.

## The analogy record

| Field | Type | Meaning |
|---|---|---|
| `object_name` | string | Chosen from the catalogue, or named by the model for a bare count. |
| `kind` | string | The object's kind, recorded so a re-roll can avoid it. |
| `count` | number | Computed by the host, never by the model. May be fractional. |
| `packing`, `footprint_aspect` | string, number | From the catalogue, or from the model for a bare count. |
| `sentence` | string | One line for the reader: "About eleven sacks of flour like these." |
| `setting` | string | The background the model chose: "on a bakery floor". |

The picture's cells and their per-cell prompts are built from this record by
[the picture datapath](005-datapath-the-picture.md).

## The re-roll

A middle-click on the quantity or its panel. The host remembers, per hover, the
list of kinds already shown. A re-roll runs the same datapath with that list
one longer. When every kind with a drawable count has been shown, the host
says so to the panel instead of repeating one.
