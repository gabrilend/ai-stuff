# 068 — Byte mode

```meta
phase  | 9
issues | 907
```

## Where it comes from

> alternatively, each byte, so you can pulse 8 bits in a cycle.

That line is in the original page, two sentences after the one-wire-per-bit
claim. **Whoever wrote it had already found the wall**, and the retreat is better
engineering than the claim it retreats from.

## What it changes

Dividing the conductor count by eight moves the required pitch from one only a
permanent bond reaches to one **ordinary microbumps reach**. That is the
difference between a part that can only be made by wafer-level bonding at the
very end of assembly and one that can be attached with a process the industry
runs every day — and, crucially, one that can be **tested before it is
committed** and **reworked if it fails**.

| | bonded (`066`) | byte mode |
|---|---|---|
| conductors | one per bit | one per byte |
| pitch | bondable only | microbump |
| attach | permanent | reworkable |
| edges per pane | one | eight |
| whole-core transfer | tens of microseconds | hundreds |
| rework | none | possible |

Eight times the time, and in exchange the part becomes manufacturable,
reworkable and testable. **Hundreds of microseconds to move the entire core is
still three orders of magnitude faster than a network interface.**

## What has to be designed rather than scaled

**The multiplexer.** Eight bits share a conductor, so something selects between
them at eight times the pane rate. It is per conductor, two million times — and
at a microbump pitch it has a thousand square microns rather than `064`'s few
tens, so it can be a real circuit rather than an inverter.

**The eight-phase timing.** `065`'s tiling still applies, but each tile must now
produce eight correctly spaced phases, and **the skew budget within a pulse is
eight times tighter** for the same nominal rate. That is the hidden cost and it
is surfaced rather than buried.

**Which eight bits.** Byte-aligned is the obvious mapping and probably right, but
`063`'s bit-to-pad rule was chosen to keep a tile inside one memory interleave
unit, and byte-serial order interacts with it.

## Why this is the one that ships

The bonded grade is unrepairable and stakes two objects on sixteen million
simultaneous bonds. The cabled grade gives up two orders of magnitude and needs a
different circuit entirely. Byte mode keeps most of the width, uses a process
that exists, can be tested before it is committed, and costs eight edges — which
against a translation unit already a thousand times slower is invisible.

## Symbols

```symbols
n_phase_byte  | 1 | given | 8        | bits sharing one conductor, and therefore pulses per pane
p_bump_byte   | um | given | 32.0    | microbump pitch this grade uses. Thirty is a quarter of a micron finer than the conductor count actually permits in the fine zone available
a_mux_lane    | um^2 | measured | 260.0 | area of one eight-way multiplexer and its phase logic
n_rework_byte | 1 | given | 2         | rework attempts a microbump attach permits

n_cond_byte   | 1 | derived | n_pane_bit / b1 / n_phase_byte      | conductors this grade needs
p_byte_need   | um | derived | sqrt(A_fine / (n_cond_byte * (1 + f_gnd_ratio))) | the pitch that many conductors actually require in the fine zone
a_cond_byte   | um^2 | derived | p_bump_byte^2                    | area one conductor has at the chosen pitch
f_mux_area    | 1 | derived | a_mux_lane / a_cond_byte            | how much of it the multiplexer uses
t_pane_byte   | s | derived | n_phase_byte / f_spout_burst | time for one pane in this grade
t_core_out_y  | s | derived | n_pane_core * t_pane_byte            | whole-core transfer time
t_skew_phase  | ps | derived | t_skew_intra / n_phase_byte         | skew budget within one pulse, which is the hidden cost
ratio_net_y   | 1 | derived | t_core_net / t_core_out_y            | how much faster than a network interface this grade still is
E_pane_byte   | J | derived | E_pane                               | energy per pane, unchanged: the same bits cross the same bonds, just not at the same moment
```

## Constraints

```constraints
C-068-1 | n_cond_byte * n_phase_byte ~= n_pane_bit / b1 | the conductors times the phases must be the pane exactly
C-068-2 | p_bump_byte >= p_byte_need    | the chosen microbump pitch must be no finer than what the conductor count requires in the fine zone available
C-068-3 | f_mux_area < 0.5              | the multiplexer must fit in under half the pitch, which it comfortably does -- this grade has forty times the area per conductor that 064 has
C-068-4 | t_skew_phase >= t_skew_min    | the skew budget within one pulse must still be achievable. It is eight times tighter than the bonded grade's for the same nominal rate, and this is the constraint that would fail first if the rate were raised
C-068-5 | ratio_net_y > 1000            | it must still be three orders of magnitude faster than a network interface, which is what makes eight edges an acceptable price
C-068-6 | n_rework_byte > n_rework      | this grade must permit rework where the bonded one does not, which is the whole argument for it
```

## Symbols this owns and needs

```symbols
t_skew_min    | ps | given | 0.8 | the least skew any distribution can be held to at this scale, from the process
```

## What is still open

**The bit-to-conductor mapping is not written**, and it interacts with `063`'s
rule about keeping a tile inside one interleave unit. Byte-aligned is obvious and
obvious is not checked.

**Nothing says which grade a given cube is built with.** `056` makes it an
assembly decision, `082` has to sequence it, and `088` has to price all three.
The recommendation here is byte mode and no blueprint records a choice.
