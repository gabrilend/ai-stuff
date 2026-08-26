# 406 — Locking a Placement

> **Will not be implemented.** Stones belong to individual players now, so a
> teammate cannot move what you placed and there is nothing for a lock to defend
> against. Replaced by **issue 412**, which builds contributing a stone to the
> communal pool. See F29 and F31 in the open questions.
>
> Left as written. The number is spent and will not be reused.

| | |
| --- | --- |
| Phase | 4 — The Shared Chest |
| Blocked by | 106, 402, 404 |
| Blocks | 407, 704 |
| Reads | [the shared upgrade pool](../../docs/009-the-shared-upgrade-pool.md) |
| Open questions | none |

## Current behavior

Any player can move any of their team's upgrades at any time. A player who has
arranged three upgrades into a plan can have all three moved by a teammate who
did not know there was a plan, and neither of them will ever find out what
happened.

## Intended behavior

Any player may **lock** any of their own team's placed instances. A locked
instance cannot be moved or withdrawn by a teammate. The locker can always unlock
their own.

The vision's framing: a player locks something because "they've got a thing
going, y'see." An intention that a teammate scanning the board cannot see and
would otherwise trample.

What this system actually is, and it should be built as this rather than as a
permissions system: **a communication channel with exactly two verbs.** Locking
says *I am doing something here.* Objecting, in issue 407, says *I would like you to
stop.* A team that never locks anything has not started talking to each other
yet, and the interface should make that visible rather than comfortable.

Rules:

- Locking is free and instant. No cooldown.
- Only **placed** instances can be locked. Locking something sitting unplaced in
  the chest is meaningless — nobody is going to move it from nowhere.
- A lock survives the instance being unaffected by anything else. It does **not**
  survive a siege-surge, which releases every lock along with every placement.
- The locker's name is stored, and the viewer shows it. An anonymous lock is an
  argument with nobody.

## Suggested implementation steps

1. Write the `lock_upgrade` and `unlock_upgrade` handlers.
2. Add the lock check to the placement and withdrawal handlers from issue 404,
   ahead of every other check, so "locked by someone else" is the reason reported
   rather than a cooldown that also happened to apply.
3. Put `locked_by` into the snapshot so the viewer can draw who.
4. Write a test: player 1 locks, player 2's placement is refused with the right
   reason, player 1's own placement succeeds.

## Related documents and tools

- [The shared upgrade pool](../../docs/009-the-shared-upgrade-pool.md)
- Issue 407, the other half of the conversation

## Settled

**Locking is unlimited and free.** No cap, no cost, no decay. One player claiming
every instance the team owns is legal, and answerable — slowly, one at a time,
through issue 407.

So there is **no counter to enforce and no timer to run**. The one thing the
interface owes a player is a visible count of what they currently have locked,
because the failure mode here is not malice. It is forgetting.

See [the shared upgrade pool](../../docs/009-the-shared-upgrade-pool.md).

## Still open

Nothing blocking. Issue 407's objection timeout is the remaining question in this
area, and it belongs to that issue.
