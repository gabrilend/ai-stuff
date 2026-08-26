# Phase 3 — The Corners: progress

**Where the heat goes, and the plumbing that takes it. All eight blueprints
written, and as of the network solve, all eight finished.**

| ticket | blueprint | state |
|---|---|---|
| `301` | `020-heat-budget` | done |
| `302` | `021-working-fluid` | done |
| `303` | `022-face-microchannel-field` | done |
| `304` | `023-corner-parity-plumbing` | done |
| `305` | `024-flow-network` | done |
| `306` | `025-thermal-resistance-network` | done |
| `307` | `026-thermal-transient-and-throttle` | done |
| `308` | `027-external-loop` | done |

Sixty-eight constraints in the phase, all holding. `./run-demo 3` prints them
with the cube's plumbing solved underneath.

## The four findings

**The hot spot is not spreading resistance.** The phrase implies heat travelling
sideways to reach a cooled area, and here it does not have to — the cold plate
covers the whole die back and the channels are directly above, so getting out
vertically costs a fifth of a kelvin. The problem is that **only the channels
above the multiplier array are available to it**: a tenth of the wetted area
carrying seventy per cent of the heat. Twelve kelvin instead of two. It is a
floorplanning problem and `041` is where it is actually solved.

**The walking hot spot is thermally invisible, and `010`'s face ordering earns
nothing.** A multiplier region's time constant against its cold plate is three
milliseconds; a pipeline stage is a hundred and fifty microseconds. The array
reaches five per cent of its steady rise before the work moves on. The antipodal
ordering was chosen two phases ago on a thermal argument that does not survive
contact with a time constant, and the ordering is now free for something else.

**The parity argument became load-bearing.** `016` withdrew the claim that the
manifold is negligible — the rails are about a third of the loop. So what keeps
the flow even is no longer that the manifold is invisible; it is that no point of
either network is more than one edge from a port and no channel carries flow away
from a load. And that property is **unique**: any four corners work exactly when
no edge joins two of them, which is exactly when they are one side of the
bipartition. Feeding one face's four corners instead leaves a third of the
network doing nothing.

**The margin should buy the removal of a chiller.** A twenty-five degree inlet in
a twenty-two degree room needs a refrigeration plant. A fifty degree inlet needs
a radiator and a fan, and the junction goes to about ninety with room to spare.
Fifteen kelvin of junction temperature for several hundred watts and a
compressor is a good trade and it is not taken yet, because the temperatures
printed throughout the documentation assume the cold inlet.

## What the checker caught

**A helium leak rate has the dimensions of power.** Millibar litres per second is
a pressure-volume throughput, and comparing it against a reservoir emptying is
comparing a power to a volume flow. Dividing by the working pressure makes it a
volume flow, and then a hundred and sixty-six joints come to a few cubic
millimetres a year.

**Water cannot travel.** A cube may see minus twenty in transit. The constraint
failed outright rather than marginally, and the resolution — the cube ships empty
— puts a fill and purge step into two other blueprints.

## The three things the solve found

Both remaining tickets in the phase turned out to want the same missing thing: a
program holding the cube as data rather than as prose. `102` is that program, and
it produced three results nobody had predicted.

**The network is two and a half times the size the ticket estimated.** Twenty
branches across eight nodes was the guess, and it was the cube's own edges and
corners rather than its plumbing. The real object is fifty branches across
twenty-nine nodes: supply and return are separate networks sharing a geometry,
every rail carrying a plenum is two rails with a tap between them, and the corner
blocks are branches rather than junctions.

**The rail assignment is a real choice and most of the choices are worse.** Six
plenum pairs onto twelve rails gives five hundred and twelve arrangements; sixty
four obey every rule; **sixteen of those sixty-four distribute the coolant exactly
evenly and the other forty-eight leave one face five or six per cent short.** The
sixteen are the ones with a threefold rotation about a body diagonal — one fed
corner with all three of its channels tapped — which is the symmetry that makes
all six faces the same face. The forty-eight spread the plenums two and two,
which looks more balanced and is not. Nothing in `304`'s argument predicted this,
because `304`'s argument is about the network reaching everywhere and this is
about where the plenums hang on it.

**The hand-summed loop overstates the circuit by a quarter.** `dp_loop` follows
one path from a fed corner to a drained one and charges it for two whole rails.
The real manifold delivers to each plenum from both ends at once, so the rails
carry about half what the single path assumes. Eighteen point nine kilopascals
becomes eleven point four. The estimate was the conservative one, which is the
right way round for an estimate to be wrong, and `C-024-11` is what would notice
if it ever inverted.

**And the thermal chain now uses the worst legal wiring rather than the best.**
Building the junction temperature on a perfect distribution would make the whole
thermal budget depend on the plumbing being assembled to the drawing rather than
merely to the rules. `025` is given `f_worst_any`, the five and a half per cent
shortfall of the least even legal arrangement.

## What is still open

**The hot spot rests on a floorplan that does not exist** (`025`, `009` entry T1).
The multiplier array's area and power share are entered from `041`'s intention.
If the array is denser or hotter than assumed, the term grows in proportion.

**Nobody has asked how many channels can block** (`009` entry T2). A hundred and
seventy-three channels at a hundred and fifty microns, in a loop with a pump. The
filter specification in `027` is a requirement written in the imperative mood
rather than one derived from a blockage model.

**Fouling is not modelled at all** (`027`). The filter stops particles. Scale,
corrosion products and biological growth all have length scales comparable to the
channel and accumulate over the years `086` is claiming.
