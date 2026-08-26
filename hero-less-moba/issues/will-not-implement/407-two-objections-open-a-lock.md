# 407 — Two Objections Open a Lock

> **Will not be implemented.** The two-key rule existed to open a lock against
> its holder's wishes, and there are no locks. Replaced by **issue 413**, which
> builds the dismissal cycle — a disclaim rather than a claim, and one that
> scales to any team size where "two objections" never did. See F31.
>
> Left as written. The number is spent and will not be reused.

| | |
| --- | --- |
| Phase | 4 — The Shared Chest |
| Blocked by | 106, 406 |
| Blocks | 704 |
| Reads | [the shared upgrade pool](../../docs/009-the-shared-upgrade-pool.md) |
| Open questions | none |

## Current behavior

A lock is absolute. If a player locks an upgrade and then stops paying attention,
their teammates can do nothing about it for the rest of the match.

## Intended behavior

A teammate can **object to** a locked instance to ask for it to be released. When
**every teammate other than the locker** has objected it, the lock releases
automatically: `locked_by` goes to 0 and `objection_mask` clears.

On a three-player team that is the vision's "if both of them do so." It is
written as *everyone but the locker* rather than *two people* deliberately, so
that the rule survives a change of team size — which is much more likely to
happen than the rule itself changing.

The design shape: **one teammate objecting is not enough, two is.** A single objection
is an opinion. Two objections from two different people is a team decision, and the
locker is outvoted by the rest of their team rather than by whoever clicked
first. That is the smallest possible democratic mechanism, and it is doing the
job that voice chat would otherwise do — with the advantage that it works when
nobody is talking.

Objections **expire** after a timeout. Without expiry, the two-objection rule quietly
becomes a one-objection rule on any long match: an objection left over from four minutes ago
combines with a fresh one to open a lock that nobody currently objects to. With
expiry, the two objections have to be roughly contemporaneous, which is what
makes them a decision rather than an accumulation.

A player cannot object to their own lock — they can just unlock it — and cannot object
the same instance twice to count as two.

## Suggested implementation steps

1. Write the `object_upgrade` handler: set this player's bit in `objection_mask`, record
   the tick.
2. Write the release check immediately after: if every teammate but the locker
   has a live objection, release.
3. Write the expiry as a per-player tick stamp alongside the mask, checked when
   the mask is read, rather than as a sweep over every instance every tick.
4. Put `objection_mask` and who objected into the snapshot. An objection nobody can see is a
   message nobody received.
5. Write a test: one objection does nothing, two release. Write a test: two objections far
   enough apart in time do nothing.
6. Write a test at team size two and team size four, asserting the rule scales as
   "everyone but the locker."

## Related documents and tools

- [The shared upgrade pool](../../docs/009-the-shared-upgrade-pool.md)
- Issue 406, the other half

## Settled

**Objections expire after a timeout.** That is what keeps two objections a
*decision* rather than an *accumulation* — the two have to overlap in time, which
means two people looked at the same thing and disagreed with it at the same
moment.

Without expiry, every lock on a long match eventually collects enough stray
objections to pop on its own. **That is worse than having no rule, because it
looks like a rule.**

Implementation as described above: a per-player tick stamp alongside the mask,
checked when the mask is read, rather than a sweep over every instance every tick.

See [the shared upgrade pool](../../docs/009-the-shared-upgrade-pool.md).

## Still open

**How long is the timeout?** A balance value with a real range: too short and two
teammates who are not watching each other can never coordinate an unlock at all;
too long and it stops doing its job. Also open: whether the locker should see a
running record of who has objected over time, even when the objections never
reach two at once — repeated disagreement that never quite fires is information a
locker would probably want.

**How many players are on a team?** This rule is where the three-per-team
assumption came from, and it is the rule that changes most if the answer differs.
