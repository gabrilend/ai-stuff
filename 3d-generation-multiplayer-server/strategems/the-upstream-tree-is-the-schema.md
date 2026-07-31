# strategem — the upstream tree is the schema

*Never transcribe a format you can extract from the thing that enforces it.*

A pattern that showed up three separate times in one sitting, in three
subsystems that have nothing to do with each other — which is what promoted it
from a convenience to a rule.

---

## The pattern

You need to speak a format that some other program defines: a wire protocol, a
file layout, a set of constants, an enumeration. The format is *written down
somewhere* in that program's source.

The obvious move is to read it and write your own copy. The move that does not
rot is to **extract it mechanically, at build time, from the source that
enforces it** — and to treat your copy as a generated artifact that is never
hand-edited.

```
   their source  ──▶  [extractor]  ──▶  your generated definition  ──▶  your code
        │                                          ▲
        └────── the authority ─────────────────────┘  regenerated, never edited
```

The three places it appeared here, all in one project:

- **an opcode enumeration** — fifteen hundred message numbers, of which we
  implement a few dozen. Extracted, not typed.
- **two cipher seed constants** — sixteen bytes each, where a single wrong nibble
  produces a stream that decrypts to noise with no diagnostic.
- **the layout of a hundred binary data tables** — where the loader's own format
  descriptor *is* the schema, in the strongest possible sense: it is what will
  actually be applied to our bytes.

---

## What it buys

**A transcription error becomes impossible**, because there is no transcription.
This matters most where the mistake is silent — a wrong opcode is a packet
politely ignored, a wrong constant is a stream of noise, a column miscount is
every subsequent field misread. None of those announce themselves.

**Their change breaks your build instead of your runtime.** This is the real
prize. When upstream renames a message, inserts a column, or retires a constant,
the extractor sees it and the generator has no value for it, so the *build*
stops and names the thing that moved. The alternative is a program that starts
cleanly and is wrong.

**Your subset stays honest.** You implement a fraction of what they define. When
they remove something you still handle, the generated definition shrinks and
your handler fails to compile. You learn about their amputation at build time
rather than at three in the morning.

**It is cheap.** An extractor is usually a dozen lines of `awk` over a header.
The asymmetry between that and a week spent on a silent format mismatch is the
whole argument.

---

## When it does *not* apply

Worth being precise, because over-applying this produces build systems nobody
can debug:

- **When the format is genuinely standardised and versioned.** Extracting a
  constant from someone's copy of a public specification adds a dependency and
  buys nothing.
- **When the source is not reachable at build time.** The pattern needs the
  authority present. Against a binary-only dependency there is nothing to
  extract from and the honest move is a hand-written copy *with a test that
  fails loudly against the real thing.*
- **When the definition is not machine-readable.** A constant assembled across
  three files by preprocessor arithmetic is not extractable with `awk`, and
  pretending otherwise produces an extractor more fragile than the transcription
  it replaced. Extract what is stated; do not try to evaluate their language.

The tell for "this applies" is simple: *the definition exists, in one place, in
a form a script can read, in a tree you already have.*

---

## The relationship to the other one

This is the sibling of `the-tree-is-a-build-artifact`, and they compose:

| | keeps | regenerates |
|---|---|---|
| **the tree is a build artifact** | the transformations | the modified tree |
| **the upstream tree is the schema** | the extractor | the definitions |

Both refuse to store something derivable. Both make upstream movement produce a
loud, localised failure instead of a quiet, distributed one. Run together, the
result is that *nothing in the repository is a copy of anything*, which is a
surprisingly strong position to be able to state about a project built on top of
somebody else's hundred thousand lines.

## Related

- `docs/datapath-the-world-stream.md` — the opcodes and the cipher constants
- `docs/datapath-the-fabricated-data.md` — the table layouts
- `strategems/the-tree-is-a-build-artifact.md` — the sibling
