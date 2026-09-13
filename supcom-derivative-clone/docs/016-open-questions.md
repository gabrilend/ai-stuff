# 016 — Open Questions

Every unresolved decision found while turning the vision into documents. This is
not a closing section and it is not decoration. **A phase whose questions have
not been worked through is a phase being built on a guess**, and the guesses are
labelled below as *working rulings* so that it is obvious which parts of the
documentation are the vision speaking and which parts are somebody filling a
gap.

The questions are meant to be gone through one at a time, with a person.
Answering one usually kills two or three others — and occasionally creates one.

**Answered so far: none.** Two are marked as directions set rather than
questions, and three are awaiting evidence that only running the thing can
supply. Entries are kept when answered rather than deleted, rewritten to record
the answer, what it settles, and what was rejected.

Each entry carries: what the vision says, the working ruling if there is one,
why the answer matters, and which documents change when it is answered.

**A through H are the shared groups and nothing else may use those letters.** An
issue that raises a question nobody outside it needs to see keeps it in its own
file under a letter of its own picking.

---

# Group A — Rules the vision genuinely leaves open

These change how the game plays. They are the ones worth arguing about.

## A1. Is the command tank the command truck?

**Vision:** "a command tank that flies a plane in a direction chosen by compass
wheel" and, later, "command trucks are 1 [hit]" and "few things can be moved,
like command trucks."

**Working ruling:** one unit, called the truck.

**Why it matters:** if they are two units, one is the player's stake and the
other is the plane's carrier, and the plane's carrier can be built more than
once. That is a different game with a different air war.

**Changes:** [008](008-the-command-truck-and-its-plane.md), [004](004-a-unit-and-what-it-carries.md), issue 210.

## A2. What does losing the command truck mean?

**Vision:** silent, beyond the truck dying in one hit.

**Working ruling:** the parent game's rule — a team whose last truck dies has
lost the match.

**Why it matters:** it is the win condition. The alternative is that a match is
won on territory, and the truck's death only removes the plane and the centre
that engineers build around.

**Changes:** [008](008-the-command-truck-and-its-plane.md), [001](001-what-this-game-is.md), issues 210, 110.

## A3. Does a shell track its target, or land where it was aimed?

**Vision:** silent. Infinite range with time-of-flight is implied by "some have
lower damage from far away."

**Working ruling:** a shot resolves against the unit it was fired at, at the
tick it lands, wherever that unit then is.

**Why it matters:** ballistic shells make long shots miss moving targets and
make the field a lead-your-target game; tracking shells make range purely a
matter of falloff and sight. They are different games at long distance.

**Changes:** [004](004-a-unit-and-what-it-carries.md), issues 205, 206.

## A4. What does a land unit do at the end of its pattern?

**Vision:** "the units don't listen after they've left the factory."

**Working ruling:** it holds where the pattern ends and fires at what it sees.
No chasing, no returning, no looping.

**Why it matters:** a pattern that loops is a patrol; one that holds is a siege.
The vision's factory-game framing reads as the latter.

**Changes:** [006](006-factories-and-patterns-in-the-sand.md), [004](004-a-unit-and-what-it-carries.md), issue 204.

## A5. Can a line be stopped, resumed, or demolished?

**Vision:** patterns cannot be redesigned; "everything can be queued."

**Working ruling:** a line can be stopped and resumed; a factory can be
demolished for a share of its mass; a pattern can never be changed.

**Why it matters:** without a stop, a factory drains resources forever; without
demolition, a bad pattern occupies its cell forever.

**Changes:** [006](006-factories-and-patterns-in-the-sand.md), issue 307.

## A6. How many players, and how many teams?

**Vision:** silent. Everything is described for "you" and "the enemy."

**Working ruling:** two teams, any number of players per team, one truck per
player. The prototype is one against one.

**Why it matters:** the roster, the menu, and the cloud are all per team; two
players on one team share them. That is either the co-operative game or a
mistake.

