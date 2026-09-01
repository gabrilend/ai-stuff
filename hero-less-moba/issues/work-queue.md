# The Work Queue

Everything asked for and not yet built, in the order it makes sense to build it, with
what each one is waiting on. Lives beside the phase progress files because it is the
same kind of thing: a place to look rather than a place to decide.

**Statuses.** `queued` — designed, not started. `blocked` — cannot start until an open
question is answered. `in progress` — being built now. `done` — built, tested, and
struck through with the commit that did it.

---

## Blocked on a question, and the question is yours

### Q1. Terror, and what it does to death — issue [212](212-a-beaten-body-gets-one-roll.md), [602](602-the-surge-turns-waves-into-a-stream.md)
**blocked**

The rule is settled: a body carries **terror** as well as health, morale attacks
(*fear*, *despair*, *ruin*) deal terror rather than damage, and **a body retreats when
terror plus health falls below zero.**

What is not settled is what happens to **dying**. Today a body dies at zero health.
With this rule, a body at zero health and no terror is at exactly zero — not below it —
and a body reduced past zero by an ordinary blow is already negative and would retreat
rather than die. So either ordinary damage does not push health below zero, or
retreating and dying are separated by something else, or issue 212's roll is what
decides between them. The third reads best and is not yet written down as the answer.

### Q2. Do two allied formations pass through each other, or does one go round? — issue [214](214-going-round-what-is-in-the-way.md)
**blocked**

The scene is built and shows them deadlocking. Which of the two pictures is right is a
design call and changes the caption as much as the code.

### Q3. Does a retreating body still count? — issue [602](602-the-surge-turns-waves-into-a-stream.md)
**blocked**

A body streaming home is on the field, taking up room, blocking lines of sight, and in
push depth. Whether it should be is real: a surge whose lanes fill with bodies going the
wrong way may read as a mess rather than as a current.

---

## Queued, in build order

### 1. Stepping aside, both versions — issue [214](214-going-round-what-is-in-the-way.md)
**queued** · reproduced in [the proving ground](111-the-proving-ground.md), two scenes

Two separate things, and they are alternatives to be built and compared rather than one
design:

- **Swarm pathfinding** — every body for itself, going round whatever is in front of it.
- **Formation-respecting avoidance** — a formation gives way to another formation as a
  body; a formation does **not** move for a stray, and its members filter round him and
  close up behind.

And underneath both: **a body can move laterally between files** to fill an opening in
the front. A hole in the line ahead of you is a place to rush to, not a place to wait
behind.

### 2. A body has a size — issue [215](215-a-body-has-a-size.md)
**queued**

Large bodies walk far too close to everything and small bodies stand inside them,
because there is one `personal_space` for a monster and a soldier alike. Room becomes a
question about **both** bodies' sizes. Size grows with upgrades, so a fed lane is
visibly bigger. The renderer's separate drawn-size table goes away — which reverses a
decision that file states and defends, and hands the drawing back the problem it was
avoiding.

### 3. The surge — issue [602](602-the-surge-turns-waves-into-a-stream.md)
**queued** · partly blocked on Q1 and Q3

- **One hit point for everyone the surge sends out** — settled: the bodies the surge
  emits, not everyone on the field. They are testing arrangements of technology and
  they return once they have been subjected to a hit.
- **Terror, and retreat when terror plus health is below zero** — settled as a rule,
  blocked on Q1 for what it means for dying.
- **Running home, avoiding allies and foes alike** — settled, and where home *is* is
  settled too: a guard runs to its guardhouse, a wave body to a guardhouse in a
  neighbouring lane, a hero to the home library. **Guardhouses do not exist yet**, which
  makes them a prerequisite rather than a detail.

### 4. Guardhouses
**queued** · no issue yet · prerequisite for 3

Named for the first time as the place a retreating body runs to. Nothing about them is
written down; they need an issue before anything else here can be finished.

### 5. Darts for ranged weapons — issue [702](702-the-map-draws-itself.md)
**queued**

Tiny darts in flight for ranged attacks. **Red darts for the blue team, green darts for
the orange team** — the dart is coloured by what it is flying at rather than by who
threw it, which is the opposite of every other colour rule on the screen and is the
point: you see what is being shot at.

### 6. Green rising `+` marks on healing — issue [702](702-the-map-draws-itself.md)
**queued**

The only event in the game with no picture at all, and five healer archetypes designed
to differ in shape that a player cannot currently tell apart.

### 7. Monsters spread across the centre lane — issue [606](606-what-walks-out-of-the-middle.md)
**queued** · small

Two monsters at the midpoint, spaced evenly **across** the lane's width rather than both
on its centre line. The widest ground in the game and they are standing inside each
other.

### 8. Rendering that lags the simulation with inertia
**queued** · no issue yet · the largest of these

Three separate things asked for together, and they should probably be three issues:

- **Snapping a movement target off an occupied place.** When a target lands within
  `self.radius + other.radius` of a body, it snaps to the point on that circle that is
  most "up".
- **The drawn position is not the simulated one.** The body renders where it was and
  travels toward where the simulation says it is — not a lerp, but something that
  carries inertia and can overshoot and settle.
- **The simulation writes into shared memory that every thread reads**, including the
  rendering thread.

The third is an architecture change; the first two are visible immediately and could be
built without it. Worth splitting before starting.

### 9. Replaying the development as git history
**queued** · skill written at [`skills/replay-the-development/SKILL.md`](../skills/replay-the-development/SKILL.md)

Write out each design iteration as it stood, commit them in order, and replay forward,
so the last few sessions become history rather than one enormous diff. The method is
written down; **running it is not started**, and it should not start while the working
tree still holds uncommitted work from more than one session.

---

## Done this session

- **The proving ground** — [111](111-the-proving-ground.md). A short straight road, a
  named subset of the machinery, and a window that draws nothing belonging to a match.
  Two scenes, both entirely allied. `./run-arena`
- **A random seed, with a notebook** — `input/seed` accepts `random`, draws one, and
  appends it to `tmp/shared-memory/seeds.log`. `HLM_SEED` on the command line beats it
  and is not logged. The test suite pins its own.
- **The generated HTML is no longer committed** — checked rather than assumed: a build
  regenerates all 165 pages and leaves nothing behind.
- **Archers are wedges, melee are discs** — [702](702-the-map-draws-itself.md).
- **A body looks up when struck by somebody new** — [204](204-choosing-what-to-attack.md),
  gated so a body already swinging at something it can reach does not turn round.
- **The fanning rank is no longer held to the road** — [214](214-going-round-what-is-in-the-way.md)'s
  ancestor, and it turned out to be dead code.
- Three bugs found on the way: the wave record had three fields only the ordinary
  spawner filled in; the formation's advance re-derived its heading from the team
  instead of reading it; the scenario gate's `wave` verb has never worked in any
  scenario that also sets a clock.
