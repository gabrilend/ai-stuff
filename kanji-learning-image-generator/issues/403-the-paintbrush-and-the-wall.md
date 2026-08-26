# 403 — The paintbrush, and the wall around it

## Current behavior

Every scene is worked out automatically. When one comes out wrong there is
nothing to do about it except change the rules that produced it, which changes
every other character too.

## Intended behavior

**A person can write a better argument for one character, and it wins.**

From `notes/041`: *supply them with better arguments as we please*. This is the
mechanism for that sentence, and it is the difference between a generator and a
dictionary somebody is building.

```lua
-- input/arguments/時.lua
return {
  world = "sky",
  subjects = {
    { "日", "the sun, low and huge" },
    { "寺", "a temple with a bronze bell" },
  },
  strokes = { [1] = "the temple's roofline" },
  note = "sun over temple. the temple is only there for the sound.",
}
```

**The vocabulary is closed and published.** `docs/042` has the table. A closed
list of legal words is not a convenience — it is the only defence against
plausible invention. Given a long reference describing everything a scene can
hold, anybody writing quickly will reach for a neighbouring word that does not
exist, confidently and in good style. A short allowlist has nowhere for the
analogy to go.

**The language is the parser.** An argument is Lua returning a table, so a
syntax error arrives with a line number for free and there is no parser here to
write or to be wrong. The wall checks vocabulary, not syntax.

**The wall is a wall, not a net:**

- every error names the field, says what was wrong, and says where
- every error offers the nearest legal word, which is computable because the
  vocabulary is small and closed, and is almost certainly what was meant
- all errors are reported together in one pass, because stopping at the first
  turns fixing an argument into one guess per run
- a malformed field is an error, always; an **absent optional** field takes a
  default that is written in the published contract. A default that exists only
  in code is a fallback, and this project treats a fallback as a warning and a
  warning as an error.

**An argument may say as little as it likes.** Overriding the world and nothing
else is the commonest case — the automatic scene was fine except that it put the
character in the wrong place. Everything unstated stays as the grammar worked it
out.

**A rendering records which argument produced it, and the paintbrush version.**
Without the version a tier means nothing later: a vocabulary that has since
changed produces scenes that cannot be compared with new ones.

## Suggested implementation steps

1. **Extract the vocabulary from what exists.** Do not design it. Every word in
   the table is already a field on a scene; the contract publishes that shape
   and the wall enforces it.

2. **The nearest legal word is edit distance**, over a list short enough that
   comparing against all of it costs nothing.

3. **Check against the character, not just against the vocabulary.** Naming a
   piece the character does not contain is the mistake somebody will actually
   make — the record says which pieces it has, so the wall can say *時 has no
   piece 土; did you mean 寺?*

4. **Test the wall by feeding it wrong arguments**, one per kind of wrong, and
   asserting that each error names its field and offers a suggestion. A wall
   nobody has walked into is a wall nobody has measured.

## Related

`docs/042` — the contract. `024` — what an argument overrides.
