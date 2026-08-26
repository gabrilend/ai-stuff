# Open questions

Questions that surfaced while the rest of these documents were being written, and
which are mostly **not answered**. They are listed here so they can be worked
through one at a time rather than being quietly decided by whoever writes the code
first.

A phase with an unanswered blocking question against it is not ready to start.
Where a document states an answer to one of these, it states it as a proposal and
says so.

A question that gets settled is marked ANSWERED and **stays here**, with the
reasoning that settled it. It is not deleted. A list that only holds live
questions loses the record of why the dead ones died, and that record is what
stops the same question being reopened in six months by somebody who was not in
the room.

Each question carries the phase it blocks, so the order to work through them is
roughly the order of [the roadmap](015-roadmap.md).

---

## Blocking phase 1 — the world holds still

### 1.1 Is one world unit one foot?

[A thing in the world](005-a-thing-in-the-world.md) assumes it, which sets the
range at about four hundred miles and the precision at about a hundredth of an
inch. If the intended scale is a town rather than a dungeon, or a battlefield,
the constant changes and everything downstream still works. It is cheap to decide
now and expensive to decide in phase 5.

### 1.2 Does anything persist between sessions?

[The roadmap](015-roadmap.md) says no -- a session is a world file, a command log,
and then it is over. But a campaign is a sequence of sessions in a place that
remembers, and "the players burned down the tavern last week" is a normal thing
for a table to want. If the answer is yes, the snapshot format becomes a
long-lived format rather than a debugging convenience, which is a much stronger
constraint on it.

---

## Blocking phase 2 — the world can be seen

### 2.1 How coarse is the fog memory grid?

[Sight and what it remembers](007-sight-and-what-it-remembers.md) proposes one
world unit per cell. Coarser is smaller and remembers a corridor you only glanced
into; finer is exact and costs bits. The number is configuration either way, but
the default matters because it is what everyone will use.

### 2.2 Does a viewer with many bodies see the union, or switch between them?

A commander with six goblins: is their screen everything all six can see at once,
or the view from whichever one is selected? The union is the honest answer for
sight-as-security and it is what the documents assume. But it may play badly --
six overlapping cones is a strange thing to look at.

---

## Blocking phase 3 — the world ticks

### 3.1 Is the world continuously simulated, or turn-shaped underneath?

The question from [the vision](../notes/vision). [The tick](004-the-world-and-its-tick.md)
proposes that the world always runs, and that turn structure -- if a ruleset has
any -- is implemented as the ruleset refusing commands out of turn, rather than as
the world stopping. That keeps the two ideas separate and lets a system with no
turns work with no special case.

It has a cost worth stating: in a turn-based system, everything not currently
acting is standing perfectly still while the world runs anyway, which may look
worse than a world that is honestly paused.

### 3.2 What is the tick rate?

[The dynamic picture](012-the-dynamic-picture.md) assumes about twenty per second
and interpolation on top. Faster costs the host's CPU, mostly in the sight pass,
and buys tighter controls. Slower is cheaper and needs more interpolation. This
should probably be measured in phase 2's demo rather than chosen now.

---

## Blocking phase 4 — people connect

### 4.1 Why one port per participant, rather than one port and many sockets?

[The door and the private port](003-the-door-and-the-private-port.md) argues for
it after the fact: the kernel resolves identity, the outbound filter binds once
and cannot be misthreaded, and operations become legible. Those are real. The
counter-case has not been argued: one listening socket needs no port range,
crosses NAT without a conversation with a router, and has a dispatch that is
thoroughly tested in every server ever written.

This is the single most reversible-looking decision that is actually expensive to
reverse later, because the filter-binds-to-the-socket property is what phase 4's
whole security argument leans on.

### 4.2 What is in the `secret` field of a join request?

A shared password for the table? One password per participant? A public key?
Something the host reads out over voice chat when the session starts? The field is
thirty-two bytes and its contents are entirely undecided.

### 4.3 How large can a table get?

