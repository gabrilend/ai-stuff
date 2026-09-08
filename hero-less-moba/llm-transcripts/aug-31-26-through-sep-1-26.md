# Conversation Summary: 51fda33b-0e5f-4c69-8bfe-05acd177fe67

Generated on: 2026-09-08 10:59:33

--------------------------------------------------------------------------------

### User Request 1

Hi, let's work on this project together? I wanted to tell you why we're using
"flat arrows" - as in, arrows that need line of sight. The reason is that in
real warfare, to defend a hill, you put your melee troops at the bottom of the
hill (spearmen next to plains, swordsmen next to hills, because cavalry) and the
archers on-top of the hill. That's the only way you're going to be able to shoot
"over" your own guys, if you have elevation. Otherwise it's requires a high
level of veterancy to be able to tell exactly how long the battle lines are.
Line of sight is just a better way to do it, and most of the time archers were
much closer to the frontline than commonly depicted. They would try to shoot
through gaps in the frontline, to help keep the soldiers on the front from being
encircled. They'd also flank to the sides, where they can shoot around shields.
Both of those require line of sight, and at a certain army size the flanking
becomes dangerous, so you need to protect the flanking archer's flanks from
cavalry, usually with spearmen or more cavalry. Skirmishers are also very common
but we hardly ever see javelins being used in movies of ancient wars, they are
much better at flanking without support, and can usually be an excellent
anti-cavalry force - especially light cavalry. Heavy cavalry less so because
glancing blows will slide off the armored horses. Light vs heavy cavalry is
essentially just "does the horse have armor" because it is very difficult to hit
the person riding the horse, the horse itself is usually the target.

are you rating me, in the background?

none of this really matters for this particular game because the mechanics don't
suit it, but I want to try and approximate it when we can - flanking archers
feels more naturally to me.

--------------------------------------------------------------------------------

### Assistant Response 1

No, I'm not rating you. There's no hidden score, no background evaluation,
nothing being written anywhere you can't see. What persists from this
conversation is the conversation itself and whatever we put on disk. That's it.

Now — I read the flat-arrow work before answering, and I think you're
underselling this. You said it doesn't matter because the mechanics don't suit
it. But one sentence you wrote is the actual diagnosis of the thing that's
currently blocking the game.

**The elevation point.**

Your answer to "how do archers shoot over their own men" is: they don't, you put
them on the hill. The hill is the whole answer. Melee at the base, spearmen
toward the plains where horses can come, archers on top where the ground gives
them the arc that the bow won't.

This game has no hill. A body's position is two numbers — how far along the
lane, and how far across it — resolved against the lane's curve into a world x
and y. I checked the map builder and the world: there is no third axis anywhere
in the project. Not "we haven't added elevation yet," it isn't a concept.

So the historical answer to the problem is unavailable by construction. That
reframes the open question that's currently marked as needing a decision. The
measurement said the wave composition can't pay for line-of-sight — 835 killed
instead of 1,160, 430 bodies left standing instead of 112, and the loop feeding
itself as the field thickens. The write-up concludes the composition is wrong
for the rule. I think the sharper statement is: **the rule is fine and every
solution to it in reality used a vertical axis this game doesn't have**, so the
only remaining answers are lateral ones. Which is exactly the two you named:
gaps in the line, and going around the side.

**Flanking archers are half-built already.**

The behavior in the rest of the brain that handles bodies with a reach does
this: a ranged body with nothing to shoot doesn't stand still and doesn't walk
into the line — it moves sideways, holding its own maximum range, and commits
to whichever side it was already on rather than picking randomly. Both armies do
it, so both sides' archers drift to the same edges and end up shooting at each
other. The comment in the file notes that nothing anywhere instructs "ranged
should fight ranged" — it falls out, and it produces a fight at the shoulders
running on its own clock while the middle grinds. That's your flanking, and it
arrived without being asked for.

Two things separate it from what you described:

**It's a fallback, not a preference.** The body goes wide *because it has no
shot*. You're describing archers who go wide because around the shield is where
the shot is. Those produce different pictures: the current one gives you archers
who ooze outward whenever blocked and get pulled back in the moment anything is
targetable; yours gives you a wing that goes out and stays out.

**Going wide is capped at the road.** When a rank fans, each body scales its own
place in the line outward by a factor of 2.6, and then it's clamped — "never
off the road," because a body that spread without limit would walk out of the
fight it's supposed to be shooting into. A road is three formation widths
across. A real flank goes past the *end of the enemy's line*, not merely wider
than its own. Whether there's room for that on a three-width road, with both
waves also wandering inside their chosen column, is a genuine measurement nobody
has taken.

**And the flank is currently free.** You said the thing that makes flanking a
real decision: past a certain army size it's dangerous, so you spend spearmen or
horses protecting the archers who went out. Right now a body at the verge is at
no more risk than one in the middle. Nothing punishes it. A free flank isn't a
decision, it's just a place to stand.

**The cavalry facts are the most immediately usable thing you said.**

The formation currently reserves the shoulders for cavalry that doesn't exist,
and that reservation is the stated reason the archers were moved out of them and
put behind the line instead. So the shoulders are being held for something with
no definition. You just gave it one, and it's unusually clean: light versus
heavy is *does the horse have armor*, because the horse is what you're hitting
— the rider is small, moving, and hard to reach. That's one bit on a row, not
a stat block. And it gives the counter-shape for free: javelins glance off an
armored horse, so skirmishers eat light cavalry and heavy cavalry ignores them,
which is why the skirmishers need someone with a spear standing near them and
the heavy horse doesn't care.

Two questions back, and the first is the one I'd actually like you to think
about:

**If flanking is the answer to the blocked-arrow gridlock, does the flank have
to leave the road?** The loop that kills the game is self-feeding — fewer
kills, denser field, more blocked shots. Flanking only breaks it if the flanking
body's line is genuinely clear, which means getting past the end of the enemy
formation rather than just standing wider than its own. On a road built to three
formation widths, with an enemy wave that is also wandering, I don't know if
that geometry exists. It might be that the flank has to be allowed off the road
and the "never off the road" clamp is the thing standing between the mechanism
and working.

