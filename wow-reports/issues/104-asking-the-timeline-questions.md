# 104 - Asking the timeline questions

| | |
|---|---|
| Phase | 1 - the patch spine |
| Blocked by | 102 and 103 |
| Blocks | the viewer's scrubber, and every dating decision in extraction |

## Current behaviour

Build records exist as a list. Nothing can be asked of them.

## Intended behaviour

The small set of questions everything downstream needs to ask of the timeline,
answered in one place so that no two callers answer them differently.

The questions:

- **Order.** Given two builds, which came first. Within one product line this is
  the build number. Across lines it is the release date, and comparing builds
  across lines by number is an error rather than a guess, because the numbers
  mean different things in different lines.
- **What was live.** Given a date and a product line, which build was current.
- **What came next.** Given a build, the build that followed it in its own line.
- **Which expansion.** Given a build, its name from the expansion table.
- **The span.** The earliest and latest build the archive knows about, per line,
  which is what the scrubber's two ends are.

## Suggested implementation steps

1. Write these as a small set of functions over the build records, with no state
   of their own beyond the records handed to them.
2. Make cross-line numeric comparison raise rather than return. It is the
   mistake this whole issue exists to prevent, and a comparison that silently
   returns a plausible wrong answer will be found years later inside a chart.
3. Test each question against known builds, including the awkward ones: two
   builds released on the same day, a build in a Classic line whose number is
   lower than a retail build released a decade earlier, and a date before any
   build existed.

## Related documents

- The shape of a fact - why a fact is always paired with a build
