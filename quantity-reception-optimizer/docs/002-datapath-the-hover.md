# 002 — Datapath: the hover

How the pointer resting on a page becomes a **hover record** and then a
**proximity spectrum**.

```
pointer enters a new word       (page, JavaScript)
       └─ find the paragraph element under the pointer
            └─ split its text into words; measure each word's box on screen
                 └─ group boxes into lines by their vertical position
                      └─ hover record ──► bridge ──► host            (Lua)
                                                     └─ proximity spectrum
                                                          └─ context policy reshapes it
                                                               └─ weighted paragraph
```

## Page side: observing only

The content script does no interpretation. There is no waiting period: the
moment the pointer enters a new word (the owner: wait "however long it takes to
generate", and no longer), it walks up from
the element under the pointer to the nearest block-level element and treats its
text as the paragraph. It uses the DOM's text ranges to measure the rectangle of
every word, because a rectangle is the only reliable way to know which *line* a
word landed on after the browser wrapped the text.

Lines are not a thing the DOM knows about. A line is recovered by grouping word
rectangles whose vertical centres fall within half a line-height of each other.

## The hover record

What crosses the bridge. Every field is a primitive or a list of primitives, so
it is plain JSON.

| Field | Type | Meaning |
|---|---|---|
| `paragraph_text` | string | The paragraph's full text, whitespace collapsed. |
| `words` | list of word | Every word, in reading order. |
| `words[i].text` | string | The word as written. |
| `words[i].char_start` | integer | Offset of its first character in `paragraph_text` (0-based, UTF-16 units, because that is what JavaScript counts). |
| `words[i].line_index` | integer | Which line it landed on, 0 at the top. |
| `words[i].box` | four numbers | Left, top, width, height in CSS pixels, relative to the viewport. |
| `pointer` | two numbers | The pointer's x and y in the same coordinates. |
| `pointer_word_index` | integer | Which word the pointer is over. A hover over whitespace is not sent at all — there is nothing to be over. |
| `page_url` | string | Where the paragraph came from, for the cache and the log. |

## Host side: the proximity spectrum

A list of numbers, the same length as `words`, each between 0 and 1.

For each word, two distances from the pointer's word are measured: how many
*lines* away it is, and how many *words along* the line (or, for other lines,
the horizontal pixel distance turned into word-widths). Each distance passes
through its own falloff curve, and the two are multiplied. Lines fall off
faster than words along a line, because a sentence is read along the line, and
the line above is often a different thought.

The **context policy** then reshapes the whole list. *Encouraged* widens both
falloffs, so more of the paragraph carries weight; *discouraged* narrows them
until little but the quantity itself remains. The falloff widths for each
policy live in the settings file, not in the code.

The output of this datapath, read by [the analogy datapath](004-datapath-the-analogy.md),
is the paragraph with each word paired to its weight.
