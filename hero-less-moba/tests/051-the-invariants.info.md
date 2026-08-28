# 051-the-invariants

The properties this project refuses to break, checked in one run.

## Running it

```
luajit tests/051-the-invariants.lua
```

Exits non-zero if anything failed, so it can be wired into a build. `./run-tests`
runs this along with the formation sandbox and the documentation validator.

Every check prints as one line. The run's own count is the answer to "how many are
there" — this file describes what they guard, not how many, because a number
written down here goes stale the first time somebody adds one.

## What it checks, grouped by what it is really guarding

### The map is fair, and the geometry agrees with itself

| Check | Fails the day somebody… |
| --- | --- |
| The map validator finds nothing wrong with the map it builds | …changes a shape parameter that makes the geometry inconsistent — a lane shorter than its milestones, a tower with no site, a bend that does not close. |
| A lane's milestones mirror across the junction diagonal | …breaks the symmetry independently of the validator noticing. An asymmetric map hands one team a shorter walk and nothing else in the project would ever say so. |

### The camera

| Check | Fails the day somebody… |
| --- | --- |
| **The world under the cursor does not move while zooming** | …adds a camera feature that quietly breaks the whole point of issue 708. |
| Home returns to the whole map instantly and drops the drag | …makes getting back a navigation task, after which players stop zooming in at all and the detail the camera exists for goes unread. |
| The camera cannot pull back past the whole map | …lets the map drift into empty space. |
| The camera cannot push in past the badge-reading ceiling | …unbounds the zoom. |

### The simulation's own arithmetic

| Check | Fails the day somebody… |
| --- | --- |
| A query wider than the grid's cell still finds everything | …reintroduces the fixed nine-cell ring. This is the regression for a real bug: a body carrying two Longbows reaches further than one cell, and the first version of the query silently searched too few of them. |
| No per-body field is ever nil | …adds a field to the world and forgets to zero it, or to clear it on release. The simulation has no nil checks anywhere and is only safe for that reason. |
| **The same seed plays the same match, tick for tick** | …adds a global random call, iterates a hash table whose order is not stable, or reads the wall clock. |

### Formations

| Check | Fails the day somebody… |
| --- | --- |
| A wave marching round a bend keeps its ranks | …changes the walk so that lane coordinates let a body take a turn for free. |
| The formation turns rather than stretching | …breaks the rule that the outer file is hurried and the inner one gives way. |
| The cohesion budget is shared out, not handed out | …lets a straggler's bonus come from nowhere instead of from the bodies ahead of it. |

The deeper formation work has its own suite, `060-the-formation-sandbox`, which
measures a bend rather than asserting one property about it. These three are the
cheap standing versions, kept here so a whole-match run notices.

### The opening

| Check | Fails the day somebody… |
| --- | --- |
| The opening is a mirror — same stone, same wallets, same first wave | …hands one team a different starting board. **Note what this does not claim**: the two teams are set up as mirrors and are not kept that way. Two even sides diverge almost immediately and are supposed to. |
| Every hero on every roster can be paid for | …prices a hero out of a colour no commander can reach, so it is on the list and can never be bought. |

### The chest, and what a player may do with it

| Check | Fails the day somebody… |
| --- | --- |
| A stone can be marked to move, is still in the chest the instant after and after one wave, and lands on the second | …makes a move quiet or instant. A move announces itself for a full wave and nobody opted into that. |
| A move can be called back, and then it simply stays where it was | …makes calling it back cost something. |
| A stone somebody owns cannot be set aside, but can be given to the pool | …lets a teammate reach into another player's holding. |
| Each dismissal removes it from one player's view and nobody else's, and when everybody has set it aside it comes back to all of them | …makes "set aside" a shared decision rather than a private one. |
| A request changes nothing by itself; nobody can take a stone that is not theirs; the owner can give it, and then it is theirs to place | …turns asking into taking. Giving is easier than asking, deliberately, and that asymmetry is the whole social design. |
| A boon nobody chose is still on offer long after the calm ends, and no team was granted one it did not choose | …makes something decide for a player. This is the only place in the project where that was ever tempting. |
| A hero obeys the sign at its junction and crosses to the next lane, with its one turn spent | …breaks sign-post routing, or lets one body turn twice. |

### The premise, and the ending

