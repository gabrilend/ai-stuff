# 101 — The units a page speaks

## Current behavior

Nothing exists. No unit is recognised.

## Intended behavior

**A data file listing every unit the reader recognises, and a small Lua module
that loads it and converts a value into SI.** The file's fields are given in
`docs/003-datapath-the-quantity.md`: spellings (list of strings), dimension
(string), factor to SI (number), offset to SI (number, zero except for
temperatures).

The lexicon is the vocabulary of the whole project. Every later stage speaks in
its dimension names — the reference catalogue (`301`) is grouped by the same
dimension strings — so the list of dimensions is fixed here and nowhere else.

It must cover, at least, the dimensions the vision names (mass, area, force)
and the ones a reader meets daily: length, volume, energy, power, time, speed,
pressure, temperature — plus `count`, the dimension of a bare number, which
has no units and an SI factor of 1. For each physical dimension, metric with its common prefixes, and the
imperial and US customary units still in use (pounds, ounces, feet, square
feet, acres, gallons, pounds-force, horsepower, psi, °F).

Spellings with dropped superscripts (`m2`, `m3`, `ft2`, `sq ft`, `cu m`) are
entries, not a parsing rule.

**Case matters for symbols and not for words.** `Mm` is megametres and `mm`
millimetres; `Kilograms` and `kilograms` are the same. Each spelling is marked
as a symbol or a word.

**Two spellings that collide are an error at load time**, naming both entries.
`m` cannot mean metres in one entry and minutes in another; `min` is minutes.

## Suggested implementation steps

1. `assets/` — the lexicon data file, as a Lua table file returned by `return
   { ... }`, so it loads with no parser and its comments can say where each
   factor came from.
2. `src/` — the lexicon module: load, build a lookup from spelling to entry,
   check for collisions, and convert value-in-unit to value-in-SI.
3. A lookup that wants "the longest spelling that matches here" — used by `102`
   — so `km/h` is not read as `km` followed by junk.
4. Tests: every entry converts one of itself to its stated factor; known
   conversions (1 lb = 0.45359237 kg, 0 °C = 273.15 K, 1 acre = 4046.8564224 m²)
   to the last digit; the collision check rejects a crafted bad file.

## Related

`docs/003-datapath-the-quantity.md` · blocks `102`, `301`
