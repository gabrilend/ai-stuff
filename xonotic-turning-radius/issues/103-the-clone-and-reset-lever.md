# 103 — The Clone and Reset Lever

**Phase:** 1 — The patch machine
**Blocked by:** 101
**Blocks:** 501 (delivery), and every upstream update thereafter

## Current behavior

The two source trees were cloned once, by hand, with a shallow fetch. Nothing
records which upstream commit the project was last known to work against, and
nothing re-fetches. "The source is in a strange state" is currently a debugging
session rather than a command.

## Intended behavior

Three separate mechanisms, each wired to its own trigger, so that nobody ever has
to choose between them.

**Re-clone.** A lever that removes only the source trees and fetches them again,
leaving build output, installed artifacts and configuration alone. This is what
makes "the source is in a strange state" a one-line fix rather than an
investigation — and it is safe *specifically because* the real work lives in the
patch scripts and not in the tree.

**Reset.** Drives both clones back to their recorded commit. Wired as an
unconditional pre-flight at every build entry point, not as a conditional "only
if dirty" — running it always is what makes a pristine starting tree a guarantee
rather than a hope. It is the backstop for the one failure the cleanup handler
cannot catch: a signal that kills the shell outright, taking the handler with it.

**Unapply.** Reverses exactly the patches this run applied. It is wired only to
the cleanup handler and to the successful path, never to a defensive position.

The reason the last two cannot be swapped is a genuine failure mode rather than
tidiness. An unapply transformation matches the *post-patch* shape of the code.
It cannot distinguish "we put this here" from "upstream now ships this." So when
upstream eventually converges on the form we patched to — which is the normal
outcome for any good change — a defensively-run unapply silently reverts clean
upstream code, manufacturing modifications that read like upstream regressions.
Reset goes to a commit and therefore cannot fabricate anything. So reset takes
every defensive position, unapply takes only the positions where our authorship
of the change is certain, and the call site chooses rather than a person.

**The recorded commit** advances only after a build succeeds. That way the
staleness auditor's baseline can never point at a version that was never shipped,
and a failed build leaves the previous baseline intact.

**The staleness auditor** runs on every upstream update and emits one verdict per
patch against the fresh tree: *retire* when the probe says the patch is no longer
needed because upstream adopted the shape; *stale* when the anchor has vanished
because upstream restructured the target; *review* when upstream's changed line
ranges overlap the anchor, so the patch may still apply but its meaning in the
new surroundings is no longer guaranteed; and *fine* otherwise.

For the verdicts needing judgment it writes a uniquely-tagged comment into the
working tree directly above each anchor, in that file's own comment syntax, so
that a single search enumerates the entire decision set. Those tags live in the
disposable tree and vanish at the next reset, which is right for one review
session; a dated report is written alongside the registry so the decisions
survive.

## Suggested implementation steps

1. Write the clone script so it takes the destination as a variable with a
   hard-coded default, and can be run from any directory.
2. Keep the fetch shallow. The engine is small; the game data is not, and its
   history is almost entirely asset revisions this project will never read.
3. Write reset to walk both trees.
4. Record the commit of each tree after a successful build, one line per tree.
5. Write the auditor to derive changed line ranges from the version-control
   delta between the recorded commit and the new one, and compare them against
   each patch's anchor line.
6. Make the auditor's severity a wired policy — blocking for a release, warning
   during local iteration — rather than a habit anyone has to keep.

## Related documents

- `101-the-reversible-patch-component.md` for the probe the retire verdict calls.
- `102-the-generators-and-the-gate.md` for the verifier, which shares the
  anchor-match check the auditor uses for its stale verdict.

## Notes

The game data clone is roughly three hundred times the size of the engine clone,
almost entirely in assets. If fetch time becomes a problem, a filtered clone that
omits file contents until they are asked for would cut it substantially, since
this project reads only the QuakeC sources and the configuration files. Not worth
doing until it hurts, but worth writing down as the known next move.
