# 806 - Registering with the patch system

| | |
|---|---|
| Phase | 8 - emission to the server |
| Blocked by | 803, 804 |
| Blocks | nothing; this is the capstone of the phase |

## Current behaviour

Emitted patches would be files nothing runs.

## Intended behaviour

A generated patch is only useful once the target project's pipeline knows about
it. That project keeps a registry of patches organised by application time, and
a patch not in it is inert.

This issue is where the two projects actually meet, so it is also where the
seam is defined precisely enough that neither project has to know much about the
other:

- **This project produces**: patch files in the documented form, plus a manifest
  stating each one's tier, its number, its description, whether it can run in
  parallel with others, and which change set it came from.
- **The other project consumes**: the files into its patches directory and the
  manifest into its registry.
- **Neither reaches into the other.** This project does not edit the server
  project's files, and the server project does not reach into the archive. The
  manifest is the entire interface.

Numbering is the one thing that cannot be decided locally, because numbers must
not collide with the patches that project wrote by hand. The generated ones take
a reserved range, declared in the manifest, so that a hand-written patch and a
generated one can never land on the same number.

Generated patches are also marked as generated, in the file itself. Someone
reading that project's patches directory in two years must be able to tell at a
glance which files are hand-reasoned and which were derived from an archive,
because the right way to fix them differs completely: one is edited, the other
is regenerated, and editing a generated file is work that disappears at the next
emission.

## Suggested implementation steps

1. Write the manifest format, and make it the only thing the other project reads
   from this one.
2. Reserve the number range and record the reservation in both projects'
   documentation, since a reservation only one side knows about is not a
   reservation.
3. Put a generated-file marker in a fixed place in every emitted patch, and a
   check in this project that refuses to emit without it.
4. Demonstrate the whole path end to end: choose a build, compute a change set
   against a real server, view it, emit, register, apply, confirm the values
   moved, unapply, confirm everything returned. That demonstration is phase
   eight's demo.
