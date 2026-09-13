# 804 - Emitting source patches

| | |
|---|---|
| Phase | 8 - emission to the server |
| Blocked by | 801, 802 |
| Blocks | nothing |

## Current behaviour

Nothing is emitted.

## Intended behaviour

Some behaviour is not a value in a database. It is written into the emulator's
source code - how a coefficient is combined, how an aura stacks, what happens
when two effects overlap. Changing those requires patching source before it
compiles, which is the target project's first application tier.

This is a much smaller and much more dangerous category than the database work,
and the issue exists partly to say where its boundary is.

**In scope**: a numeric constant in the source that the archive has a
patch-versioned value for, where the change is a substitution and the
surrounding logic is untouched.

**Out of scope**: anything requiring new logic. If the archive says an ability
gained a behaviour the emulator has no concept of, that is not an emission - it
is a feature, and it belongs in the target project as ordinary hand-written work
with its own issue. Generating logic from an archive is how a patch system
acquires patches nobody can read.

The generated form matches the first tier's conventions: apply and unapply in
matched vim-folded functions, idempotent, operating on the cloned source tree
which that project treats as a build artefact and reverts to pristine after
every build.

The revert requirement is stricter here than for database work. That project's
rule is that any modification surviving across builds is a bug, so an emitted
source patch that fails to unapply cleanly does not merely leave a mess - it
silently changes what the next build compiles.

## Suggested implementation steps

1. Keep a mapping from archive field to source location, and treat a mapping
   that no longer matches the source as an error rather than a skip. Upstream
   moves, and a substitution that silently matches nothing is the worst outcome
   available.
2. Match on enough surrounding context that the substitution cannot land in the
   wrong place, and refuse when the match is not unique.
3. Unapply by restoring the recorded original text, not by substituting
   backwards. Backwards substitution fails when the forward one was partial.
4. Test the pristine-tree property directly: apply every emitted source patch,
   unapply them all, and confirm the tree differs from upstream in no byte.
