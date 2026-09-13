# 203 - The polite scheduler

| | |
|---|---|
| Phase | 2 - the harvester |
| Blocked by | 201, 202 |
| Blocks | any harvest that runs longer than a few requests |

## Current behaviour

Nothing paces anything.

## Intended behaviour

The owner's instruction, in their words: *we need to make sure that we aren't
bothering them - scraping, yes, but spread out the network load so it's not as
big of a burden on their servers.*

So the scheduler's purpose is not fairness between sources and not throughput.
It is that no server we ask should be able to tell we are here. Alternating
between sources falls out of that as a consequence rather than being the goal -
spreading load across sources is one of the ways load stops being concentrated.

The rules, in the order they matter:

1. **Never two requests at once to the same host.** One connection, in sequence.
   Concurrency is what turns a harvest into something a server notices.
2. **Space requests in time**, per source, at a rate set in its registry entry.
   Every source in this project is being asked for history that is not going
   anywhere, so there is no reason to hurry any of it.
3. **Ask conditionally.** If the last response said how to tell whether it had
   changed, say so on the next request. A server answering "nothing changed"
   spends almost nothing, and most of a fifteen-year archive does not change.
4. **Obey a refusal completely.** A rate-limit response is not retried sooner
   than it asked for, and repeated refusals stop that source for the session
   rather than backing off into a tighter loop.
5. **Identify honestly.** A request says what this project is and where to
   complain, so that an administrator who wants it to stop has somebody to tell.
6. **Prefer not asking at all.** The history branch exists so that someone who
   wants the archive clones it instead of re-gathering it. Every clone of that
   branch is a harvest that nobody's server has to serve, which makes it the
   most effective politeness measure in the project and the reason it is worth
   the disk it costs.

Turn-taking then follows: the scheduler holds one queue per source, and takes
from whichever source has waited longest past its own spacing interval. A source
with a long backfill does not lock out the others, because its spacing applies
regardless of how much work it has left.

## Suggested implementation steps

1. Give each registry entry its spacing interval and its concurrency limit of
   one.
2. Keep per-source state: when it was last asked, what it last said about
   freshness, whether it has refused recently.
3. Write the pacing state to the shared-memory scratch tier as the harvest runs,
   so a long harvest can be watched without being interrupted.
4. Make the harvest resumable. A fifteen-year backfill spread politely over days
   will be stopped and restarted, and restarting must not re-ask for anything
   already archived.
