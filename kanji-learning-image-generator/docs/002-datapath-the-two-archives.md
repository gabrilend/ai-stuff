# 002 — Datapath: the two archives

Everything this project knows about kanji, it reads out of two files that other
people maintain. Nothing is typed in by hand and nothing is scraped. This
document says what is in each file, what shape it arrives in, and what comes out
the other side.

## The archives

**KanjiVG** — the strokes. Published by the KanjiVG project. One XML file holding
several thousand characters, each one a nested tree of groups and paths.

**KANJIDIC2** — the words. Published by the Electronic Dictionary Research and
Development Group. One XML file holding rather more characters than KanjiVG has
drawings for, each one a dictionary entry.

Both are fetched by `src/010-fetch-the-archives.lua`, decompressed into
`assets/`, and gitignored. They are somebody else's work, they are versioned
where they live, and they are 29 MB. Run the fetcher; do not commit them. The
fetcher reports the release it took and writes it to `assets/archive-provenance.txt`,
so a set of images can always be traced back to the exact dictionary that
described them.

## What KanjiVG gives, and its shape

A character in KanjiVG looks like this, and the shape of it is the whole reason
this project is possible:

```xml
<kanji id="kvg:kanji_04f11">
<g id="kvg:04f11" kvg:element="休">
  <g id="kvg:04f11-g1" kvg:element="人" kvg:variant="true" kvg:position="left" kvg:radical="general">
    <path id="kvg:04f11-s1" kvg:type="㇒" d="M35.75,17.75c..."/>
    <path id="kvg:04f11-s2" kvg:type="㇑" d="M25.13,32.25c..."/>
  </g>
  <g id="kvg:04f11-g2" kvg:element="木" kvg:position="right">
    <path id="kvg:04f11-s3" kvg:type="㇐" d="M39.5,42.75c..."/>
    ...
  </g>
</g>
</kanji>
```

Four separate facts are in there and this project uses all four.

**The paths, in stroke order.** Every `<path>` is one brush stroke, and they
appear in the order a hand writes them. Document order *is* stroke order — no
sorting, no numbering to reconcile. The `d` attribute is an ordinary SVG path in
a 109-by-109 coordinate box with the origin at the top left.

**The decomposition.** The nested `<g>` elements say what the character is built
out of. 休 is not six strokes; it is 人 and 木, and it is the machine's job to
know that a person and a tree are in this picture. This is the single most
valuable thing in the archive and the reason the scene grammar in `docs/004` can
be etymological rather than guessed.

**Where each piece sits.** `kvg:position` carries *left*, *right*, *top*,
*bottom*, *kamae* (enclosing), *tare* (hanging over from the top left), *nyo*
(running underneath from the bottom left). A group's actual bounding box is
computed from the paths inside it, which is more precise than the label, but the
label says what the box *means*.

**Which piece is only a sound.** `kvg:phon` marks a component that was chosen for
its pronunciation rather than its meaning. In a phono-semantic compound — and
most kanji are phono-semantic compounds — one half tells you what the character
is about and the other half tells you how to say it. A scene that paints both
halves as subjects paints one thing that has nothing to do with the meaning.
`docs/004` demotes phonetic components to landscape for exactly this reason.

There is also `kvg:type`, the calligraphic class of each stroke: ㇐ horizontal,
㇑ vertical, ㇒ falling-left, ㇔ dot, ㇏ falling-right, ㇆ horizontal-with-hook,
and so on, with `a`/`b`/`c` suffixes for variants and a slash for genuinely
ambiguous strokes. Geometry can measure most of this for itself; what geometry
reads badly is **hooks**, because a hook is a small terminal flick that barely
moves the endpoint. The class is consulted there. Run
`luajit src/020-test-the-ink.lua --stroke-classes` for the counts actually
present in the archive on disk.

## What KANJIDIC2 gives, and its shape

