# 106 — Numbers a machine will read

## Current behavior

Done. `src/018-write-the-numbers.lua` provides the ordered table and the writer.

The ordered table is an ordinary table with a gate on assignment: values live in
a store the gate holds rather than on the object, which is what keeps the object
empty enough for the gate to keep being consulted. A key written straight onto
the object would be found by ordinary lookup afterwards and would never pass
through the gate again, so its order would be lost the moment it was updated.

All three failure modes the plan named are tested for directly, because all three
produce output that looks correct at a glance.

## Intended behavior

**A JSON writer that preserves key order**, which is why an existing one is not
being used.

A Lua table has no key order. Encoding one produces whichever order the hash
happened to land in, which means two runs of the same program emit byte-different
files, a diff between two workflows is noise, and a person opening a workflow
finds `cfg` above `class_type` above `seed` in a different arrangement each time.

For a format a human is going to read and a version control system is going to
diff, that is not acceptable, and it is not fixable by sorting — sorted keys put
`class_type` after `cfg`, which is backwards for reading.

So: an **ordered map** type. Insertion order is the emission order, keys are also
addressable by name, and it is the only structure this project's emitters build.
Arrays stay ordinary Lua arrays.

The rest is small and only needs to be exactly right about the things that are
easy to be nearly right about:

- **Escaping.** Quote, backslash, and the control characters below 0x20, which
  must become `\u00XX` and not be passed through. UTF-8 above that is emitted as
  itself, because the output is full of kanji and escaping them would make every
  file unreadable to the person it is for.
- **Numbers.** Integers must not print as `41011.0`, because ComfyUI reads a
  seed and a step count as integers and a float there is a type error at the far
  end. A number equal to its own floor and inside the range where a double
  represents integers exactly prints without a decimal point.
- **Empty tables are ambiguous.** `{}` is both an empty array and an empty object
  in Lua, and ComfyUI's format contains both — `"flags": {}` must not become
  `[]`. The ordered map settles it: an empty ordered map is an object, an empty
  array is an array, and the writer never has to guess.

Indentation is optional and on by default. The workflows are meant to be opened.

## Suggested implementation steps

1. **`src/018-write-the-numbers.lua`** — the ordered map constructor, the writer,
   and nothing else. No decoder: nothing in this project reads JSON.

2. **Test the three failure modes above specifically**, because all three produce
   output that looks correct: key order stable across runs, an integer round
   number emitting without a decimal point, and an empty object staying an object.

## Related

`docs/005` — the format this has to produce. `301` — its first real consumer.
