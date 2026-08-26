# 035 — The cell, and the array around it

```meta
phase  | 5
issues | 502
```

Three numbers everything else needs: how much area a bit takes, how fast it can
be read, and what reading it costs.

## Why static and not dynamic

A dynamic cell is a fraction of the area and would give several times the
capacity in the same volume. It is not used, and the reason is one paragraph
because it is the first question anybody asks.

**Refresh** costs bandwidth, and bandwidth is this machine's scarce resource.
**A dynamic read destroys the row and writes it back**, and at forty terabytes a
second that write-back is a large fraction of the core's power budget. **And a
row-buffer miss is not predictable**, while `053`'s schedule depends on transfer
times being so.

The trade is capacity for bandwidth, and this machine exists to have bandwidth.

## Areal density, derived rather than asserted

This is the most optimistic number in the project and it should be built up in
the open.

```drawing
from a bitcell to a megabyte per square millimetre [not-dimensioned]

   bitcell area at the node        [a_cell]
        ÷ array efficiency        [eta_array]     decode, sense, wordline
   = area per bit in an array     [a_bit_array]   drivers, redundancy
        ÷ tier overhead           [eta_tier]      through-stack vias, test,
   = area per bit on a tier       [a_bit_tier]    ECC routing, seal ring
   = areal density                [d_areal]
```

**The arrangement this assumes matters as much as the numbers.** It is a
*dedicated array tier* carrying bitcells and local decode and nothing else, with
sense amplifiers, redundancy logic, error correction and the interface on a
separate logic lamina beneath. A conventional cache achieves a third of this
because it carries all of that on the same die.

For a sanity check that is not a datasheet: a shipping stacked cache die at an
older node reaches about one and three quarter megabytes per square millimetre
with a similar arrangement. The figure derived here is above it, and the gap is
the node — which is honest, because static memory has very nearly stopped
scaling and the gap is therefore small.

## The three outputs

**Areal density** feeds `034`'s capacity chain. **Access time** feeds `034`'s
clock and `053`'s schedule — and it is not one number, but a latency to first
data and a rate for the rest of a burst. The sieve cares almost entirely about
the second, because its transfers are enormous. **Energy per bit** feeds `020`,
split into read, write and retention.

## Read stability

`029` needs the margin by which the array rail must exceed the logic rail. It
comes from here: the static noise margin of the cell at the low end of its
voltage tolerance, the high end of its temperature range, and the worst process
corner — **all three at once**, because that is when it fails.

## Symbols

```symbols
a_cell        | um^2/bit | measured | 0.0199 | area of one six-transistor static memory cell at the chosen node. The unit is area per bit rather than area, which sounds pedantic until a density derived from it is compared against something and turns out to be a reciprocal area with no information in it
eta_array     | 1    | measured | 0.55   | share of a memory array that is cells rather than decoders, sense amplifiers, wordline drivers and redundancy
eta_tier      | 1    | given    | 0.60   | share of a tier's area that is array rather than through-stack vias, test structures, correction routing and the seal ring
t_access      | ns   | measured | 0.75   | latency from a read being issued to the first bits arriving at the tier's port
n_macro_tier  | 1    | given    | 4096   | memory macros on one tier
w_macro       | bit  | derived  | w_tier_port / n_macro_tier * n_macro_tier | bits a tier's macros deliver together per cycle; equal to the port width because the port is what they are sized to fill
SNM_cell      | V    | measured | 0.155  | static noise margin of the cell at the low voltage, high temperature, slow process corner
SNM_required  | V    | given    | 0.075  | the least static noise margin that is considered safe against the soft error rate in 040

a_bit_array   | um^2/bit | derived | a_cell / eta_array     | area one bit occupies inside an array
a_bit_tier    | um^2/bit | derived | a_bit_array / eta_tier | and on a tier, once everything a tier needs besides array is counted
d_areal       | MB/mm^2 | derived | 1 / a_bit_tier | areal density. The unit conversion from bits per square micron to megabytes per square millimetre is the notation's job, not the author's, which is the second reason area per bit had to carry its bit
d_areal_ref   | MB/mm^2 | measured | 1.78 | density a shipping stacked cache die reaches at an older node with a comparable arrangement, as a sanity comparison rather than a target
t_cycle_core  | ns  | derived | 1 / f_core                  | the core's cycle time, which the access time must fit inside
E_core_write  | pJ/bit | measured | 0.55 | energy to write one bit into a core tier
E_core_ret    | pJ/(bit*s) | measured | 20.0 | retention leakage per bit at the operating temperature: about twenty picowatts a cell, which is what makes an idle machine cost anything at all. Per bit per second, so it is a power per bit and not an energy
P_core_leak_d | W   | derived | E_core_ret * C_core_raw | retention power of the whole stack, derived from the per-bit figure
dV_read_need  | V   | derived | SNM_required * 2 - SNM_cell + dV_read_marg | how far the array rail must sit above the logic rail for the cell to keep its margin while being read
```

## Constraints

```constraints
C-035-1 | t_access < t_cycle_core * 2   | the array must deliver first data within a couple of cycles, or the latency in 052 grows and 048's prefetch has to run further ahead
C-035-2 | SNM_cell > SNM_required       | the cell must keep a usable noise margin at the worst corner. All three worst conditions at once, because that is when it actually fails and a check at any one of them is a check of nothing
C-035-3 | d_areal < d_areal_ref * 2     | the density claimed must be within a factor of two of what a shipping part with the same arrangement achieves at an older node. Static memory has nearly stopped scaling, so a claim far beyond this would be a claim about a process nobody has
C-035-4 | P_core_leak_d ~= P_core_leak  | retention power derived from the per-bit figure must agree with the figure 020 assumed. Two routes to the same watts
C-035-5 | eta_array * eta_tier > 0.25   | the two efficiencies together must leave at least a quarter of the tier as cells. Below that the tier is mostly overhead and the dedicated-array argument has stopped being true
C-035-6 | E_core_write > E_core_bit     | writing costs more than reading, which is true of static memory and catches the two being swapped
```

## What is still open

**The tier overhead is a `given` with nothing behind it.** Six tenths of a tier
being array is a guess that includes through-stack vias whose count `036` has not
settled, and the whole capacity of the machine is proportional to it.

**Access time is one number for a forty millimetre die.** A read from a macro at
the far corner of a tier is not the same as one from the middle, and `037`'s
crossbar sees the difference as jitter it has to absorb. Nobody has bounded it.

**Nothing says what happens at the low-voltage corner during a load step.**
`031` allows the logic rail to droop three per cent; the array rail's own droop
is not specified anywhere, and `C-035-2`'s worst corner assumes a static
condition that a machine under load does not have.
