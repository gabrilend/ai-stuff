# 606 -- Handing a scope over

**Phase:** 6, control is a dial
**Blocked by:** [604](604-a-viewer-holds-several-scopes.md)
**Blocks:** [607](607-the-phase-six-demo.md)
**Documents:** [who controls what](../../docs/008-who-controls-what.md)
**Open questions:** [6.3](../../docs/016-open-questions.md) — orders in flight;
[4.4](../../docs/016-open-questions.md) — what a departure does.

## Current behaviour

A viewer is given a body on joining and keeps it until they go. Nothing changes
hands.

## Intended behaviour

A GM hands the tavern to somebody who has just arrived. Somebody drops and their
character stops being anybody's.

A scope's `viewer` field changes. That is the whole mechanism — and it is world
state, so it is snapshotted, rolled back, and hashed like anything else.

### Orders in flight

Standing orders belong to the **bodies**, not to the scope. So a handover leaves
six goblins already walking somewhere, and the new commander inherits an intention
they were not told about.

Three answers, none argued out ([6.3](../../docs/016-open-questions.md)):

- Keep them. The world does not stop because somebody changed seats.
- Clear them. The new commander starts from stillness.
- Show them. Hand over the orders as visible standing intentions.

**Keep them** is what falls out of doing nothing, so it is what gets built — and
that is worth being honest about rather than presenting a default as a decision.

### A departure unholds, and does not destroy

When a viewer goes, their scopes' `viewer` becomes 0. The scopes remain, holding
whatever they held. An unheld scope is a normal thing: the forest exists whether
or not anybody is playing it tonight.

Whether the departed person's **character** should keep standing there, be driven
by a GM, or vanish is [4.4](../../docs/016-open-questions.md) and is still open. What
this issue settles is only that the *scope* survives.

### Only somebody who may

Handing over is a command and runs the gauntlet. Who may is not obvious: a GM,
plausibly; the current holder, plausibly; both, plausibly. Requiring
`MAY_EDIT_WORLD` is the narrow answer and is what gets built.

## Suggested implementation steps

1. Add a `GIVE_SCOPE` verb: which scope, which viewer.
2. Gate it on `MAY_EDIT_WORLD`, refusing in words otherwise.
3. Unhold on departure.
4. Make sure sight and fog follow — the new holder sees from the bodies now.
5. Write the companion `.info.md`.
6. Test: hand over, confirm the old holder is refused and the new one is not; a
   departure unholding; a handover surviving a rollback.
