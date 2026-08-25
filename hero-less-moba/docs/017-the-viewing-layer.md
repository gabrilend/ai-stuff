# 017 — The Viewing Layer

**Datapath document.** Covers the second program: the one that draws. What it is
allowed to read, what it is forbidden to do, and why the line is drawn where it
is.

## The rule

**The viewer reads world states and writes commands. It does nothing else.**

It does not hold game state of its own that the simulation would need. It does
not decide anything the simulation could decide. It does not write into the world
under any circumstances. Every arrow points one way:

    input  →  command queue  →  simulation  →  snapshot  →  viewer  →  screen

The payoff is that every bug has a side. If the frontline moved wrong, the viewer
is innocent, because it cannot move a frontline. If a health bar is in the wrong
place, the simulation is innocent, because it does not know what a health bar is.
In a game whose entire subject is a thousand small bodies interacting, being able
to cut the search space in half by asking one question is worth a great deal.

The second payoff: the simulation can run with no viewer at all, as fast as the
machine allows. Balance work is running ten thousand matches overnight and
reading a table in the morning. That is not possible if drawing is welded to
simulating.

## Snapshots

Two different objects have been called a snapshot in this project and they are
not the same thing. Naming them apart, because the collision already produced two
documents that flatly contradicted each other:

- **The viewer's frame** — what this section is about. Stamped locally at the end
  of every tick, read by the renderer, never sent anywhere.
- **The accepted sync** — positions and health only, published to every other
  machine about once a second by whichever peer's turn it is. Described in
  [players, teams, and commands](016-players-teams-and-commands.md).

The rest of this section is about the first one.

At the end of each tick the simulation stamps a **viewer frame**: a flat,
read-only copy of everything the viewer needs. Not the whole world — the viewer
has no use for cooldown timers, target generations, or pending damage.

It holds **your own team's** chest, slots, wallets, and sign-posts, and the
enemy's only as bodies on the ground. That is not the viewer being discreet: the
enemy's chest is not on this machine at all. See
[open questions](020-open-questions.md), F7.

| The viewer frame contains | Why |
| --- | --- |
| `tick` | To interpolate against. |
| Per soldier: x, y, facing, team, flavour, archetype, health fraction, alive | Everything drawn about a body. |
| Per soldier: the upgrades it was stamped with | Reading an enemy's build off their frontline is the only way to learn their arrangement. Enemy bodies carry this; enemy *chests* do not exist here. |
| Per structure: health fraction, alive, command radius | Towers and libraries. The radius is drawn for both teams — see [guard towers](007-guard-towers-and-their-guards.md). |
| **Own team only**: chest contents, slot assignments, transit marks, lock and objection state, boons | The panel. |
| Per lane: push depth, both teams' | The lane-pressure read. Ignored during a challenge. |
| **Own team only**, per player: resource, ceiling, hero count, teammate cursors | The player's own bar, and the presence channel. |
| **Own team only**, per sign-post: position and direction | Each team has its own three. The enemy's are absent from the frame entirely — not hidden, not present. See [sign-posts](013-signposts-and-lane-routing.md), F16. |
| Phase, surge timer, challenge state | The banner across the top. |
| Events raised this tick | Draws, kills, refusals, tower falls. Fires the popups. |

The viewer keeps the two most recent snapshots and interpolates positions between
them. It is allowed to be behind and is never allowed to be ahead — a viewer that
extrapolates is a viewer that shows things that did not happen, and in a game
where a player is judging a frontline by eye, showing a frontline that is not
really there is a lie that changes decisions.

## What the screen has to show

Roughly in order of how much a player looks at it:

1. **The three lanes and where the frontlines are.** The primary read. A glance
   should answer "which lane am I losing" without a number anywhere.
2. **The chest.** Unplaced upgrades, large and impossible to ignore. An upgrade
   doing nothing should be visually annoying.
