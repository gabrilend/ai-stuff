# 102 — Reading a shape out of XML

## Current behavior

Two large XML files sit in `assets/` and nothing can read them.

## Intended behavior

**One kanji record, joined out of both archives, and the only shape the rest of
the project ever sees.** Its fields are tabulated in `docs/002` and that table is
the contract.

Three pieces, and they are separate on purpose: a scanner that knows XML and
nothing else, two readers that know their own archive and nothing else, and a
store that knows how to join and select and knows nothing about XML at all.

**The scanner is a pull scanner, not a tree builder.** Twenty-nine megabytes of
XML built into a document tree is a large amount of garbage for a question as
simple as *what are this character's strokes*. It walks the text emitting
open-tag, close-tag and text events, and the readers assemble only what they want.

**The readers keep the nesting, because the nesting is the etymology.** KanjiVG's
group tree says 休 is 人 beside 木 (`docs/002`), and flattening it to a stroke
list throws away the single most valuable fact in the archive. The reader keeps
a component list with, for each one, the range of stroke indices it owns.

**The join is checked and its gaps are named.** KANJIDIC2 describes more
characters than KanjiVG draws. Characters missing from either side are dropped,
counted, and listed on request — a set that silently shrinks is a set nobody
notices has shrunk. Where the two archives disagree about a stroke count, the
record is flagged rather than one archive being quietly preferred.

**Selection is part of the store.** The queries people want are *the first two
hundred a schoolchild learns*, *everything in JLPT N5*, *these particular
characters*, and *all of them*. Grade, JLPT level and frequency rank are already
in the record; selection is a filter and a sort over them, expressed as a
dispatch table of named selectors rather than a chain of tests.

## Suggested implementation steps

1. **`src/011-scan-xml.lua`** — the scanner. Open tag with attributes, close tag,
   self-closing tag, text. Handles the five XML entities and numeric character
   references. Does not handle namespaces as namespaces: `kvg:element` is an
   attribute whose name contains a colon, which is all this project needs it to be.

2. **`src/012-read-the-strokes.lua`** — KanjiVG. Walks `<kanji>` blocks, keeps a
   stack of the `<g>` elements, and for each `<path>` records the raw `d`, the
   calligraphic class from `kvg:type`, and the innermost enclosing group that
   names an element. Emits strokes in document order because document order is
   stroke order.

3. **`src/013-read-the-meanings.lua`** — KANJIDIC2. Walks `<character>` blocks
   and takes only the fields in `docs/002`. English meanings only; the `m_lang`
   attribute marks the others.

4. **`src/019-the-kanji-record.lua`** — the store. Loads both, joins on the
   character, computes each component's stroke range and bounding box, reports the
   gaps, and offers the selectors.

   It is slow to build — two archives, thirteen thousand entries — so it caches
   the joined result. The cache goes in `tmp/shared-memory/`, which is RAM, and is
   keyed by the size and modification time of both archives so an archive that
   changed invalidates it without anybody having to remember.

## Related

`docs/002` — the archives and the record's field table. `101` — where the
archives come from.
