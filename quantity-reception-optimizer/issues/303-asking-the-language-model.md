# 303 — Asking the language model

## Current behavior

Nothing exists. Needs `102`, `105`, `301`, `302`, and for the ComfyUI route,
`204`'s client.

Checked against the server (`192.168.0.88:8188`, 2026-10-04): ComfyUI's core
has a `TextGenerate` node (a language model loaded through `CLIPLoader`, a
prompt in, text out) and a `PreviewAny` node that returns text through the
history. The only text model installed is a T5 encoder, which turns text into
numbers for image models and cannot write sentences. **So the ComfyUI route
needs a text-writing model added to the server's text-encoder folder first**
(open question 13 in `docs/008`).

## Intended behavior

**Given a quantity, the weighted paragraph, and the candidates of kinds not yet
shown, ask a language model to choose one and describe a setting; return an
analogy record.** Fields are in `docs/004-datapath-the-analogy.md`.

**Where the model runs — two routes, chosen by a setting, both built and
tested.** The owner: "run everything for this project in the comfyui system if
we can. Otherwise, we can do the language models on my side and send them as
prompts."

- **`comfyui`** — the host builds a two-node-plus graph (`CLIPLoader` →
  `TextGenerate` → `PreviewAny`) with the prompt as text, submits it with
  `204`'s client, and reads the text back from the history. The same server
  then draws the picture.
- **`local`** — the host asks a model running on the reader's own machine (an
  HTTP server such as llama.cpp's or ollama's; address and model name are
  settings), and only the resulting scene goes to ComfyUI as a prompt.

The route in use is printed in the host's log at startup. If the chosen route
cannot be reached, that is an error naming the route and address. The host
never switches routes by itself.

**What the model is sent:**

- the paragraph, with words below a weight threshold replaced by `…` (the
  threshold is a setting; the context policy from `105` has already shaped the
  weights)
- the quantity as written, its SI value — **or both readings**, when the
  separators were ambiguous (`1.234 kg`: one-and-a-bit, or twelve hundred);
  the model picks the reading the paragraph supports, as the owner asked
- the candidates, numbered, each with its already-computed count: "11.2 sacks
  of flour (25 kg each), kind: food"
- **for a bare count** (`55`, no unit), no candidates: the model names any
  everyday object it thinks suits the paragraph — "55 crocodiles", "99
  marbles" — plus its packing (`grid` or `hex`) and footprint aspect, and the
  count stays exactly the number on the page
- under *discouraged*, an instruction to prefer the plainest candidate over the
  most fitting

**What it must send back:** as JSON, the chosen candidate's number (or, for a
bare count, the object), one sentence for the reader, and a setting for the
scene ("on a bakery floor"). An answer that does not parse, or names a
candidate not on the list, is an error logged with the model's full reply and
shown in the panel. It is not retried behind the reader's back.

**The count in the sentence is the host's count**, inserted by the host. The
model is told the number; a sentence stating a different one is the same error.

The cell layout (`401`) and the picture graph (`402`) are built from the
chosen object, the count and the setting.

## Suggested implementation steps

1. `src/` — the prompt builder and the reply checker. The prompt text lives in
   a file in `assets/`, not in code.
2. `src/` — the two routes behind one call, selected by a dispatch table keyed
   on the route setting.
3. The host's `hover` handler continues past phase 1: quantity → candidates →
   model → `analogy` message.
4. Tests without a model: a stand-in that returns canned replies, including a
   malformed one, one naming a candidate not offered, one for a bare count, and
   one resolving an ambiguous reading. Run against both routes' request shapes.
5. Tests with a model, once per route: the vision's examples, by eye.

## Related

`docs/004-datapath-the-analogy.md` · `docs/008-open-questions.md` (13) · needs
`102`, `105`, `301`, `302`, `204` · blocks `304`, `305`, `402`
