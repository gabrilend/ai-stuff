# Open questions

Every question here is unanswered and the project is in progress until each has
been worked through, one at a time. Settled decisions are kept at the top rather
than deleted, because a decision without its alternatives beside it stops being
a decision and turns into an assumption.

---

# Settled

## Will we register API clients? - No, not for now

Built on open sources only. Nothing in this project requires an account or a
secret.

Consequence, stated plainly: the outside archive of real uploaded fights is out
of reach, so nothing measures real players. The correlation term therefore gets
computed the self-contained way - event simulator against arithmetic model on
identical inputs - which answers "what does the ruleset offer for sequencing
well" instead of "what did real raids actually extract". See the vision note.

Second consequence: with that archive declined, the event simulator becomes the
only instrument in the project that measures uptime at all, which is why it
cannot be dropped.

## Which simulator? - Both, and the gap is the output

## How far back? - Everything, 2011 onward, all game lines

Accepted cost: spell identifiers get reused across eras, statistics get invented
and removed, whole systems appear and vanish. Every later design question is
harder for this. The archive has to carry the era with every fact, and no two
facts from different eras may be compared without their eras being compared
first.

---

# Outstanding

## 1. Where does the raw archive live, and is it tracked?

Every fetched byte kept forever, exactly as received - that follows from
append-only memory and it is the right shape. It is not free. A full clone of
the open-source simulator's history plus a meaningful slice of per-build client
data is measured in gigabytes, and fifteen years of all game lines is the large
end of that.

The fork: archive inside the repository, so that history is literally the
history; or archive beside it, gitignored, with only the provenance records
tracked, so the repository stays small and the archive is re-fetchable.

The second is smaller but it breaks the promise, because re-fetching in 2029 does
not return what 2026 returned.

## 2. What shape do extracted facts get stored in?

Three candidates, and the stated preference for structs and primitives over
frameworks argues against the heaviest:

- **Serialised tables**, one file per build, read straight back into memory.
  No dependency, trivially diffable, and reading fifteen years means reading
  every file.
- **A single indexed database file.** The query engine is already on this
  machine. Answers "this ability across every patch" without reading everything,
  which is the viewer's entire access pattern. It is also a framework sitting
  between you and your data.
- **Flat columnar files plus a manifest.** Cheapest to write, cheapest to
  stream, and every interesting query has to be written by hand.

## 3. How do we find the spreadsheets at all?

Fetching a shared sheet is solved; finding one is not, and no index exists.
Ranked by likelihood of working:

- You supply a seed list of sheets you already know, and the harvester follows
  links found inside them to further sheets.
- Harvest links from public discussion served as machine-readable data, without
  scraping any rendered page.
- Accept the arm stays small and hand-curated, and let the automated arms carry
  the project.

## 4. Confirm the rule for an artefact with no stated patch

Proposed and written into the roadmap, but not yet confirmed by you: refuse to
guess, record the patch as unknown, and show unknown loudly rather than placing
the artefact on the timeline at an invented position. This follows your standing
rule that a fallback is a warning and a warning is an error.

The cost is that the timeline gets a visible pile of undated things sitting next
to it, permanently.

## 5. Does "gathering stats in the game" mean an addon?

Read literally, the request asks for a second harvester that is not on the
internet at all: code running inside the game client, in the game's own embedded
Lua, watching auras tick on and off and writing totals into the saved-variables
file the client flushes on logout, which something outside then reads.

This matters more now than it did before the API decision. It is the only
remaining way to get uptime that was *observed* rather than *simulated*, and
without it the project has no empirical check on its own event simulator at all.

## 6. What does taking turns between sources actually mean?

Equal turns - one request each, in a circle - or proportional, where a richer
source is asked more often. These produce very different archives. Equal turns
is fair and slow; proportional fills faster and skews the archive toward
whichever source happens to be most generous.

## 7. Where does the viewer live?

Another page in the documentation set, in the shared style with the contents
tree down the left; or a separate thing the documentation links to, so a
data-heavy interactive page is not forced into a documentation layout.

## 8. Where do we start, across fifteen years and forty specialisations?

The archive can hold everything. The simulators cannot be written for everything
at once. One specialisation, followed across every patch, is a complete vertical
slice and proves the whole machine. Which one - and is it chosen for being
simple to model, or for being interesting to look at?

## 9. Who writes the expansion table?

The mapping from a patch's leading number to the name a person uses is the only
hand-written table in the project, because no open source states it. It is small
and it is the sort of thing you may have opinions about - where Classic's
re-releases sit relative to the original, whether the test realms are their own
line.

## 10. Does this project sit inside a sandbox?

There is a tool in your scripts directory that builds projects inside a mount
namespace in RAM, where the only writable thing is the project and work reaches
disk by being committed. This project is currently a plain directory on disk,
because relocating where work happens is not a decision to make on your behalf.

A harvester that writes gigabytes and reaches the network is arguably exactly
what that wall was built for - but the wall does not contain the network, and
the network is the whole point here.

## 11. What era does the custom client target?

The emulator implements one client era, and that era decides what emission can
carry. But the destination is a custom client and a deliberately different game,
so the era is a choice rather than a constraint inherited from the emulator.

It shapes the largest mapping work in the project - archive field to database
column - because that schema is per-era. Choosing late costs that work twice.

## 12. How long is a resolution interval?

Combat substitution answers for a chunk of fight at a time. Short intervals feel
responsive and cost more; long intervals cost almost nothing and make the world
feel like it is resolving in slabs. It also sets how finely the commander can
intervene: a player cannot redirect a fight faster than the interval that
resolves it.

## 13. Who owns the performance layer?

Resolution decides outcomes; presentation invents visible actions that add up to
them. Presentation lives on the client side of the seam, which means it is the
other project's work - but the contract between them is defined here, because
this side is the one that knows what the numbers mean.

The rule that must hold either way: presentation never feeds back into
resolution. The moment it does, the cost saving is gone.

## 14. Which specialisation is the first vertical slice?

Unchanged from before but now sharper. The first specialisation modelled should
probably be one whose gap between the two simulators is expected to be *large*,
not small - because a large gap is what stresses the substitution, and finding
out early that some designs cannot be played by proxy is worth more than
confirming that a simple one can.

## 15. What is in the project's input directory?

Standing practice is that a program reads its input directory first and that is
how it knows how to start. Nothing has been put there yet, and the harvester is
the first program that will want it - a seed list of spreadsheets, a chosen
build, a list of sources to skip this run.
