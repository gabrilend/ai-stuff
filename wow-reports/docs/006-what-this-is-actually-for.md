# What this is actually for

The archive and the two simulators were described first and the destination
second. The destination changes what they are, so it is written down here.

## The destination

A player who is a floating invisible presence rather than a body, directing many
bot characters at once. The bots fight; the player commands. That is a different
game from World of Warcraft, which is the point - it is close enough to reuse
the server and far enough to be its own thing.

The obstacle is cost. A server running full combat resolution for every bot -
every swing, every tick, every aura expiring on its own timer - spends its
budget on characters nobody is looking at closely. Directing *many* bots means
combat has to get cheaper per bot, or the number of bots stays small and the
game the player wanted does not exist.

## The substitution

Combat gets replaced by its own prediction. Rather than resolving a fight
action by action, the arithmetic model computes what the fight would have
produced and that result is applied to the targets directly.

This is exactly the uptime-average model from the vision note, and every
property that made it a poor theorycrafting tool makes it a good runtime one:

| Property | As theorycraft | As a runtime substitute |
|---|---|---|
| No clock | cannot show a rotation | nothing to step, no events to queue |
| Arithmetic over averages | blind to sequencing | one multiplication chain per bot per interval |
| Scales to many characters cheaply | uninteresting | **the entire reason it is here** |

A squad of bots is a sum of rates applied to a health pool over an interval.
That is a handful of multiplications, not a scheduler.

## The gap becomes an error budget

Phase 7 was going to measure the difference between the event simulator and the
arithmetic model and call it "what the ruleset pays for sequencing well". That
measurement is unchanged. What it *means* is now different, and more useful.

The difference between the two models is the **fidelity error of the
substitution**. It is how wrong the cheap model is about a particular
specialisation, in a particular patch, expressed as a number.

That turns an open-ended engineering worry into a decision procedure:

- Measure the gap per specialisation.
- Where the gap is small, that specialisation's combat runs on arithmetic and
  nobody can tell.
- Where the gap is large, that specialisation either needs the expensive model,
  or needs a correction term fitted to the gap, or needs its design changed -
  and since this is a custom game, changing the design is genuinely on the table
  and is often the cheapest of the three.

The last option is the interesting one. A specialisation whose cheap model is
badly wrong is a specialisation that depends heavily on precise sequencing, and
a bot commanded from a distance was never going to sequence precisely anyway.
The measurement tells you which of the game's specialisations survive being
played by proxy, before a line of gameplay code is written.

## What the event simulator is for now

It never runs at game time. It is an instrument, used twice:

- It measures uptime, because with the outside log archive declined nothing else
  does, and the arithmetic model needs uptime as input.
- It is the reference the cheap model is calibrated against.

Built once, run offline, consulted forever. It is a laboratory, not an engine.

## Resolution and presentation are different layers

If the player is floating above watching bots fight, the bots must still appear
to fight, even though the outcome was decided by arithmetic that has no notion
of a swing.

So the outcome is decided by the cheap model, and the animation is a
performance that adds up to that outcome. The presentation layer is told "this
bot deals this much over this interval" and invents a plausible sequence of
visible actions summing to it. It must never be allowed to decide anything,
because the moment presentation feeds back into resolution the cost saving is
gone and the two models disagree.

This is the project's standing separation between generating data and viewing
data, appearing again at game speed.

## What can and cannot be carried to AzerothCore

AzerothCore emulates the 3.3.5a client. That is a hard boundary and it has to be
said plainly before anyone expects otherwise:

- **Content does not transplant.** A specialisation, spell, or item introduced
  after 3.3.5a has no identifier, no icon, and no animation in that client. It
  cannot be applied by patching a server, because the thing the server would be
  describing does not exist on the other end of the connection.
- **Numbers do transplant.** Coefficients, cast times, cooldowns, durations,
  resource costs, creature statistics, item statistics - these are values on
  entities that already exist, and they live in the world database and in the
  server's source, both of which the patch system already reaches.

So the archive is not a way to run a modern patch on an old server. It is a
**library of balance precedent**: fifteen years of how the designers tuned each
shape of ability, indexed by patch, available to draw from when deciding what a
number should be in a game that is deliberately not theirs.

Since this is a separate game with its own client, fidelity to any particular
retail patch was never the goal. Precedent is more useful than imitation, and it
is also the only one of the two that is actually achievable.

## Where the boundary between projects sits

Two repositories, one seam.

**This project** owns the archive, the extracted facts, the two simulators, the
calibration between them, and the viewer. It knows about numbers and their
history. It never touches a running server.

**The server project** owns the emulator source, the build, the bots, the
client, and the patch system that applies changes to them.

The seam is emission: this project *generates* patch scripts in the form the
server project already applies - the apply-and-unapply pairs, idempotent,
reverting cleanly, numbered and registered. Generating them is this project's
last phase. Applying them is the other project's ordinary business.

That split keeps the archive from growing a dependency on a server being
installed, and keeps the server from growing a dependency on the internet.