3. **The slots.** What is in each lane, what is in each lane's towers, what is in
   the library, who locked what, what has been objected and by whom.
4. **My resource, and what I could buy with it right now.** Affordable heroes
   distinguished from unaffordable at a glance.
5. **The phase.** How long until the next surge; during a surge, how long left;
   during a challenge, where the monsters are.
6. **Refusals.** Every rejected command, with its reason, immediately.

The chest and the lanes are the two things a player is constantly moving their
eyes between, so they should be arranged so that a placement is a short drag and
not a trip across the screen.

## The camera: everything by default, zoom to inspect

**The default view is the whole map, always, and a player can push in to read
detail and pull back out.** *Settled; see
[open questions](020-open-questions.md), D7.*

The default matters more than the zoom. The entire design rests on a player being
able to judge three lanes by looking at them — that is what makes an upgrade
"legible from across the map," which is one of the three reasons the chest
replaced heroes in the first place. A view that starts anywhere but the whole map
breaks that, and hands the chest panel a job the map was supposed to do.

Zoom exists because there is now real detail worth reading. A soldier carries a
visible record of what it was stamped with, and reading an enemy's build off
their frontline is the only way to learn their arrangement at all — see
[the shared upgrade pool](009-the-shared-upgrade-pool.md). At whole-map scale a
soldier is a few pixels; you need to be able to lean in.

### One rule for the camera

> **Zoom reveals detail. It never reveals events.**

Anything a player must react to — a tower falling, a surge starting, a monster
appearing, a teammate marking an upgrade to move, a lock breaking, their own
wallet overflowing — has to be legible at the default view, without zooming and
without a camera move. Zooming in is a thing a player does when they have a
moment, not a thing the game requires them to do to stay informed.

The failure this prevents is the one every game with a camera has: a player who
is looking at the wrong place at the wrong time and is punished for it by
information they were never going to have. In a game where three people share one
chest, that failure would land on the whole team.

### And it should always be one press back

Returning to the whole map is a single, instant, unmissable action. A player who
has zoomed in should never be *lost*. If getting back to the default view is ever
a small navigation task, players will stop zooming in at all, and the detail this
camera exists to show will go unread.

## The drawing library is LÖVE

*Settled; see [open questions](020-open-questions.md), D1.*

It is already LuaJIT, so there is no FFI boundary between the viewer and the
simulation — the snapshot is read directly, in the same language, with no
marshalling. It brings a window, input, audio, and a sprite batcher for free, and
the sprite batcher is the one that matters: this game draws hundreds to thousands
of near-identical bodies every frame, and batching them is the only performance
question the viewer has.

The rejected alternative was an FFI binding to something lower-level, which is
more control over exactly how those bodies get drawn, in exchange for writing the
window, the loop, and the batcher before anything appears on screen at all. That
trade would be worth making if the drawing were unusual. It is not: this is
thousands of small sprites on a fixed view.

What comes with it, and is accepted: LÖVE's choices about how a frame works, and
LÖVE's distribution story.

**The terminal viewer from issue 109 stays.** It is not a stepping stone to be
discarded once there is a real window — it is faster to debug in, it works over
a connection where nothing graphical does, its output can be piped to a file and
diffed, and it keeps the viewing layer honest by existing as a second consumer of
the same snapshots. Two viewers means neither one can quietly become part of the
simulation.

The project's documentation is generated into browsable HTML pages under
`docs/HTML/`, sharing one stylesheet and a table of contents down the left side,
with every document reachable from every other. Where a document names a source
file, the link goes to that file's companion `.info.md` page. Where it names an
issue, the link goes to the issue.

That is the same separation again: the Markdown is the data, the HTML is a view
of it, and the view is generated by a tool rather than maintained by hand.

Related: [the simulation tick](003-the-simulation-tick.md) ·
[players, teams, and commands](016-players-teams-and-commands.md) ·
[the shape of the code](018-the-shape-of-the-code.md)
