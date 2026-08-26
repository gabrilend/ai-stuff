# 073 — From cold to the first instruction

```meta
phase  | 10
issues | 1004
```

## The ten steps

```drawing
waking up [not-dimensioned]

    1  supplies valid                       from 033
    2  reference locked                     multipliers settle
    3  reset released                       cage first, then faces
    4  memory initialised                   the longest step, and the surprising one
    5  repair applied                       spares mapped in
    6  links trained                        deskew, spare remap
    7  self test                            enough to know it is not broken
    8  model load                           from the storage lines
    9  descriptor chains built              once, from the header
   10  ready
```

**Step four is the long one and it is not obvious why it exists.** Static memory
comes up with arbitrary contents, and `040`'s error correction over arbitrary
contents reports errors everywhere. So the whole core must be **written before it
is read** — and writing tens of gigabytes even at the core's own bandwidth takes
milliseconds, which is longer than every other step except the model load.

## Reset is not one signal

Different blocks need different lengths and different release orders, and some
state must survive a reset that other state must not.

**The core's contents must survive a warm reset.** A machine that reloads its
whole model because software restarted is a machine nobody wants. So there are
two resets, and the blueprint says what each clears.

## What happens if a step fails

Each of the ten can, and the machine must end up somewhere diagnosable rather
than hung. **Every step sets a fault bit on entry and clears it on success**, so a
machine stopped part way through boot says which step it stopped in.

That single convention is worth more than any amount of later debugging
apparatus, and it is why `049` has a bit per step.

## Symbols

```symbols
n_boot_step   | 1 | given | 10       | steps between supplies valid and ready
t_reset_hold  | s | given | 1.0e-6   | how long reset is asserted after the supplies are valid
t_selftest    | s | given | 5.0e-3   | the reduced self test at step seven
t_chain_build | s | given | 2.0e-3   | building every descriptor chain, once, from the header
t_link_train  | s | given | 1.0e-3   | deskewing every tile and remapping failed conductors
t_repair      | s | given | 1.0e-4   | mapping in spare rows and the redundant tier
warm_keeps_core | 1 | given | 1      | whether a warm reset preserves the core. It does, and it is a value so that a change which stopped it failing here rather than in the field

t_mem_init    | s | derived | C_core_raw / B_core             | writing every location once at the core's own bandwidth, which must happen before anything reads one
t_boot_cold   | s | derived | t_powerup + t_reset_hold + t_mem_init + t_repair + t_link_train + t_selftest + t_load_relay + t_chain_build | supplies valid to ready, from cold
t_boot_warm   | s | derived | t_reset_hold + t_selftest + t_chain_build | and from a warm reset, which keeps the core and therefore skips initialising and loading it
ratio_warm    | 1 | derived | t_boot_cold / t_boot_warm       | how much a warm reset saves, which is the argument for having two
f_step_load   | 1 | derived | t_load_relay / t_boot_cold      | the model load's share of a cold boot
f_step_mem    | 1 | derived | t_mem_init / t_boot_cold        | and memory initialisation's, which is the step nobody expects to be there at all
```

## Constraints

```constraints
C-073-1 | t_boot_cold < t_boot_max     | a cold boot must finish inside the stated ceiling, which is what an operator waits
C-073-2 | n_fault_bit >= n_boot_step   | there must be a sticky fault bit for every step, so that a machine stopped part way through says which step it stopped in
C-073-3 | ratio_warm > 3               | a warm reset must be several times faster than a cold one, or keeping the core through it is not worth the complication
C-073-4 | warm_keeps_core == 1         | a warm reset preserves the core. Asserted as a value because it is the property most likely to be lost in a later simplification, and losing it turns every software restart into a model reload
C-073-5 | t_mem_init > t_repair + t_link_train | writing every location once, before anything reads one, takes longer than mapping in spares and training every link put together. It was first asserted against the self test as well and is not longer than that -- which is worth knowing, because it means the two slow steps in a cold boot are the model load and a test whose duration is currently a guess
C-073-6 | f_step_load > f_step_mem     | the model load is still the largest step. If memory initialisation ever overtakes it, the core has grown faster than the storage lines and 057's drive count should be revisited
```

## Symbols this owns and needs

```symbols
t_boot_max    | s | given | 0.5 | the longest a cold boot may take. Half a second is what somebody switching a machine on will tolerate before wondering whether it is broken
```

## What is still open

**Step five has nowhere to read its map from.** `040` abandoned runtime repair
because nothing in this cube is non-volatile; the same gap means the test-time
spare assignment has to be re-derived or re-supplied at every boot. Whether it
comes from the host, from fuses, or from a region of the storage lines is not
decided, and it is now the **fourth** blueprint waiting on the same missing
thing.

**Nothing says what happens between step seven failing and a person finding
out.** The fault bit is set; the machine is not ready; and no blueprint says what
reads the bit when the machine that would report it has not finished waking up.