**Changes:** [005](005-territory-mass-and-energy.md), [011](011-other-players.md), issues 108, 704.

## A7. What is "improving territory"?

**Vision:** "mass comes with territory. Also you can assign energy and mass to
improving it."

**Working ruling:** a per-cell improvement level, bought with both resources,
that raises the cell's mass payment and is lost with the cell.

**Why it matters:** it is the only mass sink that is not a unit, and it decides
whether holding ground compounds.

**Changes:** [005](005-territory-mass-and-energy.md), issue 311.

## A8. Is the truck's plane one plane or two?

**Vision:** "they fly scout planes of their own design, free command tank unit
ability," and separately a plane that hunts enemy commanders with one missile.

**Working ruling:** one plane that scouts and carries one missile.

**Why it matters:** a free scout with no missile is a different economy of
information; a costly hunter is a different economy of risk.

**Changes:** [008](008-the-command-truck-and-its-plane.md), issue 210, the cloud's reports in 406.

## A9. What does an enforcer's upgrade do?

**Vision:** "the more they consume, the more they can upgrade."

**Working ruling:** each upgrade step raises health cap, damage, and the shield
sphere together, by catalogue amounts.

**Why it matters:** an enforcer that only grows tougher is a wall; one that
grows a bigger sphere is a mobile fortress for the tanks around it.

**Changes:** [009](009-enforcers-and-experimentals.md), issue 211.

---

# Group B — Numbers to be decided or measured

Not decisions about the rules; decisions about the knobs. Several of these are
awaiting evidence, meaning they are answered by running the thing.

## B1. The cost magnitudes against the ratios

**Vision:** land ten mass to one energy, air the reverse, sea ten and ten; and
also "most units cost between 40 and 70 mass and 120–400 energy."

Those two statements cannot both describe a tank. The ratios are treated as the
design and the bands as a magnitude sketch; the catalogue holds working values
and the tests assert the ratios only.

**Changes:** the catalogue, the balance ledger, issue 306.

## B2. Hits-to-kill for the helicopter and the frigate

**Vision:** tanks four, anti-air three, trucks one, enforcers six plus four. Silent
on the other two.

**Working ruling:** helicopter two, frigate eight.

**Changes:** the catalogue, issue 202.

## B3. The heal intervals per kind — **AWAITING EVIDENCE**

**Vision:** examples of seven, ten, and five seconds. Whether those produce a
match where healing matters is a proving-ground question.

**Changes:** the catalogue, issue 207.

## B4. Ticks per second

**Working ruling:** ten. Enough that a shell's flight is several ticks; few
enough that ten thousand matches overnight is a real number.

**Changes:** [003](003-the-tick-and-the-timers.md), issue 105.

## B5. The field's size and the shell's speed — **AWAITING EVIDENCE**

Together they decide how long a shot takes to cross the field, which is the
feel of infinite range. Measured, not argued.

**Changes:** the catalogue, issues 102, 205.

## B6. The claim time and radius

**Working ruling:** a claim completes after a small number of claim increments
of uninterrupted presence within a radius of two cells; an enforcer's radius is
four.

**Changes:** issue 112.

---

# Group C — The dunes and territory

## C1. Does slope slow movement, or only decide sight?

**Working ruling:** both. A land unit's speed scales down with the slope of its
current step.

**Why it matters:** if slope is free, ridges are strictly better routes; if slope
costs, the trough is fast and blind and the ridge is slow and seen.

**Changes:** [002](002-the-dunes-and-the-sightlines.md), issue 204.

## C2. Do units block sightlines?

**Working ruling:** no. Only ground blocks sight.

**Changes:** [002](002-the-dunes-and-the-sightlines.md), issue 103.

## C3. Where do thorns live?

**Vision:** "in the full game we'll have many tower types but for now treat them
like artillery."

**Working ruling:** a team-wide capacity with no position; damage lands on
whatever claimed the cell that flipped.

