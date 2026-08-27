# Phase 8 Progress — Six Players

**The goal:** everything that assumes more than one person. Networking, a lobby,
an opponent worth practising against, and the machinery for running the game ten
thousand times to find out whether any of it is balanced.

**Ends with:** the capstone — six people, two teams of three, one match from
lobby to library, on separate machines, recorded and replayed.

| Issue | | Status |
| --- | --- | --- |
| 801 | Reconciling across machines | not started |
| 802 | The lobby and commander selection | not started |
| 803 | A bot that places upgrades | a measuring bot, one brain per side |
| 804 | Ten thousand matches overnight | not started |
| 805 | A full match, end to end — **capstone** | not started |
| 806 | Three people can finally talk | not started |

**Blocking:** nothing.

**Carry into the work:**

- **Peer-to-peer, three channels, no permanent host.** Choices go immediately
  over TCP and are **never rolled back**. Continuous state — **positions and
  health only** — is published by one peer about once a second with the turn
  rotating. Cursors sync continuously.
- **Everything downstream of health converges on its own.** Deaths, wipes, draws,
  the chest: none of it crosses the wire.
- **Incoming values are checked for causality, not magnitude.** Only examine what
  differs; reject any difference no in-range body could have caused. It catches
  the impossible, not the improbable, and that is the accepted stopping point.
- **Doubles are fine.** No fixed-point rewrite, and the determinism test proves
  nothing about two machines.
- **A replay records accepted snapshots**, so replays are large rather than tiny.

**The question this phase exists to answer.** Issue 804 is the only thing in the
project that can tell us whether **the frontline actually moves.** The vision's
premise is that a lane-pusher with the heroes subtracted out stalemates, and
nothing in twenty-three documents proves the replacement layers unstick it. If
ten thousand matches show three lanes sitting at the midpoint, the design is
wrong, and the right response is an issue file rather than a patch.

**Still open:** cycle length; E3 through E7, including whether this ships
single-player — which decides how good the bot has to be and probably deserves
its own phase.

**Demo:** not yet built.

## Where the prototype got to

**Only 803, and only half of it.** There is a bot, it is the measuring kind — cheap,
deterministic and dull on purpose — and it plays a whole side rather than one seat.

It exists for the obvious reason and for a less obvious one. Ten thousand matches
need somebody to play them; but also, **without it a match does not demonstrate its
own premise.** Left alone the chest fills and nothing happens, because nothing is
placing it, so the one thing the design is about is the one thing an unattended
match never shows. That is not a stalemate anybody predicted — it is an empty chair.

Its whole policy is two lines: reinforce where you are losing, unless you are losing
nowhere, in which case press where you are winning. Stone gets every fourth
placement on a fixed rotation rather than a judgement, so both halves of the
placement decision reach the numbers. It takes the first boon offered, deliberately,
because whichever it preferred would become an invisible constant in every figure a
balance run produced.

Everything it does goes through the ordinary command queue on the ordinary tick. A
bot with a private path into the world would be a second door, and the point of the
first one is that there is only one.

**What it produced:** from one seed, both sides played, team 1 wins at about thirteen
minutes with 128 upgrades drawn and 9 still unplaced. Push depths of 7/7/2 against
0/0/5 — two lanes taken and one held. The first match this project has produced with
a shape somebody could describe afterwards.

**It sidesteps the hard problem and says so.** One brain per side, not three sharing
a chest. A teammate bot that places into lanes a person is also placing into,
respects their locks and decides whether to object is phase nine, and it is the part
that does not exist in the games this one is subtracted from.

**Nothing else in this phase is built.** No networking, no lobby, no overnight runs.
