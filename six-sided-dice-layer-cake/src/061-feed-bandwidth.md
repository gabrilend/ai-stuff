# 061 — Does a face ever starve

```meta
phase  | 8
issues | 806
```

Where `055` accounts for the interconnect, this accounts for the supply — the
same chain seen as a question about whether the engine ever waits.

## Four inequalities on four timescales

```drawing
what must keep up with what, and how often [not-dimensioned]

   the engine eats     [B_operand_die]     per cycle
        ≤
   the slice serves    [B_slice_read]      per layer
        ≤
   the core delivers   [B_face_even]       per token
        ≤
   the media supplies  [B_feed]            per power cycle
```

Being explicit about the timescale matters, because the four are easy to
conflate and the middle two are the only ones that ever bind.

## The two answers

**Below the crossover the engine starves by design and it does not matter.** It
waits for the core, the core is the bottleneck, and the machine's speed is the
core's bandwidth divided by the model size. The right statement is not *the face
does not starve* but **the face starves and this is the intended state**, which
is a much clearer thing to write down.

**Above it the engine must not wait**, and whether it does depends entirely on
`060`'s prefetch keeping ahead against `037`'s contention.

## The corners, not the average

- All six faces prefetching at once — each gets a sixth, and `060`'s lead is
  computed against that.
- A scrub cycle landing on the bank a face is reading. `040` says scrub is
  invisible; **here is where that is checked rather than assumed.**
- A spout burst. Low priority, but bounded wait, and during that wait it consumes.
- An uneven stage. `075` gives face zero and face five extra work; they read more
  and have the same time.

## Symbols

```symbols
B_eat_face    | bit/s | derived | B_operand_die * n_die_face      | what one face's four engines consume at full utilisation
m_slice_feed  | 1 | derived | B_slice_read / B_eat_face           | the slice's margin over that
m_core_feed   | 1 | derived | B_face_even / (C_layer_weights * 8e6 / t_layer) | the core's margin over what a face must pull per layer at its contended share
B_scrub_face  | bit/s | derived | B_scrub / n_face                | the scrubber's share falling on one face's traffic
m_scrub       | 1 | derived | (B_face_even - B_scrub_face) / (C_layer_weights * 8e6 / t_layer) | the core's margin with the scrubber running, which is the check 040 needs and cannot do for itself
f_starve_below| 1 | derived | 1 - (B_face_even / B_eat_face)      | how starved an engine is below the crossover, which is the intended state and is reported rather than constrained
t_token_feed  | s | derived | C_weights * 8e9 / B_core            | time per token from this chain, which 055 and 080 must agree with
```

## Constraints

```constraints
C-061-1 | m_slice_feed > 1              | the slice must feed four engines at full utilisation
C-061-2 | m_core_feed > 1               | a face's contended share of the core must cover what it pulls per layer, which is the condition 060's prefetch depends on
C-061-3 | m_scrub > 1                   | and must still cover it with the scrubber running. 040 asserts that scrubbing is invisible; this is the only place that claim is tested against the traffic it would be invisible against
C-061-4 | t_load_relay < t_load_max     | filling the core must be under the ceiling, restated here because this is the blueprint that accounts for the feed end to end
C-061-5 | t_token_feed ~= t_token       | time per token from this chain must equal what 053 derives and what 055 derives. Three routes to one number, and the third of the project's triple checks
C-061-6 | f_starve_below > 0            | the engine is starved below the crossover. Asserted in the direction that confirms it, because it is the intended state and a design in which it were false would mean the array had become too small rather than the memory too fast
```

## What is still open

**The uneven stage is not modelled.** `075` gives two faces extra work and this
blueprint checks a face's margin against an average layer. The face carrying the
output projection reads a larger layer in the same stage time, and nothing here
notices.

**The spout's consumption during its bounded wait is named and not computed.**
`037` gives it a worst-case wait; what it takes from a face's share while it
waits is not in any of the margins above.