```xml
<character>
<literal>木</literal>
<radical><rad_value rad_type="classical">75</rad_value></radical>
<misc>
  <grade>1</grade><stroke_count>4</stroke_count><freq>317</freq><jlpt>4</jlpt>
</misc>
<reading_meaning><rmgroup>
  <reading r_type="ja_on">ボク</reading>
  <reading r_type="ja_kun">き</reading>
  <meaning>tree</meaning>
  <meaning>wood</meaning>
</rmgroup></reading_meaning>
</character>
```

Taken: the character itself, its English meanings in dictionary order, its
Japanese readings split into *on* (borrowed from Chinese) and *kun* (native), its
classical radical number, its stroke count, its school grade, its JLPT level, and
its frequency rank in newspapers.

Ignored: every `dic_ref`, every `q_code`, and every non-English meaning. Those are
for finding a character in a specific paper dictionary, and nothing here is
looking anything up in a paper dictionary.

Two of the fields are load-bearing beyond the obvious:

- **`meaning` order is not arbitrary.** The first gloss is the primary sense.
  The scene grammar weights it accordingly rather than treating the list as a bag.
- **`freq` and `grade` are the selection handles.** "Generate the first two
  hundred a schoolchild learns" and "generate everything in JLPT N5" are the
  queries people actually want, and both are one field away.

## The join, and what falls out of it

`src/019-the-kanji-record.lua` puts the two together on the character itself and
produces one **kanji record**, which is the only shape the rest of the project
ever sees:

| Field | Type | From |
|---|---|---|
| `character` | string, one UTF-8 kanji | both (the join key) |
| `codepoint` | number | KanjiVG's id |
| `strokes` | array of stroke tables, in writing order | KanjiVG |
| `strokes[i].d` | string, the raw SVG path | KanjiVG |
| `strokes[i].class` | string, the calligraphic class, or nil | KanjiVG `kvg:type` |
| `strokes[i].component` | string, the component this stroke belongs to | KanjiVG group tree |
| `components` | array of component tables, outermost first | KanjiVG group tree |
| `components[i].element` | string, one UTF-8 character | KanjiVG `kvg:element` |
| `components[i].position` | string or nil — left, right, top, bottom, kamae, tare, nyo | KanjiVG `kvg:position` |
| `components[i].phonetic` | boolean | KanjiVG `kvg:phon` present |
| `components[i].stroke_first`, `.stroke_last` | numbers, an index range into `strokes` | computed |
| `meanings` | array of English strings, primary first | KANJIDIC2 |
| `readings_on`, `readings_kun` | arrays of strings | KANJIDIC2 |
| `grade`, `jlpt`, `frequency`, `stroke_count` | numbers or nil | KANJIDIC2 |
| `radical` | number, the classical radical | KANJIDIC2 |

**The join is not total, and the gap is not an error.** A character with meanings
and no strokes cannot be made into a picture; one with strokes and no meanings has
nothing to be a picture *of*. Both are dropped, both are counted, and the smaller
lists are named outright — a silently shrinking set is how you end up wondering
where a character went.

The leftovers are sorted into three kinds, and keeping them apart is the
difference between a useful report and an alarming one:

- **Not kanji at all.** The stroke archive also draws the Latin alphabet, the
  digits, punctuation and both syllabaries — reasonably, since it is an archive
  about how to write things. None appear in a kanji dictionary. This is the
  largest of the three leftovers by a wide margin and it is not a gap in anything.
- **A kanji the dictionary does not gloss.** The real gap, and it is tiny — a
  handful of rare and archaic forms.
- **The compatibility block.** Characters given a second number so that older
  Korean text survives a round trip through Unicode. The dictionary lists them
  under their ordinary number, so these carry no gloss of their own. **This
  project cannot say which ordinary character each one pairs with**: the pairing
  lives in Unicode's character database and in neither archive here. Two attempts
  to derive it are recorded in `src/019` and both were wrong.

Run `luajit src/019-the-kanji-record.lua --report` for the counts and the lists as
they stand against the archives on disk.

**`stroke_count` is checked, not trusted.** KANJIDIC2 states a number and KanjiVG
supplies a list; where they disagree, the archives disagree about the character
and the record is flagged rather than quietly preferring one. This has caught
real variant-form mismatches and it is cheap.
