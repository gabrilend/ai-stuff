# 024 — The Proving Ground

How a question about one rule gets asked, from here on.

## The problem this exists for

There are two ways to look at this game and both of them show you a match.

The **window** plays one at full size: three lanes across thirteen hundred paces,
eighteen towers, two libraries, a chest, five commanders, a phase clock, two bots. The
**headless runner** plays a thousand of those and prints totals.

Both are right for a question about the game. Both are wrong for a question about a
rule, and the reason is not that they are big — it is that in both of them **everything
is moving at once**. When a rank piles up behind a body standing in its way, the wave
spawner, the phase table, the upgrade economy and the bot are all running, none of them
has anything to do with it, and any of them could be the cause. So could the lane's
bend. So could the tower it walked past.

Twice in one week a number was read off a whole match and attributed to the wrong
cause. Once it was a formation turning; the cost belonged entirely to a different change
made at the same time. Once it was archers going blind; the pile-up it was blamed for
happened just as much with the rule switched off. **Both mistakes have the same shape**,
and it is not carelessness — it is what a measuring instrument with two hundred moving
parts does to whoever reads it.

## The bargain

A **scene** names the handful of mechanics it needs. It gets a world with exactly those
hung on it and nothing else, a short straight road, and a few bodies standing on it.

Then: **anything that moves is something the scene asked for.**

That is the whole idea, and the value is in the second half rather than the first. It
is not that the arena is small — it is that what a test did not ask for is **absent
rather than idle**. A test that runs the whole cast and merely does not look at most of
it is still being pushed around by the parts it is not looking at. A test that cannot
spawn a wave, because the wave spawner is not there, proves something.

## The three pieces

| | What it is |
| --- | --- |
| [The arena](../src/068-the-arena.info.md) | One straight lane, left to right. No bend, no stone, no junction, no bases. And the subset assembly: name your modules, get those and no others. |
| A scene | A file naming the mechanics, the ground, the bodies, and a sentence saying what should happen. |
| [The proving ground](../src/069-the-proving-ground.info.md) | The window. Ground, bodies, what each is doing, the caption. No chest panel, no roster, no badges, no clock. |

Run one with `./run-arena <scene>`, or `./run-arena <scene> headless` for the numbers
with no window. Both print the same figures, so a number seen in one is the same number
as in the other rather than two measurements that ought to agree.

## The rules of the thing

**Straight ground unless the test is about curves.** A lane's bend is real and has its
own instrument in [the formation sandbox](../tests/060-the-formation-sandbox.info.md).
A test about stepping round an obstacle that is also cornering has two candidates when
it fails, and the point of a small arena is to have one.

**Everything allied unless the test is about fighting.** Giving two groups different
teams to make them walk at each other also switches on every rule about enemies — target
selection, standing off, the frontline, combat — and then the picture is of a fight. A
pathing scene puts both formations on the same side and hands them opposite headings,
so nothing on the screen is anybody's enemy and nothing chooses a target.

**The mechanics list is on the screen.** The honesty of the whole arrangement rests on
being able to see which machinery made a picture, so the scene's declared modules are
printed above the ground. If a module is present for a reason that is not the obvious
one — the spatial grid lives inside the targeting module, so a scene about queueing has
to name targeting without anybody ever picking a target — the scene says so in a note
underneath, because a reader who sees "targeting" and assumes combat has been misled by
a true statement.

**Held on open.** A scene starts paused. The most useful moment when something is going
wrong is almost always the tick before it does, and a test that starts running the
instant it loads cannot be looked at then.

**A scene that reproduces a bug is a bug report anybody can open.** It goes in
`scenes/`, it is named for what it shows, and its caption says what *should* happen — so
that the file is a statement about the design and not only a demonstration of the
defect.

## What this is not

It is not a replacement for the invariants or the sandbox. Those assert; this shows.
A scene is looked at by a person, and the thing it is best at is the class of problem
where nobody yet knows what the right behaviour is — which is most of the interesting
ones, and exactly the case where writing an assertion first means guessing the answer
before seeing the question.

The two do meet: once a scene has settled what should happen, the assertion it implies
belongs in the invariants, and the scene stays as the picture of why.

## The cost, stated plainly

The arena's tick is **written out rather than borrowed**. It calls the same three
functions the real brain calls to march a body, in the same order, and that is a second
place in the project that knows marching is grid-then-plan-then-step. If the real one
grows a fourth step, this one will not have it and will quietly be testing something
else.

That is a real cost and it is the trade the arena makes everywhere. A test that
assembled the whole brain would not have it, and would not be able to tell you anything
either.
