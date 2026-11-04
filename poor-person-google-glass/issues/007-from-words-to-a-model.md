# 007 — From words to a model

**Phase:** 0 — Tools
**Blocked by:** 001, 004
**Blocks:** 006
**Related documents:** docs/datapath-words-to-model.md, docs/shape-words.md

## Current Behavior
All five pieces are built and tested (see the sub-issues, completed), with
four example descriptions in input/descriptions/ and the phase 0 demo
running them. Waiting on the open questions below.

## Intended Behavior
A description of an object in English, made only of relationships and no
measurements, becomes a 3D model. The owner's examples: "twice as large as
the [blank], proportionally scaled to the [other thing], aligned with the
rotational axis of the cylinder shaped thing". The English is a **closed
vocabulary**: a published list of words and sentence shapes
(docs/shape-words.md), read by a strict reader that refuses what it cannot
read, all at once, each refusal naming its line and the nearest word it does
know. Nothing measured goes in; everything comes out measured in units where
a part with no size sentence is 1 wide, so the model is a set of
proportions that a later step can scale to millimetres.

The work splits into five pieces, built level with each other (the datapath
document first, then each piece one level deeper at a time):

| ID | Name | Dependencies | Description |
|---|---|---|---|
| 007a | the-shape-words | None | the vocabulary: document and table, kept equal by a test |
| 007b | reading-a-description | 007a | sentences into statements; the wall |
| 007c | solving-the-relations | 007b | statements into sizes, axes and centres |
| 007d | building-the-solids | 007c | solved parts into a shape record (001) |
| 007e | the-describe-script | 007d | file in, glTF and a report out, optionally viewed |

Order: 007a → 007b → 007c → 007d → 007e.

## Suggested Implementation Steps
1. docs/datapath-words-to-model.md as pass zero: every piece named.
2. The five sub-issues.
3. Example descriptions in input/descriptions/, including the crown.

## Open questions
1. Free English (any wording) needs a language model in front, rewriting it
   into the closed vocabulary. This machine reaches only an OpenAI key (no
   Anthropic key, no local model server). Wanted, and with which model?
2. A part's axis can run up, left to right or front to back, never the
   other way, so a cone cannot point down. Add "points down" and its kin?
