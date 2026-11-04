# 003 — Datapath: the quantity

How a run of characters like `1,234.5 kg` — or a bare `55` — becomes a
**quantity record**.

```
paragraph text + the word under the pointer
  └─ scan outward from that word for a number, and a unit beside it if any
       └─ read the number   (separators, decimals, signs, ranges, "1.2 million")
            └─ read the unit (look it up in the unit lexicon; longest match wins)
                 │    no unit: dimension "count", and the next word kept as
                 │    the counted noun if there is one ("55 crocodiles")
                 └─ quantity record
                      └─ convert the value into SI using the lexicon's factor
```

The scanner starts at the pointer's word rather than reading the whole
paragraph, because the reader asked about *this* quantity. A paragraph with six
quantities in it produces one record, for the one under the pointer. The other
five are still visible to the reasoning as words in the weighted paragraph.

If the word under the pointer is not part of a number, or is a number that is
not an amount (a year, a page number, a date, a phone number, a version
string), the host answers "no quantity here" and nothing else happens. That is
an answer, not a fallback: most words are not quantities.

## The unit lexicon

A data file, read once when the host starts. One entry per unit.

| Field | Type | Meaning |
|---|---|---|
| `spellings` | list of strings | Every way it is written: `kg`, `kilogram`, `kilograms`, `kilo`. Matched case-sensitively where case matters (`Mm` is megametres, `mm` millimetres) and insensitively for words. |
| `dimension` | string | What it measures: `mass`, `length`, `area`, `volume`, `force`, `energy`, `power`, `time`, `speed`, `pressure`, `temperature` — or `count`, for bare numbers, which has no spellings and a factor of 1. |
| `to_si_factor` | number | Multiply by this to reach the SI base unit for the dimension. |
| `to_si_offset` | number | Added after the factor. Zero for every unit but temperatures. |

Area and volume units are frequently written without the superscript — `15 m2`,
`3 m3`, `ft2`, `sq ft`. All of these are spellings in the lexicon; nothing
parses exponents.

## The quantity record

| Field | Type | Meaning |
|---|---|---|
| `source_text` | string | Exactly the characters that were read, e.g. `1,234.5 kg`. |
| `char_start`, `char_end` | integers | Where they sit in `paragraph_text`. |
| `value` | number | The number as written, `1234.5`. |
| `value_high` | number or absent | For a range (`10–15 kg`), the upper end; `value` is then the lower. |
| `ambiguous` | boolean | True when the separators allow two readings and the page's language does not settle it. |
| `value_other_reading` | number or absent | When `ambiguous`: the other reading (`1.234` → `1.234` and `1234`). |
| `approximate` | boolean | True after "about", "~", "roughly". |
| `unit_spelling` | string or absent | The spelling matched, `kg`. Absent for a `count`. |
| `counted_noun` | string or absent | For a `count`, the word that followed the number, if any: `crocodiles`. |
| `dimension` | string | From the lexicon, or `count`. |
| `si_value` | number | `value` converted, here `1234.5` (kilograms already are SI). |

## Ambiguous separators

`1.234 kg` is one-and-a-bit kilograms in English and twelve hundred and
thirty-four in German. When the page declares its language, that decides.
When it does not, the record carries both readings and the language model
chooses the one the paragraph supports
([the analogy datapath](004-datapath-the-analogy.md)) — the owner's call: leave
it to the model's judgement.
