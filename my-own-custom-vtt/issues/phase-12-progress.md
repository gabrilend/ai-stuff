# Phase 12 — The table, as it is actually played

**Goal:** four decisions, each of which turned out to be a design the documents
did not have.

**Status: complete.** All six issues done. `./run-phase-demo 12`.

This phase exists because the first eleven were finished and then four questions
were answered — and every answer was more interesting than the options that had
been offered for it.

## The issues

| Issue | What it established |
| --- | --- |
| [1201 commanding is not affecting](completed/1201-commanding-is-not-affecting.md) | Owning a piece is the right to move it, not a fence around it. |
| [1202 the host can remove somebody](completed/1202-the-host-can-remove-somebody.md) | Nothing checks who you are, and this is why that is honest. |
| [1203 and undo what they did](completed/1203-and-undo-what-they-did.md) | The other half, and it needed nothing new in the log. |
| [1204 the controls are a dial you can see](completed/1204-the-controls-are-a-dial-you-can-see.md) | Three dials, and one keyboard moving four bodies. |
| [1205 the state is drawn back to you](completed/1205-the-state-is-drawn-back-to-you.md) | Make the state its own display, for the third time. |
| [1206 the phase twelve demo](completed/1206-the-phase-twelve-demo.md) | The capstone, which found two things. |

## What is built

| Source | What it is |
| --- | --- |
| `106-controls` | Three dials, the arithmetic between them and a point, and the diagram. |
| `108-demo-phase-12` | The capstone. |

Plus `VERB_INTERACT` and the record of what each viewer was told about;
`VERB_EVICT` and `door_show_out`; `session_expunge`; an `on_interact` hook and
four intents in the sample ruleset; the dial in the browser, taking its compass
from the C table by way of the bridge; and `beats_between_checkpoints`, which
used to be called a window.

## What the four answers taught

**A question with several plausible answers and no way to check any of them
against the code is a question about a noun that lies.** Asked what should close
a turn's window, the answer came back as a question: *what do you mean by a
window? Play runs continuously.* Nothing had ever waited. Three plausible answers
had been written down and all three were answers about a thing that does not
exist. Renaming the field dissolved two open questions.

**A permission model can have one gate where it needs two.** Every verb asked *is
this yours*, so a tavern owner could do nothing at all to a patrol in their common
room. Moving a piece and acting on a piece are different questions, and merging
them is the kind of mistake that looks like simplicity for six phases.

**A decision to build nothing still has things to build.** "Nothing checks who you
are" is a real answer, and it was only honest once the host could remove somebody
and unwind what they did. A sentence of the form *we do not need X because Y* with
no Y is worse than having no position at all.

**Reading somebody's actual configuration beat every option offered.** Asked how
one keyboard drives four bodies, the answer was a directory of bind files for a
squad-commanding scheme used in anger for years. It is a modal state machine whose
mode is drawn back to you as a diagram, and it is better than all three of the
obvious answers because those are each half of what somebody wants.

## And two the demo found

**Comparing the wrong two things reports a failure that belongs to the
comparison.** Removing somebody changes the world, so "removed and unwound"
against "never existed" is two different questions.

**Unwind first, then remove.** A rollback reaching back past a removal undoes it.
Nothing is wrong with either piece — the order is a fact about how they compose,
which means it lives in whatever uses both and nothing local will ever mention it.
