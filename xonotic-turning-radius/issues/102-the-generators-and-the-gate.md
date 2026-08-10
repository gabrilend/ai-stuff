# 102 — The Generators and the Gate

**Phase:** 1 — The patch machine
**Blocked by:** 101
**Blocks:** every patch written after it

## Current behavior

With the component shape defined, writing a patch is still a procedure someone
performs by hand: pick a free identifier, write the header, write the apply,
write the matching inverse, write the probe, remember to add a row to whatever
index exists, and remember to check that the inverse actually reverses.

Every one of those "remember to" steps is a latent defect. The two that hurt most
are a loose anchor that silently matches two places and edits the wrong one, and
an inverse that does not exactly reverse — which leaks phantom changes into the
*next* build, far from where they originated and long after the cause is
forgettable.

## Intended behavior

Three tools, each converting a remembered step into a mechanical one.

**A generator that stamps out a patch skeleton.** Given a tier, a short name and
a target file, it computes the next free identifier by scanning what already
exists, emits the header with its fields pre-labelled, pre-names the apply,
inverse and probe functions, and pre-fills the marker string. What is left for a
person is only the irreducible part: the actual old-to-new edit and the anchor
that locates it.

**A verifier that refuses malformed patches.** Against a freshly reset tree, for
every patch in the active selection it asserts:

- applying it changes the tree at all;
- the anchor matches exactly the number of times the header declares — zero
  means the patch was written against a version that has moved, and more than one
  means it will corrupt a site nobody looked at;
- the witness is absent before applying and present after;
- **the round trip is exact** — apply, then unapply, then ask version control
  what changed, and the answer must be nothing.

This is wired as a gate in front of the build. The guarantee is not "the author
tested it." The guarantee is that a patch failing any assertion cannot enter the
active set.

**A registry generator.** It reads the header of every patch file and rewrites
the registry document from them. The registry is a derived artifact, never edited
by hand, so it cannot drift from what the patches actually do. "Remember to
update the index" ceases to exist as a step a person can fail to take.

## Suggested implementation steps

1. Write the generator. Deriving the next identifier from existing filenames is
   what makes collisions impossible without a counter anyone has to maintain.
2. Write the verifier as four independent assertions per patch, reporting all
   failures rather than stopping at the first, so one run tells the whole truth.
3. Make the round-trip assertion the last one, since it is the only one that
   needs the tree returned to a known state afterwards.
4. Write the registry generator over the header fields.
5. Wire the verifier into the build ahead of the apply step, and into the
   contribution path as a pre-flight.

## Related documents

- `101-the-reversible-patch-component.md`, which defines the header fields these
  three tools read and write.

## Notes

The verifier and the staleness auditor read the same header fields for different
purposes: the verifier asks "is this patch well-formed against the tree we have,"
the auditor asks "is this patch still needed against a tree that has moved." That
they share an input is why the header is worth treating as a data structure
rather than as a comment.