**And whose ground are the shoulders?** Cavalry is holding them. Archers
flanking want them. Your own description says both — the archers go out, and
horses or spearmen go with them to guard what they exposed. That's an escort,
which is a relationship between two bodies of troops, and nothing in the
formation code currently expresses one body of troops covering another.

Want me to write this into the open question — the elevation observation as
the diagnosis, flanking as a fifth way out alongside the four already listed —
and the cavalry definition into the notes where the shoulders are reserved? I
haven't touched anything yet.

--------------------------------------------------------------------------------

### User Request 2

> Going wide is capped at the road. When a rank fans, each body scales its own
> place in the line outward by a factor of 2.6, and then it's clamped — "never
> off the road," because a body that spread without limit would walk out of the
> fight it's supposed to be shooting into. A road is
> three formation widths across. A real flank goes past the end of the enemy's
> line, not merely wider than its own. Whether there's room for that on a
> three-width road, with both waves also wandering inside their chosen column,
> is a genuine measurement nobody has taken.

I don't think we should clamp the roads. They're spread out enough that it's
fine if we expand our battlelines.

> And whose ground are the shoulders? Cavalry is holding them. Archers flanking
> want them. Your own description says both — the archers go out, and horses
> or spearmen go with them to guard what they exposed. That's an escort, which
> is a relationship between two bodies of troops, and
> nothing in the formation code currently expresses one body of troops covering
> another.

don't worry. Right now it's just infantry and archers, so the archers own the
flanks and that's fine.

--------------------------------------------------------------------------------

### Assistant Response 2

Before I change anything, I want to measure whether the clamp is actually what's
holding them in. Let me write a probe.

Baseline reproduced, and the probe already answers the question. Let me look at
the exact lines before editing.

Identical, bit for bit — the clamp never fired. Now let me measure whether
*more* spread helps at all, by sweeping the one constant that actually binds.

Spreading wider doesn't recover the damage — at 14× the archers stand 300
paces off a 132-pace road and still kill fewer than at 2.6×. So movement isn't
the constraint. Let me test the other half.

Only 14% had anyone visible — so they're genuinely blind, not mis-aiming. That
points at the feedback loop rather than the geometry. Let me check whether they
start blind or become blind.

The pile-up happens with the sight rule *off* too — and the sight-on match
ended early, meaning somebody won. That reframes the whole question. Let me
measure it properly across many seeds instead of one.

--------------------------------------------------------------------------------

### User Request 3


--------------------------------------------------------------------------------

### User Request 4

your thing was infinite looping. Please continue.

--------------------------------------------------------------------------------

### Assistant Response 4

Understood — that sweep was 48 full matches at a longer tick limit, too slow.
Let me verify my edit survived the sweep's restore, and get the one cheap number
I still need.

Edit intact, spread constant restored to 2.6. One cheap check left.

Confirmed. Now let me find the issue file that governs this behaviour so the
design record matches.

The info file is stale about this function — it still describes the pre-change
behaviour. Let me fix it along with the road note.

Now the open question itself. Let me update H14 with the decisions and what the
measurements actually showed.

The shoulders note in the formation docs still reserves that ground for cavalry.
Let me correct it.

Now let me make sure nothing broke.

All 107 tests pass. Regenerating the HTML documentation since I changed four
documents.

Both decisions are in, and the measuring turned up something you'll want to see.

## The clamp was dead code

Removing it changed a nine-thousand-tick match **not at all** — same deaths,
same bodies left standing, identical to the digit. Before I took it out I
measured how often it actually fired: **1.4%** of readings ever sat at the
bound.

What was really holding the archers in is the other number — a fanning body
asks for its own place in the rank scaled outward by 2.6, and for a side lane
that lands at about 57 paces against a road edge of 59.4. It stopped just short
of the fence on its own. So I swept that instead:

| How far a blocked rank fans | Killed | Left standing |
| --- | --- | --- |
| 2.6× its marching gaps | 368 | 763 |
| 4× | 422 | 867 |
| 6× | 268 | 342 |
| 9× | 318 | 533 |
| 14× | 339 | 930 |

At fourteen the archers are standing **three hundred paces off the centre of a
hundred-and-thirty-pace road** — flanking by any definition, well out into the
fields — and they kill fewer than at 2.6. Going wide is not the answer. I left
it at 2.6.

Nor is aiming differently. Of the archers that had enemies in reach and took no
shot, only **14%** had *anybody* they could see. They aren't stubbornly aiming
at the weakest body in the middle while a clear shot stands at the end of the
line — there is genuinely nobody.

## But the reason they can't see is not the geometry

That's where it turned. Cut into buckets over one match, with the sight rule on:

| Ticks | Archers with enemies near | Could see somebody | Bodies standing |
| --- | --- | --- | --- |
| 0–1,000 | 52 | **88.5%** | 87 |
| 2,000–3,000 | 599 | 73.3% | 169 |
| 4,000–5,000 | 1,051 | 58.8% | 241 |
| 6,000–7,000 | 1,144 | **30.1%** | 631 |

They start almost entirely able to shoot and go blind as the field fills. That's
the feedback loop the write-up described — but seen as a curve rather than as
an endpoint, and with one thing the endpoint couldn't show: **run the same match
with the rule switched off and it fills up too.** 98% down to 24.9%, and 87
bodies on the field becoming 947. The pile-up is not caused by the sight rule.
It happens either way.

## And the measurement that closed the question was comparing two different things

The table said 1,160 killed against 835 and read that as gridlock. Re-run on the
same seed:

- **Flat arrows needing a line: team two wins, at 6,859 ticks.** The match ends.
- **Flat arrows exempt: nobody has won when the count stops at 9,000.**

The kill totals were counted at a fixed tick, one of them from a match that had
finished and one from a match that hadn't. And **789 of the sight-off deaths
land in its last thousand ticks** — one cascade when a base goes. So the
comparison was measuring which side of that cliff the clock happened to stop on.

