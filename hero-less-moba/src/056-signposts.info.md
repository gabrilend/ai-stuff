# 056-signposts

The three objects in the world that decide where a body turns.

## What a sign-post actually is

**A lane swap on a timer, and the timer is the walk.** The ability to move a body
into a neighbouring lane, once, with a delay.

A body arriving at a junction takes the branch the sign points at, and **after that
goes straight on at every junction for the rest of its life**, whatever the next
sign says. That single rule is what keeps this from being a routing system — no
looping a body around the anti-diagonal, no chaining two posts to reach the far
lane, no policy that steers a body twice.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `begin(world)` | | — Plants one post per lane per team, at that lane's junction. |
| `cycle(world, team, lane, player)` | | The post, turned one step. |
| `consult(world, id)` | | The connector this body should take, or nil. |
| `check_junction(world, id)` | | `true` if the body just turned. |

## The record

`team`, `lane`, `node`, `branch` (0 for straight on, otherwise a connector id),
`options` (which connectors leave this junction), `set_by`, `set_tick`.

## Cycling, not toggling

A side lane's junction has **one** connector leaving it; the middle has **two** —
the top-left corner and the bottom-right. So a click cycles: straight on, then each
option, then back. On a side post that degenerates to a toggle, which is what a
player expects there.

The default everywhere is straight on, so somebody who never touches a sign-post
gets exactly the behaviour they would expect from a game that did not have them.

## Who obeys

**Hero units, and nothing else.**

- **Wave units ignore them completely.** Not an oversight: if waves could be
  rerouted, a team could feed two lanes into one and the lane structure of the map
  would be decorative. **Waves are the map's skeleton; heroes move across it.**
- **Guards never reach a junction**, being leashed to their tower.
- **Challenge monsters walk the centre** and nothing redirects them.

## No lock, no objection — and what that costs

Any player on a team may set any of their three at any time. They are cheap,
instant and reversible, and a negotiation layer over something undoable in one click
would be ceremony with no stakes under it.

What it costs is that a teammate can **silently redirect every hero you have
inbound**, which makes it the only unnegotiated change one player can make to
another's plans. So the change raises an event, the panel shows who set each post,
and the renderer haloes one that changed recently.

## The enemy cannot see yours

Not greyed out, not drawn without a direction — **not drawn.** Under the networking
model their routing is not on your machine at all, which is what makes the secrecy
real rather than polite.

So routing is concealed until it pays off: a team that has quietly pointed all three
junctions at the centre has committed every future hero purchase to the middle, and
the other side finds out when heroes start turning up there, several purchases late,
with the commitment already a wave or two deep. **The fog is made of walking.**

## One implementation note

The junction window is a body's **own speed**, not a fixed distance, so a fast hero
cannot step over the junction between two ticks and miss the sign — which would be a
silent failure of the only steering a player has.
