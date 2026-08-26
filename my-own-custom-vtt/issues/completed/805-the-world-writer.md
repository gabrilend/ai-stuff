# 805 -- The world writer

**Phase:** 8, content generation
**Blocked by:** [804](804-furnishing-asks-the-ruleset.md)
**Blocks:** [807](807-the-phase-eight-demo.md)
**Documents:** [content is generated](../docs/013-content-is-generated.md)

## Current behaviour

`035-worldfile` writes worlds already, versioned and byte-identical on a round
trip. It was built in phase 1 for a different reason.

## Intended behaviour

Almost nothing. **The writer already exists**, and this issue is mostly about
noticing that.

What it needs is the thin part around it: a program that takes a description and
a seed, runs the four stages, and writes a world file.

```
generate <description> <seed> <output>
```

### And the part that is genuinely new

**The description and the seed go into the file's header**, so a world can say
where it came from.

That turns a world file from a blob into something with provenance. Somebody
handed a dungeon can ask what description made it, change one line, and
regenerate — which is the difference between a map you can edit and a map you can
only replace.

It also means the round-trip test gets sharper: generate, write, read,
regenerate from the recorded description and seed, and compare. If those differ,
either the generator is not deterministic or the header is lying.

## Suggested implementation steps

1. Write the command-line program.
2. Add the description name and seed to the world file header, and bump the
   format version — the machinery for that has been there since phase 1 and this
   is the first time anything uses it.
3. Write the converter from version 1 to version 2. **The first rung of a ladder
   that was built empty on purpose**, and the moment it stops being theoretical.
4. Report what was generated: rooms, corridors, things, and the time it took.
5. Test the sharper round trip described above.