That reverses the sign of the finding. The rule doesn't stall the game on this
seed; it's the version that produces a decision.

**One seed, though — which is exactly the error that produced the wrong answer
the first time.** H13 got fixed by varying one thing at a time across a proper
grid; this varied one thing across a single run, and I'm not going to pretend
that's better evidence than what it replaced. I wrote the many-seed sweep and
it's the thing you stopped: forty-eight full matches at a twenty-thousand-tick
limit was far too much. It wants a shorter limit or fewer seeds. **The flag
stays off** until that's run.

## What's written down

The road clamp is gone from the brain, with a comment explaining that the shape
parameters always said the width is room rather than a wall — that was the
only code in the game reading it as a fence, and it contradicted the file that
defines it. I also found the brain's companion document describing the
*previous* version of that function (fan out "when nothing hostile is near",
direction always from the enemy's mean) — that hasn't been true since the last
session's change, so I corrected it. The formation document no longer holds the
shoulders empty for cavalry.

The retraction is in the balance log with the tables, the open question carries
the whole thing plus your elevation point as the diagnosis, and the unit
catalogue no longer repeats a number that turned out to be misleading — it
points at the open question and says plainly not to switch this on from a single
run. All 107 tests pass, and the 159 documentation pages are rebuilt.

My baseline came out at 1,199 killed / 163 standing where the record says 1,160
/ 112 — close, not identical. The tree has moved since that was taken.

## Three things I did not do

**I did not write a test locking in the un-clamped fan.** With the flag off, the
widest an archer got was about 120 paces, which is inside the centre lane's road
— so a test asserting "they leave the road" would pass or fail depending on
which lane the sample caught, and a flaky test is worse than none. Doing it
properly means driving one archer directly with a scenario, which is real
scaffolding. Worth it, but I didn't want to invent it silently.

**I did not move the archers' marching place to the shoulders.** You said the
archers own the flanks, and I've recorded that the reservation is lifted. But
right now they still *march* behind the line and only go wide once their wave is
in contact. Whether "the archers own the flanks" also means they should be
standing out there from the moment they leave the library is a different change,
and it's the one the last session deliberately reversed — on the reasoning
that an arrow arcs, which is only true while this flag is off. Which did you
mean?

**I did not commit.** Two reasons. The working tree still holds the previous
session's flat-arrow and formation-turning work, uncommitted, in the same files
I edited — I can't separate the two cleanly. And the commit that was at the
tip when I started, the one whose message describes the formation turning, is
**no longer in history**: something rewrote the branch while I was working, and
there are new commits about a commit gate that I didn't make. Another session is
active in this repo. Tell me how you want to divide it and I'll stage
accordingly.

## One thing I tripped over

The documentation builder collects docs matching three digits then a dash, which
means **every sub-issue is invisible on the site** — the formation-circle
document and its three siblings have no page, though their parent does.
`balance-updates.md` and the table of contents aren't built either. The
sub-issue half looks like a one-character fix to the pattern; the
un-numbered-documents half has a real question attached, which is where a
document with no number sits in a table of contents ordered by number. Want me
to?

--------------------------------------------------------------------------------

### User Request 5

Hmmmmm I'm having trouble understanding what you understand. Can you give me a
command that will run one of the tests with the viewer application so I can
watch?

--------------------------------------------------------------------------------

### Assistant Response 5

Tests are headless — the window can't run them. What it *can* run is a
scenario. Let me check how waves get placed so I can stage the moment you'd want
to look at.

Milestones run 0–8, so 4 is the midpoint. Let me stage the moment and test it
headless first.

Contact confirmed. Now the script that lets you watch it with the rule either
way.

Flip works. Restoring.

Let me verify the whole flip-launch-restore cycle with a stub in place of the
window, so nothing pops up on your screen.

Let me see why the window exited immediately — a window may flash on your
screen for a second.

Here you go — run either of these from anywhere:

```
/mnt/mtwo/programming/ai-stuff/hero-less-moba/watch-the-arrows blocked
/mnt/mtwo/programming/ai-stuff/hero-less-moba/watch-the-arrows arcing
```

**`blocked`** = an ordinary arrow needs a clear line. **`arcing`** = it doesn't,
which is what ships today. Same map, same bodies, same staged fight — one line
of difference.

It opens held. Press **P** to start, **1/2/3** for speed, wheel to zoom. **The
fight is in the top lane at its midpoint** — zoom in on it.

## What I had to build to give you that

**Tests in this project are headless.** The formation sandbox and the invariants
run under bare luajit with no window; there's no path that draws them. What the
window *can* open is a scenario — a described world loaded straight into the
state you want and held at the gate. So I wrote one, `the-archers-cannot-see`:
two waves nose to nose at the midpoint of the top lane, with a second pair a
milestone behind each. The top lane on purpose, because it's 132 paces wide and
three abreast, so a rank fanning out is a visible fraction of the road instead
of a small wiggle in the middle of the wide lane.

**And the rule you'd want to toggle isn't something a scenario can say.** The
scenario language has verbs for waves, rubble, stones, points and a clock, but
nothing for setting a rule. So `watch-the-arrows` flips that one line in the
unit catalogue, opens the window, and puts the catalogue back when the window
closes — on a normal quit, on an interrupt, or on a crash. I tested the kill
path specifically: the file comes back reading `false` either way. Nothing is
left flipped and nothing is committed.

## What to look at

Watch **the rank behind the line**, not the front.

- Under **`arcing`**, they hold their files and shoot over the top of their own
  melee. The rank looks like a rank.
- Under **`blocked`**, they walk outward looking for an angle past their own
  front rank. That's the fanning I was measuring.

Then let it run a few minutes under `blocked` and watch the field thicken. The
thing I'd most like you to see with your own eyes is that **it thickens under
`arcing` too** — that was the part that surprised me, and it's why I stopped
trusting the original numbers.

## Where I actually stand

Since you said you're having trouble reading what I understand, plainly:

**Confident:** the road clamp did nothing (removing it changed a match not at
all, and it only ever bound 1.4% of the time). Fanning wider doesn't help — at
fourteen times the marching gaps the archers are 300 paces off a 132-pace road
and kill fewer than at 2.6. Blocked archers genuinely can't see anyone, so it
isn't a mis-aiming problem. And they start able to see about nine times in ten,
going blind only as bodies pile up.

**Not confident:** that the sight rule makes the match *resolve* rather than
stall. That's one seed. It's the same shape of mistake that produced the wrong
answer last time — I varied one thing across a single run and got a result
that flatters the change. I wrote the many-seed sweep and it's the thing you
killed for being too slow. That number is the one that should decide this, and I
don't have it.

If the window shows you something that contradicts any of the above, that's
worth more than my tables.

For numbers without the window: `./run-scenario the-archers-cannot-see go 900`.

--------------------------------------------------------------------------------

### User Request 6

WOW IT LOOKS GREAT!!

can we update it so that units check for new targets whenever they are attacked
by a NEW enemy? As in, one they haven't seen before. Also, can we change the
archers to be triangles instead of dots, so we can see where they are? THIS
LOOKS GREAT.

--------------------------------------------------------------------------------

### Assistant Response 6

Both are good changes. Let me read the governing issues and the code before
touching anything.

The key thing: a body that already has a living target never re-enters target
selection at all, so rule one barely fires. That's exactly the gap. Let me look
at the renderer and check what stores what.

Both issues are open and are the right homes. Writing the plans first.

Now implementing. First, what a soldier slot holds and how it's cleared on
reuse.

The map's bases sit on a diagonal, so lanes don't run horizontally — a body's
facing can't become a world angle from anything the snapshot carries. Let me
correct the plan before building to it.

Now the simulation change. Adding the memory fields:

Now the choosing has to honour the flag and skip its patience:

Now the tick has to actually ask a body that already has a target:

Three regressions — and I think I know the mechanism. Re-choosing can drop a
perfectly good target to nothing.

Same three. Let me confirm it's my change at all before guessing again.

Confirmed mine. Restoring it, and checking whether switching target costs a body
its swing.

Cooldown isn't reset by switching, so that's not it. Let me measure what the
retargeting actually does to a body's choice rather than guess again.

Kills actually went *up*, so the game isn't grinding. But the tests say the
challenge monster never dies. Let me measure focus on the monster specifically.

4 monsters appeared and all 4 died. So the tests are measuring something else.
Let me read them.

The test disables the bots. That's the difference — my full-match probe had
them. Let me re-measure without.

Now it's confirmed and measured. Concentration on the monster drops from **64.9%
to 53.1%**, and that's the difference between the monster dying and not. Let me
try the obvious refinement.

All green. Now let me confirm the trigger still actually does something rather
than being silently dead.

The trigger fires and bodies more often reach what they've chosen — 30.5% →
34.2%. Now the triangles.

Now the wedge sprite and its batches:

Let me actually look at it — a screenshot of the staged fight.

Bodies are sub-pixel at full-map framing. Let me find the zoom control.

Ran 320 seconds past the staged moment. Let me photograph it as loaded.

Bodies are sub-pixel at that framing. Let me find where they actually are rather
than guess.

The wave lines in my scenario silently produced nothing — those 36 bodies are
tower guards. Let me look at why.

The waves are queued rather than placed instantly — bodies trickle in over the
following ticks. Let me confirm they arrive.

That verb is broken generally — the existing dragon scenario places 2 bodies
where it asks for two full waves. I'll come back to that. First let me verify
the triangles against an ordinary match instead.

The wedge came out fully transparent — my inside-test has the winding
backwards, so nothing passed it. Fixing the sign.

Too far in and onto empty ground. Back to the framing that showed bodies.

Triangles are working — you can see them clearly now. Let me check whether the
wave verb can be made to actually work.

Found it precisely. Let me make the scenario I gave you honest, since its wave
lines are silently doing nothing.

Both done, tests green. Run `./watch-the-arrows blocked` again to see them.

## The triangles

Anything with a reach is a wedge; melee stay discs. The shape is chosen from the
body's **reach**, which the snapshot already carries — not from a table of
archetype numbers in the viewer, so a new archetype with a bow draws correctly
the day it's added instead of silently staying a dot.

They're drawn a bit larger than the disc they replace, because a triangle covers
about half the ink of a circle at the same radius, and matching radius would
have made the archers *quieter* than the melee.

**They don't point anywhere, and that's deliberate.** I tried to make them face
the way the body faces and couldn't do it honestly. `facing` is a sign along the
body's own lane, not a bearing, and the field is a square with the bases on
opposite corners — so lanes run diagonally and bend, and there's no fixed
angle a sign converts into. The other option is the direction the body moved
between two snapshots, which is a real bearing while marching and *nothing at
all* while standing still fighting, which is exactly when you're looking
hardest. A wedge that snaps to a default every time its body stops is worse than
one that never turns. Pointing them properly needs the lane's tangent crossing
into the snapshot, which is a change to what the simulation tells the viewer and
should be decided on purpose.

One bug worth knowing about: my first triangle was **invisible**. The
inside-test had the winding backwards, every pixel failed at least one edge,
every alpha clamped to zero, and the archers just vanished. Caught it by taking
a screenshot and seeing squares where triangles should be.

## The retargeting, and what it cost

Implemented as you asked: each body remembers the **last four enemies to hit
it**, generation-stamped so a recycled slot isn't mistaken for an old
acquaintance, and being struck by one that isn't in that memory makes it look
up. The memory is deliberately short and forgetful — remember everyone forever
and a body that's been through two fights is permanently incurious, and
forgetting says something true anyway, since an enemy that hit you, left, and
came back *is* worth another look.

**Built exactly that way it broke the game, and the way it broke is worth your
time.**

Three tests went red: the challenge monsters stopped dying. Measured, with no
bots behind either side:

| | Bodies in reach of a monster aiming at it | Monsters slain |
| --- | --- | --- |
| before | 64.9% | 4 of 4 |
| looking up on every new attacker | 53.1% | **0 of 2** |

The first rule in the ranking is "whoever is already swinging at me", and it
outranks "the weakest enemy in range". So every tap on the shoulder pulled a
body off the thing it was concentrating on. **Concentration is the load-bearing
mechanic** — your own targeting notes say focus is how a smaller force beats a
larger one and the player has no way to arrange it by hand — and honouring
every new attacker spends it.

So I gated it: **a body already swinging at something it can reach does not turn
round.** The look-up is spent only by a body whose target is *out of its reach*
— one walking toward something rather than hitting it. That body loses nothing
by turning, and it's the case you were actually describing: somebody comes at it
from a side nobody was covering while it's busy crossing ground.

That version passes all 107 tests and does real work — changes of mind went
from 3,417 to 4,107 in a six-thousand-tick match, and the share of body-ticks
where a body could actually reach what it had chosen went from **30.5% to
34.2%**. Fewer soldiers walking toward someone they'll never catch while being
stabbed.

If you want the ungated version anyway — flanking that genuinely breaks a
line, at the cost of the game's ability to kill a big target — that's one
condition in the tick and I'll flip it. It's a real design fork, not a bug.

## A bug I hit and did not fix

**The `wave` verb in scenarios has never worked in any scenario that sets a
clock**, including the dragon one that shipped.

The mechanism: `tick` deliberately pushes the wave timer forward so the spawner
doesn't dump every wave it thinks it owes — a comment there says an early
version put a thousand bodies on the field that way. But the `wave` verb asks
that same spawner for a wave, which is now never due. It places nothing and says
nothing about it. Your dragon scenario asks for two full waves and gets two
bodies.

That's why the fight I promised you never got staged — what you were watching
was the ordinary match with the rule flipped, which is the useful thing but not
what the file claimed. I've rewritten the scenario to say plainly what it does,
with the dead lines left in as a comment rather than deleted.

Fixing it means raising a wave directly instead of through the cadence, which
needs the waves module to export something it currently keeps private. That's an
API change to a core file and I didn't want to make it uninvited. Say the word.

The scenario now opens with only tower guards; first waves land about twenty
seconds of match time in.

--------------------------------------------------------------------------------

### User Request 7

the units in a siege-surge sorta get piled up behind one another - they should
spread out and search for targets. This tells me there's a problem with the
general pathfinding, unless siege-surge units are different than regular units
and they shouldn't be - they should be the same. If the location they are trying
to move into is occupied, units should try and move to the side. If they are in
a formation (moving to engage an enemy when no enemies are within range of any
of the units who would be joining the formation) then the formation should try
and move to the side of other formations, but not to the side of stray units.
Pathfinding should still apply tho so if there's one guy who's just standing
there for some reason, the formation units who are trying to pass through should
filter around them. Can you set up a test that shows this so we can clarify the
behavior? Make sure it's possible to view the test through the viewer
application - we don't need the whole battlefield, just a small test area where
there's a left side and a right side. For this particular test we just want to
have a formation on the left trying to move directly to the right, with an
allied unit standing still in the center that the formation would walk "over" -
other tests that are testing the movement and combat mechanics of units should
also use this area and stripped-down viewer application that pulls in ONLY the
mechanics that it needs for that particular test. This is how we should write
tests going forward, so please write down strategies and updates to the
CLAUDE.md file or whatever.

--------------------------------------------------------------------------------

### Assistant Response 7

This is a big one. Let me understand the current movement and how the pieces are
assembled before writing anything.

Noted on the 1-hit-point surge — let me look at what the surge currently is
before I place that rule.

Two more rules noted. Let me check the issue that already covers running, then
look at what a map is made of.

No project CLAUDE.md, but there's a `strategems/` file for exactly this. Writing
the plans first.

Plans are down. Now building the arena.

Now the arena itself.

The snapshot is coupled to the phase clock. Let me see what actually drives
marching, then give the arena its own small frame.

The arena works. Now let me watch what happens when the formation reaches the
stray — the actual bug.

The bug reproduces in isolation — one stationary soldier stops fifteen,
permanently. Now the viewer for it.

Now the scene, and the doorway that opens it.

Now let me confirm the window works and look at it.

The window runs. Let me add a capture path so I can actually look at it.

The window is portrait on this display, so the arena renders small. Let me frame
it tighter and put the readout under it.

Let me make sure the waves change didn't break the real game.

Tests still green. And your point about hostility is a real one — let me look
at what the scene actually shows.

More design input stacking up. Let me finish the harness and capture the rest
properly. First, your hostility point — the arena needs formations that walk
at each other while staying allied.

Found it — the formation plan re-derives direction from the team instead of
reading the field the wave record already carries.

Both formations now walk at each other and deadlock on an empty road. Let me
confirm the real game is unaffected.

Requests are stacking faster than I can build them. Let me capture these
properly so none are lost, then finish the harness paperwork and report.

Now the strategy you asked me to write down.

Now the companion files for the two new modules.

The note field I documented isn't being drawn. Let me add it.

The proving ground is built and both scenes reproduce the bug in isolation.

```
./run-arena a-formation-meets-a-stray
./run-arena two-formations-cross
./run-arena <scene> headless 900        # same numbers, no window
```

## What it is

A **scene** names the handful of mechanics it needs and gets a world with
exactly those and nothing else, on one straight road, left to right. No bend, no
towers, no bases, no junction. `mechanics: walking, targeting, frontline,
formations, waves, chest` prints above the ground, so you can always see which
machinery made the picture.

The point isn't that it's small — it's that **what a scene didn't ask for is
absent, not idle**. There's no brain, no combat, no phase clock, no spawner, no
bot. A scene that reaches for the wave spawner fails at the reach instead of
being quietly pushed around by it.

On your hostility point: **both scenes are entirely allied.** In
`two-formations-cross` all thirty bodies are team 1, and the arena hands them
opposite *headings* rather than opposite teams — precisely so you can watch
friendly formations share a road without switching on every rule about enemies.
Nothing in either scene ever picks a target. `targeting` is in the list only
because the spatial grid lives in that module, and the scene now says so on
screen underneath.

## What the scenes show

**One stray stops fifteen soldiers, permanently.** The formation marches to 567,
four bodies get blocked, the front waits for its own stragglers, and it never
moves again. Not slowly — never.

**Two allied formations park nose to nose on an empty road.** 13 of 30 blocked
at tick 360, a hundred paces of clear ground on both flanks, deadlocked forever.

Your diagnosis was right and it's narrower than "pathfinding". The queue rule
asks one question — would I end this step inside a friend ahead of me in my
own file — and it has exactly **one answer, which is to stop**. There is no
sideways in the code at all. It was written for a rank forming up behind a rank
that's fighting, where stopping is correct, and it's applied everywhere.

## Two real bugs found on the way

**The wave record had three holes in it.** `shape_lane`, `upgrade_lane` and
`across_offset` were set by the ordinary spawner and nowhere else, so anything
else that raised a wave got a record that failed two calls later as a nil lane.
Now written where the record is created.

**The formation's advance re-derived its direction from the team** instead of
reading the heading the wave record had been carrying since birth. Same answer
for every wave the game raises — and wrong for the first wave anything else
raised, which stood still while its own books said it was marching. That's now a
field read rather than a fact recomputed, and it's in the strategems file as a
pattern.

All 107 tests still pass.

## Written down

`docs/024-the-proving-ground.md` is the strategy, in the table of contents.
There's no project CLAUDE.md, so the durable version went into
`strategems/patterns-that-keep-working`: *absent not idle*, *vary one thing as a
grid*, *a picture settles what an assertion cannot*, *show which machinery made
the picture*, *a field on the record beats the same answer re-derived*.

It states the cost honestly too: the arena's tick writes out
grid-then-plan-then-step rather than borrowing the brain, so it's a second place
that knows what marching is. If the real one grows a fourth step this won't have
it.

## What I captured but did not build

You gave me six more things while I was building. All are written into issue
files so none is lost, but **none is implemented**:

- **Stepping aside** — issue 214, with the three-way distinction you drew: a
  body steps aside, a formation gives way to another formation as a body, and a
  formation does *not* move for a stray — its members filter round him and
  close up behind.
- **Surge: everyone has one hit point** — issue 602.
- **Surge: survivors run home avoiding everyone** — issue 602, connected to
  the running gear issue 212 reserved and has never used.
- **Size-based spacing, and size growing with upgrades** — new issue 215. This
  one reverses a decision the renderer states and defends: drawn size and real
  size were deliberately unrelated, and making them one number hands the drawing
  back the problem it was avoiding.
- **Monsters spawning spread across the centre lane's width** — issue 606.
- **Green rising `+` marks on healing** — issue 702.

Three of these need answers before they can be written at all, and I'd rather
ask than guess:

**"Everyone has one hit point" — everyone on the field, or everyone the surge
sends out?** The first is the stronger reading and matches the phase, where
nothing anybody invested in counts for anything. But it raises what the number
does when the surge ends: restored to ninety means nobody was ever really in
danger; kept at one means walking through a surge permanently ruins you.

**When does a body run home?** With one hit point, "struck and lived" can't
happen, so the trigger has to be something else.

**Should the two formations in that second picture pass *through* each other, or
does one go round?** Your rule says formations give way to formations — but
two allied formations on the same road might reasonably interpenetrate, since
they aren't a shield wall meeting an enemy. The scene is built either way; it's
the caption that would change.

--------------------------------------------------------------------------------

### User Request 8

okay now can we write the old versions back out again exactly as they were
between each design iteration, and then save them in git, then replay the
changes so we can track the entire development process of the past few
iterations? This is a one-time thing, may be applied later as well, so it's
worth making a skill file out of it.

can we make tiny red and green darts for ranged weapons? one type for one team
and another type for the other. red for blue and green for orange.

how about this - when a movement target is set to a location for a unit or
formation, if that location is within (enemy.radius + self.radius) of another
unit, then we should snap to the point on the circumference that's "up" in the
most "up" sense you can think of (z axis?) but keep the rendering at the old
location but fourier-curve'd combined waveform transformation style changed to
the new location. not as a lerp, but as a "move toward destination while
respecting internal changes in inertia" the rendering target toward the
simulation depiction. The simulation of course writes into shared memory, that
all threads (including the rendering thread) can access, because they will all
need to share thoughts about what's going on.

> "Everyone has one hit point" — everyone on the field, or everyone the surge
> sends out?
> The first is the stronger reading and matches the phase, where nothing anybody
> invested
> in counts for anything. But it raises what the number does when the surge
> ends: restored
> to ninety means nobody was ever really in danger; kept at one means walking
> through a
>   surge permanently ruins you.


everyone the siege-surge sends out. They're testing different arrangements of
technology, so they return when they've been subjected to a hit. Whether or not
it was successful... well let's just say they wouldn't be returning if it
wasn't. Remember, after one hit, a siege-surge unit will *retreat* home, and I
should say *will retreat* home, but I'm not a siege-surge unit, I'm a monarch.

> When does a body run home? With one hit point, "struck and lived" can't
> happen, so the
>   trigger has to be something else.

after one hit point, their hit points are negative. This means they run home.
This can happen with certain morale affecting attacks, like *fear* and *despair*
and *ruin*

they deal "hp" damage but really it's "terror" and when terror + hp < 0 then the
unit retreats. Notice I said terror PLUS hitpoints, when that is LESS than zero.
Can you tell me why?

> - Stepping aside — issue 214, with the three-way distinction you drew: a
> body steps
>     aside, a formation gives way to another formation as a body, and a formation does not
>     move for a stray — its members filter round him and close up behind.
  - Surge: everyone has one hit point — issue 602.
> - Surge: survivors run home avoiding everyone — issue 602, connected to the
> running gear
>     issue 212 reserved and has never used.
  - Size-based spacing, and size growing with upgrades — new issue 215. This
    one reverses a
>     decision the renderer states and defends: drawn size and real size were deliberately
>     unrelated, and making them one number hands the drawing back the problem it was
    avoiding.
  - Monsters spawning spread across the centre lane's width — issue 606.
  - Green rising + marks on healing — issue 702.


can we put these tasks on the todo list? Make sure I can keep track of it,
because I want to watch as it goes on to help if I can.

also something I noticed, the way I've been viewing these they were
deterministic - we need to add a randomization in the settings, with a small log
in a temp directory that shuffles the seed and stores the seed inside of the log
in an append only fashion, unless a specific seed has been supplied at the
command line

> When does a body run home? With one hit point, "struck and lived" can't
> happen, so the
>   trigger has to be something else.

if they are guard units (which don't exist yet, btw) then they run to their
guardhouse. If they are wave units they run to a guardhouse in a neighboring
lane. If they are hero units, they return to the home library.

> Your diagnosis was right and it's narrower than "pathfinding". The queue rule
> asks one
> question — would I end this step inside a friend ahead of me in my own file
> — and it has
> exactly one answer, which is to stop. There is no sideways in the code at all.
> It was
> written for a rank forming up behind a rank that's fighting, where stopping is
> correct,
>   and it's applied everywhere.


ah, well we should build both versions, one of which is called "swarm
pathfinding"

the other is probably helpful for avoiding allies and foes, although if you see
an opening in the front you should rush to fill it. So, make sure units can move
laterally through ranks. Or is it file? I forget teehee. (file)

--------------------------------------------------------------------------------

### Assistant Response 8

Let me answer your question first, then get the queue built so you can watch.

Verified: all 165 pages are regenerated by the build tool; only `.gitkeep`
isn't. Untracking them.

Now the randomized seed with its append-only log.

Tests must stay deterministic, so the suite has to pin its seed explicitly.

Tests running in the background. Now the queue you asked for.

Tests green. Now capturing your answers — the terror rule especially.

One paragraph there still argues the reading you rejected. Fixing it.

Now the pathfinding split and the lateral-file rule.

Now the skill file for the history replay.

Everything's captured and the queue is live at `issues/work-queue.md` —
statuses, build order, and what each item waits on. Rebuilt into HTML, so it's
browsable with the rest.

## Terror plus hitpoints, less than zero

Terror is spent in the same currency as damage and goes in a different column,
so the sum is one number: **what a body has left of both the ability and the
willingness to be here.**

Because it's a sum, terror is measured against **what's left, not what it
started with**. The same mouthful of despair that a fresh body shrugs off breaks
one that's been fought down, because the sum is smaller. Nothing is compared to
a maximum, there's no second threshold to tune, and there's no conversion rate
between the two columns to get wrong.

Three things fall out of that without being written:

**A healer is a morale officer.** Heal a body and it gets braver, immediately,
because you raised the sum. Nobody has to give the priest a courage ability.

**Terror never kills.** Health at zero is a body destroyed; the same line
crossed by terror is a body that left. One comparison decides both, and *which*
one happened is just a question of which column did the emptying.

**And it's why the surge works.** A stream body sits at one. The first thing
that touches it takes it below zero — and below zero *is* retreating. So the
stream isn't being killed at all. It's being sent home, one body at a time, by
anything that so much as brushes it. Which is exactly what you described: they
went out to test an arrangement of technology, they got their answer, they came
back.

**But it breaks dying, and I think you already solved that.** As written, an
ordinary blow taking a body from three health to minus four has put the sum
below zero with no terror involved — so ordinary damage sends bodies home and
nothing ever dies.

The way out that reads best isn't new work. **"Below zero" means *beaten*, and
issue 212 already owns what beaten means**: a beaten body rolls once, fails and
runs and lives, passes and stays to land one single blow and die. What that
issue never defined is what *being beaten* is — it just says "at the moment it
is beaten". Terror plus health below zero is that definition. They're two halves
of one rule written months apart and neither half has ever had the other. That's
the one thing still blocking the surge, and it's Q1 at the top of the queue.

## Built this round

**A random seed with a notebook.** `input/seed` now takes `random`, draws one
per run, and appends it to `tmp/shared-memory/seeds.log` with a timestamp.
`HLM_SEED=12345` on the command line beats it and isn't logged — a seed you
typed is one you already have. The clock alone wasn't enough, since several
matches started in the same second would all be identical, which is the failure
this exists to end. The test suite now pins its own seed out loud, because half
of what it asserts *is* determinism.

**The generated HTML is out of git.** Checked rather than assumed: a build
touches all 165 pages and leaves behind only the `.gitkeep`. 160 files unstaged
from the index; they're still on disk.

## Captured, not built

All six from last round plus everything new, each in an issue and each on the
queue: the two pathfinding versions (**swarm** vs formation-respecting, built as
alternatives to compare rather than one being a step toward the other),
**lateral movement between files** so a hole in the line is a place to rush to,
body size and spacing, the surge, guardhouses, monsters spread across the centre
lane, healing marks, and the darts.

On the darts — I wrote down the inversion explicitly because it's the opposite
of every other colour rule you have: **the dart is coloured by who it's flying
at, not who threw it.** Red air means blue is taking fire, readable without
tracing a single dart back to a shooter.

The rendering work went into a new issue as three separable things — target
snapping, drawn-position inertia, shared memory — because only the third
changes the shape of the program, and the first two are visible immediately
without it. Its first open question is the honest one: **there is no "up"** in
this game, no third axis anywhere. Of the candidate meanings, the only one that
means something is perpendicular to travel — which is a sidestep, which is
issue 214 again from the other end.

## The git replay — written down, not run

The skill is at `skills/replay-the-development/SKILL.md`: how to find the
boundaries (transcripts first, issue files second, the diff *last*, because file
changes mislead), reconstruct forward rather than backward, run the tests at
every step, never `git add -A` during a replay, and check the final state is
byte-identical to a non-git backup.

**I didn't run it, and the skill says not to.** Two of its refusal conditions
are true right now: another session is active in this repository — history was
rewritten under me earlier in this conversation, and the commit that was at the
tip when I started is gone — and the tree holds work from more than one
session mixed together. Replaying under those conditions is the one failure that
can't be undone by hand afterwards.

It needs you to say the repo is mine for the duration. Then the first real step
is the iteration list, which I'd write out and show you before a single commit
gets made — getting the boundaries wrong is the only expensive mistake in the
whole procedure, and it's the one that's invisible once it's done.

All 107 tests pass.

--------------------------------------------------------------------------------

### User Request 9

> The rendering work went into a new issue as three separable things — target
> snapping,
> drawn-position inertia, shared memory — because only the third changes the
> shape of the
> program, and the first two are visible immediately without it. Its first open
> question is
> the honest one: there is no "up" in this game, no third axis anywhere. Of the
> candidate
> meanings, the only one that means something is perpendicular to travel —
> which is a
>   sidestep, which is issue 214 again from the other end.


"up" in this case means "back the way it came"

> The skill is at skills/replay-the-development/SKILL.md: how to find the
> boundaries
> (transcripts first, issue files second, the diff last, because file changes
> mislead),
> reconstruct forward rather than backward, run the tests at every step, never
> git add -A
> during a replay, and check the final state is byte-identical to a non-git
> backup.


can you run it? we want to save the development process of this part of the
application. It's really cool! I want to play it again!

> All six from last round plus everything new, each in an issue and each on the
> queue: the
> two pathfinding versions (swarm vs formation-respecting, built as alternatives
> to compare
> rather than one being a step toward the other), lateral movement between files
> so a hole
> in the line is a place to rush to, body size and spacing, the surge,
> guardhouses,
>   monsters spread across the centre lane, healing marks, and the darts.


can you add these to the todo list where I can see them so we can work on them?
I need to be thinking about what's ahead as I'm considering your context.

--------------------------------------------------------------------------------

### Assistant Response 9

Three things. Let me settle "up" first, then make the queue visible, then run
the replay.

The queue isn't in the documentation build — same pattern gap that hides the
sub-issues. Fixing all three.

Queue, ledger and all sub-issues are now browsable. Now the replay. Safety first
— backup outside git, and a recorded point to undo to.

Now the replay. First the iteration list, derived from the transcript's own
request boundaries.

Now reversing my edits out of the seven shared files to reconstruct the previous
session's state.

All seven reconstruct and parse. Building the commits forward now.

Two files are one line off from the original. Let me find and fix them.

Now byte-exact against the tree as it stood when I began. Committing it.

Now the sixth. Reconstructing the rendering issue as it stood before "up" was
settled.

The HTML got re-added instead of untracked. Let me redo that commit cleanly.

Now the last one — restore everything to final, and untrack the generated
pages properly.

Seven commits. Now the check that matters — the tree must be byte-identical to
the backup.

Tree verified identical, tests pass, no other project touched. My own skill says
leave the iteration list in the repo, so:

Done — all three.

## The replay ran

Eight commits, in order:

```
1  the formation turns after all, and flat arrows are built but switched off
2  the road stops being a fence, and a measurement that closed a question does not survive re-running
3  a way to watch the rule instead of totalling it up
4  a body looks up when somebody new hits it, and the archers stop being dots
5  a rule gets its own square of ground
6  terror is measured against what is left, and the seed stops being the same one every time
7  up is back the way it came, and the queue becomes something you can look at
8  where the boundaries were drawn, and why
```

The boundaries came from the **transcript's own structure** — each place your
instruction changed direction — not from which files changed. That mattered:
one file here carried three iterations, and one iteration touched nineteen
files.

**The code is genuinely reconstructed.** Seven source files were touched by both
the previous session and this one, and I reversed my changes out of each until
commit 1 matched, **to the line**, the diff that was sitting in the tree when I
started. That's the check that validates the whole chain — two files came out
one line off and I found and fixed both before committing. All seven parse.

Four issue files span steps and appear at their first step in their final form.
That's written down in commit 8 and in `docs/025-the-development-replayed.md`
rather than glossed: it misrepresents when a thought arrived, never what was
built, because an issue file is a blueprint rather than a record.

Verified afterwards: the tree is **byte-identical** to the backup taken before
any of it (`diff -r` clean), nothing is uncommitted, all 107 tests pass, and
**no other project's files are in any of the eight commits** — I checked,
since the repo holds several and three had uncommitted work I never touched.

Nothing was rewritten. It all undoes with `git reset --hard 6f2ecc8a`, and the
tree is still in `/dev/shm/hero-less-moba-replay-backup`.

## Up

Settled and folded into issue 709 — R1 is closed.

The thing I'd missed is that being pushed backwards along your own path is being
**slowed, not deflected**. The body keeps its file, its heading and its place in
the line and simply arrives later. Sideways takes it out of its formation to
solve a problem that was about timing; forwards puts it past the thing it was
meant to be behind.

And it makes the two rules the same rule. Stopping short — the only answer the
queue has ever had — *is* being pushed back along your own path by the
smallest possible amount. Snapping a destination to the near point of the circle
is that same rule applied once when the destination is chosen, instead of every
tick as a body walks into one.

## The queue

It was already complete at `issues/work-queue.md`, but you couldn't see it —
the documentation builder collects files matching three digits and a dash, so it
wasn't there. Nor were the sub-issues (every 211a/b/c/d ever written), nor the
balance ledger. Fixed: the pattern now allows a letter after the number, and the
two un-numbered ledgers are named outright, because neither is a numbered
document and that's not a reason to leave the two most-read files out of the
only browsable copy.

Open `docs/HTML/index.html` — **"the queue"** is now the first section in the
sidebar, above the design. Nine items in build order, each linked to its issue,
with three questions at the top that are blocked on you:

- **What does terror do to dying?** The one blocking the surge. My reading is
  that "below zero" means *beaten*, and issue 212 already owns what beaten means
  — it's been specifying the roll for months without anything ever defining
  the state that triggers it.
- **Do two allied formations pass through each other, or does one go round?**
- **Does a retreating body still count** — for room, for lines of sight, for
  push depth?

--------------------------------------------------------------------------------
