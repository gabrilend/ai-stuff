# 801 -- A description is validated first

**Phase:** 8, content generation
**Blocked by:** phase 7 complete.
**Blocks:** [802](802-the-layout-is-a-graph.md)
**Documents:** [content is generated](../docs/013-content-is-generated.md)
**Open questions:** [8.1](../docs/016-open-questions.md) — what the description
language looks like.

## Current behaviour

`037-fixture` builds one hard-coded world. Nothing reads a description.

## Intended behaviour

A **description** — a small declarative file saying what kind of place this is,
how big, and how connected — and a wall in front of it.

### The wall, not a net

A net catches some things and shrugs the rest through.

- **Every error names the entry, the field, and what was wrong.** "Invalid input"
  is not an error message, it is an apology.
- **Every error carries the nearest legal word.** The vocabulary is small and
  closed, so edit distance is computable and one of the legal words is almost
  certainly what was meant.
- **All errors are reported together, in one pass.** Stopping at the first turns
  fixing a description into one guess per run.
- **Nothing is quietly filled in.** A malformed field is an error, always. An
  *absent optional* field taking a documented default is a different thing — that
  is vocabulary. A default that appears only in code is a fallback, and a
  fallback is a warning, and a warning is an error.

### The vocabulary is closed, and that is the point

A description may use a fixed set of words and no others. Not because
completeness is unachievable, but because **anything generating descriptions will
invent plausible neighbouring words that do not exist**, confidently and in good
style. That is true of a person working fast and much truer of a language model.
A short allowlist has nowhere for the analogy to go.

### The parser is sixty lines of C, and it was nearly Lua

The first version of this issue said Lua should be the parser: the host already
embeds it, a description could be a Lua table, and syntax errors with line
numbers come free.

**That was reconsidered while building it**, for a reason that only appeared in
phase 7. Lua's only number type is a double, so any module touching the Lua API
carries floating-point instructions and needs an exemption from the build's
floating-point check. `073-rules` has one, by name and with a paragraph. A second
exemption for a second module is how a ban stops being a ban.

And what Lua buys is expressiveness, which a **closed vocabulary of scalar fields
does not want**. A description is data, not a program -- unlike a ruleset, which
genuinely needs closures and tables and is worth the exemption.

So: a line-based `key = value` reader, in C, with no floating point and no
dependency. The vocabulary being closed means there is nothing to parse that a
line split cannot handle.

The cost is that the error messages have to be written by hand rather than
inherited -- and given that this file is largely about error messages being good,
they were going to be written by hand anyway.

## Suggested implementation steps

1. Define the vocabulary as a table of field names, types, and bounds — **one
   place**, from which both the checker and the documentation are derived.
2. Read the file line by line, splitting on the first equals sign.
3. Check every field, collecting all failures.
4. Report them together, each with the nearest legal word.
5. Write the companion `.info.md`, listing the vocabulary. That listing is the
   contract.
6. Test: a good description; one bad field; six bad fields reported at once; a
   misspelled word getting the right suggestion; an absent optional taking its
   documented default; a malformed one being refused rather than defaulted.