| Check | Fails the day somebody… |
| --- | --- |
| The stacked lane actually holds the upgrades, **and its frontline is further forward than the lanes beside it** | …breaks the premise, however well everything else runs. If stacking a lane does not move a frontline, none of the rest matters. |
| A surge deals the whole holding to bodies in every lane, and takes nothing out of the slots to do it | …makes a surge spend the board instead of copying it. |
| A match left alone reaches an ending, through three surges and three challenges; the first two monsters die and the third does not | …removes the deadline. Without it two even teams grind for as long as anybody will watch, which is not a stalemate the design wants — it is the absence of an ending. |
| A match somebody plays is won rather than drawn, and the chest was actually used to do it | …makes playing indistinguishable from not playing. |

### The way in

| Check | Fails the day somebody… |
| --- | --- |
| With nobody saying anything the way in is the menu; a named match or scenario skips it; a camera pointed at a scenario still gets the scenario; a camera with nothing named gets a match; a camera pointed at the menu gets the menu; a start naming no scenario leaves the menu up | …reorders the start-up questions. This is the regression for a real bug: asking for a screenshot of a scenario photographed an ordinary match instead, and nothing about the picture said so, because it looked like a game. |
| A scenario loaded at the gate moves the clock to where it says, stands the described phase and monster up, and was holding still until something asked it to move | …breaks the far end of the bypass. The check above proves the right door opens; this proves there is a room behind it. |

### Death

| Check | Fails the day somebody… |
| --- | --- |
| Bodies fall and begin decaying rather than vanishing; a decaying body is not alive, is not in the living count, still holds its own slot halfway through, can be brought back intact, and nobody was paid for a death that was taken back | …makes a death instant again. The slot being reachable is the entire mechanism by which a death can ever be corrected from another machine — once it is recycled there is nothing left to write onto. |
| Bodies spend time decaying over a whole match, their deaths are announced when they become certain, a finished decay hands the slot back, and nothing decays for longer than its span | …breaks the far end. A body stuck decaying would hold its slot for the rest of the match and never pay anybody, and the free list would drain until the world ran out of room. |

### The replay

| Check | Fails the day somebody… |
| --- | --- |
| A match records keyframes as it is played, the file reads back as the match that was recorded, the commands somebody made are in it, and playing it back reproduces the match at every keyframe | …breaks the recording or the playback. Played with corrections **off**, so what is checked is the simulation reproducing the match on its own rather than the keyframes dragging it into place. |
| A world that has drifted stops matching the record, the keyframes hold it near the match that was played, and it does not wander further as the match goes on | …makes the keyframes decorative. Measured as a **distance in world units** rather than as a hash match, because after a correction the hash is the wrong instrument — it is taken before the correction lands and answers yes-or-no about a world that is now approximately right. |
| The rules stamp is the same twice for the same rules, changing one number anywhere changes it, putting the number back puts it back, and a replay from other rules is refused rather than migrated | …lets a replay recorded before a balance change play under the new numbers. It diverges within seconds and every symptom points at the replay system rather than at the catalogue somebody edited. |

The divergence check is also the project's only measurement of **how far apart two
runs can get**, which is a question the network design needs and cannot answer by
argument. It prints both numbers — corrected and uncorrected — and they are the
evidence behind H1 and H2 in the open questions.

## Three of them earn their place above the others

**Reproducibility** is the project's most valuable regression test. It is compared
on a fingerprint of every body's position and health rather than on a summary,
because a summary can agree while the details diverge.

**The camera anchor** is checked with four hundred random cursor positions and
random scale changes rather than with one hand-picked case, because every later
camera feature is a chance to break it silently. It is asserted against the
camera's **target** rather than its drawn values — the animation is allowed to be
on its way; it is the destination that must be exact. Trials where the pan clamp
bites are skipped rather than failed, because the clamp is a deliberate rule and
not a defect.

**A stacked lane pushes further.** It is the only check here that is about the game
being worth playing rather than about the machine being correct.

## The test's own randomness

The camera test uses a small hand-written generator rather than `math.random`, so
that a failure is reproducible — and so that this file cannot be the thing that
introduces global randomness into a project whose first invariant is that there is
none.

## What is deliberately not checked

**Tick-by-tick symmetry.** An earlier version of this file asked for it, and it was
the wrong claim. Two even sides diverge almost immediately: a tie broken one way in
one lane is broken the other way in another, and by the second exchange the two
halves of the field are different games. Holding the mirror past the opening would
cost a canonical ordering on every tie in the hottest loop in the simulation,
bought to preserve something with no gameplay meaning after the first ten seconds.
What is checked instead is that the **opening** is a mirror.
