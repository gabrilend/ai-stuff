# The Work Queue

Everything asked for and not yet built, in the order it makes sense to build it, with
what each one is waiting on. Lives beside the phase progress files because it is the
same kind of thing: a place to look rather than a place to decide.

**Statuses.** `queued` — designed, not started. `blocked` — cannot start until an open
question is answered. `in progress` — being built now. `done` — built, tested, and
struck through with the commit that did it.

---

## Blocked on a question, and the question is yours

These three now live on [the open questions page](../docs/020-open-questions.md) as
**H15, H16, H17**, where the documentation validator counts them. Before that they were
written down only here, so the validator reported two questions needing a decision when
there were five.

### Q1 → [H15](../docs/020-open-questions.md). Terror, and what it does to dying — issue [212](212-a-beaten-body-gets-one-roll.md), [602](602-the-surge-turns-waves-into-a-stream.md)
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

### Q2 → [H16](../docs/020-open-questions.md). Do two allied formations pass through each other, or does one go round? — issue [214](214-going-round-what-is-in-the-way.md)
**blocked**

The scene is built and shows them deadlocking. Which of the two pictures is right is a
design call and changes the caption as much as the code.

### Q3 → [H17](../docs/020-open-questions.md). Does a retreating body still count? — issue [602](602-the-surge-turns-waves-into-a-stream.md)
**blocked**

A body streaming home is on the field, taking up room, blocking lines of sight, and in
push depth. Whether it should be is real: a surge whose lanes fill with bodies going the
wrong way may read as a mess rather than as a current.

---

## Queued, in build order

### 1. Bodies cannot stand in the same place — issue [214](214-going-round-what-is-in-the-way.md)
**done** · reproduced in [the proving ground](111-the-proving-ground.md), both scenes

Neither of the two designs was built and neither will be. The ruling on
[H16](../docs/020-open-questions.md) is one circle test on the ground a body's next step
lands on, and a formation flowing round another formation is fifteen bodies each
declining to stand inside somebody.

**Still owed:** a body cannot change file, so head-on the rule stops a body rather than
moving it aside — which means one stationary ally still halts a formation. That is
**H18** and it is a question for you.

### 2. A body has a size — issue [215](215-a-body-has-a-size.md)
**done, except one part**

Every body carries a radius. It is what is drawn, what is stood on, what another body
may not come inside, and what something must reach past to hit it. Reach is now measured
to a body's skin, without which no melee body could ever touch a monster.

**Still owed:** size does not grow with upgrades, so a fed lane still looks like an empty
one. That was half the point of the issue and it waits on Z3.

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
**done**, and it taught something

They were eighteen paces either side of the centre line, which is less than one
monster's radius, so two of them stood inside each other. They are now spread by their
own size and no further — and the "and no further" is the lesson. Spread across the
*road*, which is what "evenly across the lane" sounds like it means, each monster ends up
eighty paces off the centre line and **holds that file all the way down**, so it arrives
beside the library rather than at it, outside its own reach, and stands there hitting
nothing. Both Golems arrived and neither could touch a library. The deadline is the walk,
and the walk has to end somewhere it can reach.

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

- **Bodies are solid** — [214](214-going-round-what-is-in-the-way.md),
  [215](215-a-body-has-a-size.md), answering
  [H16](../docs/020-open-questions.md). Every body has a radius; nothing stands inside
  anything; reach is measured to a body's skin.
- **Two spawners were putting bodies in the same place**, invisibly, since they were
  written: every tower's guards on the tower's own node, and every wave's rear ranks on
  the library node all three lanes share.
- **A queue is bodies going your own way.** Two allied formations parked nose to nose
  because each was in the other's queue, and neither was ever going to move. Narrowing
  it further — to bodies of your own wave — was tried and reverted: waves stopped
  queueing behind each other, lines stopped forming, and over six thousand ticks nobody
  died at all.
- **Surge bodies are born spread across the starting line** and hold that file down the
  lane, which is [the picture you drew](../inspiration/how-units-should-move-through-a-lane.png).
- **Two new questions for you: H18 and H19.**

## Done the session before

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
