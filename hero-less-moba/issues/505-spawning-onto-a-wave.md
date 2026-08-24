# 505 — Spawning Onto a Wave

| | |
| --- | --- |
| Phase | 5 — Commanders and Heroes |
| Blocked by | 106, 207, 503 |
| Blocks | 703 |
| Reads | [hero units](../docs/012-hero-units.md) |
| Open questions | none |

## Current behavior

A bought hero appears at the library and has a long walk to anywhere useful.

## Intended behavior

The first of three spawn destinations. A player picks one of their team's living
waves, and the hero appears **with that wave, wherever it currently is,
immediately**.

This is the aggressive option. The hero arrives already at the frontline, in
formation, with the wave's bodies around it. It is also the fragile one, because
the frontline is where the enemy's damage already is — a hero dropped into a
losing fight can die before it swings.

That tradeoff, against the library's slow-but-safe arrival, is the entire spend
decision, and it is why all three destinations exist rather than one.

The hero joins the wave's position but **not its wave record**. It does not count
toward `member_count` or `living_count`, and killing it does not contribute to
wiping that wave. A wave is a batch of wave units; a hero standing among them is
a guest. Otherwise a player could keep a wave from being wiped by feeding heroes
into it, which would break the upgrade economy in a way nobody would ever
diagnose.

"Wherever the wave currently is" means the position of the wave's **rearmost
living member**, not its front. The hero arrives behind its escort rather than in
front of it, which is both what a player expects and what keeps this from being
strictly better than every other option.

## Suggested implementation steps

1. Extend `spawn_hero` to take a destination kind and a wave id.
2. Refuse if the wave is not this team's, is settled, or has no living members.
3. Place the hero at the rearmost living member's edge and progress, facing the
   same way.
4. Explicitly do **not** touch the wave's counters, and comment why.
5. Write a test: spawn onto a wave, kill every wave unit in it, assert the wipe
   event fires while the hero is still alive.

## Related documents and tools

- [Hero units](../docs/012-hero-units.md)
- [Waves, and when one is finished](../docs/005-waves-and-when-one-is-finished.md)

## Still open

During a challenge, waves do not spawn into the side lanes at all — everything
goes to the center. Spawning onto a wave during a challenge therefore means
spawning into the center, which may make this destination strictly better during
challenges than at any other time. Whether heroes should be buyable during a
challenge at all is unsettled.