Sets the port range, the thread pool size, and how hard the sight pass has to
work. Six is a normal tabletop. Thirty is a convention hall. The difference
changes whether `SEES_REGION` is an optimisation or a necessity.

### 4.4 What happens when somebody's connection drops?

Their port is released and their scopes are unheld -- so does their character stand
there? Get driven by a GM? Vanish? And when they reconnect, do they get their old
port back, and does their fog memory survive, or do they re-explore what they
already saw?

Fog memory surviving a reconnect is the difference between a dropped connection
being an annoyance and being a disaster.

---

## Blocking phase 5 — the bridge and the browser

### 5.1 How is a thing actually drawn? — ANSWERED

**Animated SVG**, one self-contained file per sprite, composed and driven by the
renderer. Decided in [the sprite studio](017-the-sprite-studio.md).

It is left in this list rather than deleted because it was open for a while and
the reasoning is worth keeping where somebody looking for it will find it: vector
survives being scaled, tinted, and recomposed where a raster sprite does not; SVG
is text, so the encoder is string-writing and nothing is borrowed to produce it;
and an animated SVG can be *watched* in a browser as it stands, which is what makes
it rateable by a person who is judging a walk cycle rather than a still frame.

What remains open is downstream of it, and is [11.1](#111-does-the-terminal-renderer-draw-sprites-at-all)
-- a terminal cannot draw one.

### 5.2 May the bridge keep a local copy of the fog memory?

It would cut the bandwidth considerably: the server would send only newly-revealed
terrain rather than everything remembered. But it puts a piece of per-viewer state
outside the server, and the whole security argument rests on the server being the
only place that decides what a viewer has. Probably safe, because the fog is that
viewer's own memory and reveals nothing new. "Probably safe" is exactly the phrase
that should stop a decision from being made quietly.

---

## Blocking phase 6 — control is a dial

### 6.1 When a goblin patrol walks out of the forest and into the tavern, whose is it?

The question from [the vision](../notes/vision). Region membership is evaluated
from the thing's current region, so mechanically the answer is "the tavern's, the
moment it crosses". Whether that is wanted is another matter: the forest's
commander may have been walking that patrol for ten minutes with an intention, and
having it taken away at a doorway is a strange experience.

Alternatives that have not been argued: the patrol keeps its origin scope until
somebody hands it over; a thing can be in a list scope *and* a region scope, with
the list winning; the boundary crossing is a request the receiving commander
accepts.

### 6.2 Is "usually weaker but not always" a rule or a convention?

Whether the program enforces anything about the strength of a commander's bodies,
or whether that is entirely the GM's business when handing out scopes. If it is a
rule, it is a *ruleset's* rule, since the server has no idea what strength is.

### 6.3 Can a scope be handed over mid-session, and what happens to orders in flight?

A GM handing the tavern to a player who just arrived. Standing orders belong to
the bodies, not to the scope, so mechanically they would continue -- which means
the new commander inherits six goblins already walking somewhere for reasons they
were not told.

### 6.4 Does a player with a party of four drive all four, or one at a time?

The vision says a player controls "up to an entire party at once, but generally
not more". Four bodies driven simultaneously with one keyboard is not really
possible; four bodies given orders is the strategy-game interface; one driven and
three following is a third thing that is common in games and is not in the
documents at all.

### 6.5 Does `HIDDEN` hide a thing from other GMs?

With several GMs at one table, one of them may want an ambush the others do not
know about. Currently `MAY_SEE_HIDDEN` is a single bit and every GM has it.

### 6.6 Can a GM see what the players have seen?

Not the world -- a GM sees that anyway -- but the *fog*. "Which rooms have they
explored" is a question a GM asks constantly, and the data is right there. It is
also, faintly, a surveillance question about the other people at the table.

---

## Blocking phase 7 — the rules layer

### 7.1 What happens when a ruleset raises an error mid-tick?

The whole argument for embedding Lua rather than compiling rules in is that
somebody's homebrew should not take down the table. So: the offending hook is
abandoned, the tick continues, and a sentence goes somewhere a person will read
it. But *which* person -- the GM, everyone, a log file? And what happens to the
half-applied changes the hook had already requested before it failed?

### 7.2 Are stale ghosts shown?

When a viewer sees a goblin and walks away, is a faded goblin drawn at the last
place they saw it? [Sight and what it remembers](007-sight-and-what-it-remembers.md)
proposes this is the ruleset's decision, because it is a statement about how the
game handles uncertainty. That may be over-thinking it.

---

## Blocking phase 8 — content generation

### 8.1 What does the description language look like?

The five-stage pipeline in [content is generated](013-content-is-generated.md)
says what the stages do and says nothing about the syntax of the thing feeding
them. It is the part of the project most likely to become a language, and the part
where deciding by accident would be worst.

---

## No phase — questions about the whole thing

### 9.1 Is sound modelled at all?

Light is blocked by walls and this is the entire foundation of the fog. Sound is
the same shape of problem -- it travels, it is blocked, it goes around corners
differently -- and hearing something you cannot see is one of the best things a
tabletop can do. It is not in any document and not in any phase.

### 9.2 Can two people drive one body?

A scope is held by exactly one viewer, so currently no. Whether that should hold
for the case of a player who has stepped away, or two people sharing a character.

---

## Blocking phase 9 — the sprite studio

### 10.1 Which rating algorithm does a given table actually run?

Both are built. [The sprite studio](017-the-sprite-studio.md) says the choice is a
setting and that switching costs nothing because both write the same field. What
it does not say is what the **default** is, and the default is what nearly
everyone will use.

Rate-on-arrival suits a large generated library and gives a free, continuous
measurement of how far the machine's taste has drifted from yours.
Judge-then-curate gives a library every item of which a person has looked at, and
bounds it at one person's patience. They fail in opposite directions.

### 10.2 Who may re-tier a sprite during play?

Algorithm B has somebody changing a sprite's tier mid-session. Only the GM? Anyone
who can see the thing? The table by some agreement?

There is no leak in letting a player re-tier a sprite they can already see -- the
tier is about the `kind`, and they are looking at one. But a shared library that
any of six people can re-tier, mid-session, without discussion, is a different
social object from one the GM curates.

### 10.3 Is the pool per-table or per-project?

If a table's sessions each curate the same pool, the library becomes that group's
over a campaign, which is the appealing version. If the pool ships with the
project, in-play re-tiering is one person editing a shared asset for everybody who
ever uses it, which is a different thing entirely and probably wants to be a
local overlay on top of a shipped pool rather than an edit to it.

### 10.4 What are the categories, exactly?

Quality is discussed per-category and never globally -- nobody says the sprites are
bad, they say *the goblins* are bad. [The sprite studio](017-the-sprite-studio.md)
proposes that the categories are the `kind` families a ruleset declares. That
makes them the ruleset's to name, which means two rulesets have two different sets
of categories, which means a pool is not straightforwardly portable between them.

### 10.5 Does a machine grader that watches motion actually exist here?

Algorithm A requires something that rates every sprite on arrival, and a rater
shown one still frame of a walk cycle is rating an illustration. Whether the thing
doing the rating can watch an animated SVG at all is a practical question that has
not been checked, and if it cannot, algorithm A does not work as described and
algorithm B is the only one that does.

### 10.6 Does the studio ever regenerate a sprite that is in use?

A sprite is referenced by things in a live world. If the studio produces a better
goblin, does the running session pick it up, at the next session, or never? Never
is the safest and is also how a library stops improving.

---

## Blocking phase 10 — the second view

### 11.1 Does the terminal renderer draw sprites at all?

Phase 10 proves the split by building a second renderer against the same protocol.
But the protocol now carries vector sprites, and a terminal cannot draw one. Either
the terminal view ignores appearance entirely and draws glyphs by `kind` -- which
is honest and slightly weakens the proof -- or the appearance layer has a
representation the terminal can use, which is a constraint on
[the sprite studio](017-the-sprite-studio.md) that nothing currently states.
