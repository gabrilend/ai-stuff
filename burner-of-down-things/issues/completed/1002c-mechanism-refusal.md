# 1002c — Mechanism refusal

The third piece of 1002.

## Current Behavior

Built. `src/085-the-lesson.lua`'s `mood_of(text)` is the mood-vs-mechanism
check, and `build` sends back any lesson whose mechanism it finds a mood,
saying why and showing the house example. Three shapes are refused, from
closed word lists so the check is counted rather than judged: fewer than
three words (too few to name an actor and what followed); a verdict after
a linking word (`the build was bad`, `the tests were not very good`, `the
repair went wrong`); and a sentence ending on a verdict or holding nothing
but verdicts and filler (`the build failed`, `sloppy and buggy and
broken`). Checked by `tests/109-checking-mechanism-refusal.lua`: five
mechanisms kept, eight moods sent back, each naming why.

Also built here, since 1003's drafting needs real lessons: `lesson.read`,
the `lessons.md` reader 1002d deferred, which turns `append`'s file back
into lesson records (rebuilt through `build`, so a hand-edited mood is
refused on reading) that feed `mechanism_counts.from_lessons` unchanged.
Checked by `tests/110-checking-the-lessons-reader.lua`.

Decision: a word-list check, not a model's judgement — docs/069 says
recurrence is counted, not judged, and a check that gives the same answer
every time can say exactly why it refused. It will let through some moods
dressed as mechanisms; the person's promotion gate (1003d) is the second
look.

## Intended Behavior

A lesson without a mechanism is sent back — a mood ("the build was bad")
is not a mechanism ("a builder grading its own work passes itself"),
docs/069.

## Suggested Implementation Steps

1. The mood-vs-mechanism check (a mechanism names an actor and a
   consequence; a bare judgement word is refused). **Test:** a lesson
   with no mechanism is refused; one with a mechanism is kept. Done:
   `085-the-lesson.lua`'s `mood_of`.

## Blocked by

- 1002a