**Changes:** [005](005-territory-mass-and-energy.md), issue 310.

## C4. Does a contested claim reset or pause?

**Working ruling:** pause. The claim's start increment is kept while both sides
are present and the claim resumes when one leaves.

**Changes:** issue 112.

---

# Group D — The economy

## D1. What do engineers on energy duty do, exactly?

**Vision:** "four buttons to determine how many of your engineers get put toward
energy exploitation."

**Working ruling:** they raise energy buildings on held ground, nearest
hydrocarbon first, and operate what stands. Engineers off energy duty are build
power.

**Changes:** [005](005-territory-mass-and-energy.md), issues 302, 303.

## D2. Does the roster have positions?

**Working ruling:** no. Builders and engineers are counts with health, imagined
around the truck.

**Changes:** [005](005-territory-mass-and-energy.md), issue 304.

## D3. Is build power split evenly?

**Working ruling:** yes, across everything under construction.

**Changes:** issue 305.

## D4. Who finds a hydrocarbon?

**Working ruling:** a scout report or a completed claim on its cell.

**Changes:** issue 303.

---

# Group E — The air war and the truck

## E1. Where is the cloud, and is there only one?

**Working ruling:** one cloud, above the field's centre.

**Changes:** [007](007-the-cloud.md), issue 401.

## E2. Can the cloud be shot from below?

**Working ruling:** no; it is above every gun's sight.

**Changes:** [007](007-the-cloud.md), issue 405.

## E3. What counts as "suitably unbothered"?

**Working ruling:** in the cloud, not in a round this tick, not defensive.

**Changes:** issue 406.

## E4. Does a bombing run damage, claim, or both?

**Working ruling:** both: damage to what stands on the cell, and a claim on it.

**Changes:** [007](007-the-cloud.md), issue 406.

## E5. Where does air strength come from?

**Vision:** "depending on how they upgrade the planes."

**Working ruling:** a per-team upgrade table bought with energy; a plane copies
its team's total at birth.

**Changes:** issue 407.

---

# Group F — Other players

## F1. Lockstep or reconcile? — **DIRECTION SET**

Lockstep. The reasons are in [011](011-other-players.md): commands are rare,
everything is already queued, and the wire is a radio.

## F2. Are doubles safe across the two targets? — **AWAITING EVIDENCE**

Answered by running one match on a computer and on the handheld and comparing
hashes. If not, positions become fixed-point integers.

**Changes:** [003](003-the-tick-and-the-timers.md), issues 104, 801.

## F3. The input delay in ticks

**Working ruling:** five ticks on a computer; the handheld's is pending its
measured latency.

**Changes:** issues 702, 707.

## F4. What the handheld's radio gives — **AWAITING EVIDENCE**

Design pending details on soren-ds wifi capabilities: whether ad-hoc mode works
on the chip, bandwidth, latency, loss, largest datagram, peer count, battery.
Listed in [011](011-other-players.md).

**Changes:** issues 707, 806.

## F5. Encrypt the wire, or not?

**Working ruling:** not. Nothing in a match is secret.

**Changes:** issue 703, 707.

---

# Group G — The handheld

## G1. C boxes, a Lua userland, or generated boxes? — **DIRECTION SET**

Hand-ported C boxes with the Lua as the reference, checked by the
reproducibility test. The other two are recorded in [012](012-the-handheld.md)
and are not closed, only not chosen first.

## G2. Which four buttons are the energy menu?

**Working ruling:** a drawer's radial menu. A question for a person holding the
device.

**Changes:** issue 803.

## G3. Which screen shows what?

**Working ruling:** top wide, bottom close and touched.

**Changes:** [012](012-the-handheld.md), issue 802.

---

# Group H — Found while building

Reserved for questions that surface once there is source. Writing the program is
itself a review, and it turns up disagreements between documents that reading
them against each other cannot. No entries yet.
