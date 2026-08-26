# Phase 10 — The Metronome: progress

**Clock, reset, and getting six faces to agree about when. Complete.**

| ticket | blueprint | state |
|---|---|---|
| `1001` | `070-clock-generation` | done |
| `1002` | `071-clock-distribution` | done |
| `1003` | `072-cross-face-synchronisation` | done |
| `1004` | `073-reset-and-boot` | done |
| `1005` | `074-timing-budget` | done |

**Three hundred and seventy-three constraints hold across sixty-seven
blueprints.** Fifty-five wait on phase 11, which is where the reference model
lives.

## The question that got answered in the negative

`070` published the ratio between the face clock and the core clock so that `074`
could say whether the two domains might be one. **They cannot.** The core's path
does not fit a face cycle, so the crossing in `072` stays and the machine keeps
five supply domains and two clock domains.

That is worth having as a derived answer rather than an assumption, because
merging them would have removed a domain crossing, a synchroniser and a whole
class of failure.

## The distribution that turned out easy

The level that looks hardest — between faces, across the whole cube — is the
easiest. **The cage is equidistant from all six faces by construction**, so
inter-face distribution is a star with equal arms. It is the property `000` claims
as a reason for the cube's shape, and this is the second place it has paid off.

What made it easy is a decision rather than luck: faces are **mesochronous**,
sharing a frequency and not a phase, because `072` establishes that they need to
agree about order rather than about time. Insisting on synchrony would have cost
a great deal of power for a guarantee nothing consumes.

## `026`'s finding, applied

A face's thermal time constant is twenty times a pipeline stage, so the
temperature term in clock skew is the **steady** difference between a busy face
and an idle one rather than the walking excursion that phase 1 worried about. It
is far smaller than it first appeared.

## What the checker caught

**Two enumerations disagreeing.** `C-072-1` requires this blueprint and `039` to
count the same number of places two faces touch the same memory. On the first run
they were four and three — this one had counted the reverse staging buffers for
training and `039` had not. Both say three now, and both record that it becomes
four the day `076a` is implemented.

**A claim that was simply wrong.** `073` asserted that initialising memory is
longer than testing it. It is not; it is longer than repair and link training
together. The corrected constraint says that, and the finding underneath is that
**the two slow steps in a cold boot are the model load and a self test whose
duration is currently a guess.**

## The conflict now visible

`074` publishes what the thermal margin would buy in clock frequency. `027`
publishes what the same margin would buy in removing a refrigeration plant.

**Both stake a claim on it and neither knows about the other's.** This is the
clearest unresolved conflict in the project and neither blueprint can settle it —
it is a product decision about whether these are sold fast or sold cheap.

## What is still open

**The enumeration in `072` is checked by count, not by name.** Two blueprints
could each name three different sites and pass. The notation holds numbers and
not lists, and this is the weakest link in the argument that mesochronous
operation is safe.

**Step five of the boot has nowhere to read its repair map from** (`073`). The
**fourth** blueprint waiting on the same missing non-volatile store, after `033`,
`040` and `069`.

**Reference loss must be detected and no detector exists** (`070`), and it cannot
be clocked by the thing it watches.

**Two `given` delays carry the whole timing budget** (`074`, `071`): the logic
delay through a cell `045` has not laid out, and a skew coefficient per kelvin.
