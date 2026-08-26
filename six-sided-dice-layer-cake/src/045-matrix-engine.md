# 045 — Sixty-five thousand multipliers

```meta
phase  | 6
issues | 605
```

Where nearly all the transistors and nearly all the heat are.

## It is idle most of the time, and that has to be said first

Generating one token means reading every weight in the model once and doing two
operations per weight. The reading takes about twenty-eight times as long as the
arithmetic. **Below a batch of about twenty-eight this array is waiting for
memory**, and a reader who meets that fact in `080` rather than here will think
something has gone wrong.

So why build it this large? Because prompt processing and batched serving both
operate above the crossover, and those are the workloads the machine is for.
Single-stream generation is the case it must not be *slow* at, not the case it is
*sized* for. If that argument does not hold for the intended use, the array
should shrink and the die with it, and the cube would get smaller.

## The dataflow

**Weights stationary, activations streaming.** A weight is read once from the
slice and used for every sequence in the batch, which is exactly the reuse `004`
describes. The reuse factor is the batch size, up to the point where the
accumulators run out of somewhere to put partial sums.

## Weight expansion, in the datapath

Weights arrive as four-bit indices into a sixteen-entry table shared by a group,
with one scale per group, and they have to become operands.

**The expansion happens in the datapath and not in a separate pass**, because a
separate pass means writing expanded weights somewhere and expanded weights are
four times the size — which the slice cannot hold. So the table lookup and the
scale multiply sit between the slice and the array and run at full rate. That is
a real circuit with a real area and it is budgeted here rather than assumed away.

## The transposed multiply, which training needs

`076a` wants the gradient with respect to a layer's input, which needs the weight
matrix the other way round. A weights-stationary array does not offer that.
Three options, all costing something:

- **A bidirectional array**, read along either axis. Costs area in every cell.
- **Weights held twice**, in both orientations. Costs double the slice, which
  does not exist.
- **A different streaming order for the backward pass**, keeping the array as it
  is and paying in operand bandwidth rather than area.

**The third is chosen** and priced below. It is the only one that does not cost
something the design has already spent.

## Symbols

```symbols
n_mac_row     | 1 | given | 256   | multiplier cells across one row of the array
f_face        | GHz | given | 1.4  | the face clock
a_mac         | um^2 | measured | 480.0 | area of one multiply-accumulate cell including its share of the accumulator
w_acc         | bit | given | 32   | accumulator width
n_lut_entry   | 1 | given | 16    | entries in the shared expansion table one group of weights indexes
n_flop_mac    | flop | given | 2  | operations one multiply-accumulate cell performs per cycle: a multiply and an add. It carries the unit so that an operation rate is a rate of operations rather than a bare reciprocal second, which is the distinction that keeps a throughput from being added to a clock
a_expand_lane | um^2 | measured | 900.0 | area of one expansion lane: the table lookup and the scale multiply
f_bwd_operand | 1 | given | 2.0   | how much more operand bandwidth the backward pass needs, streaming differently instead of transposing the array

n_mac         | 1 | derived | n_mac_row^2                          | multiplier cells in one array
A_mac_array   | mm^2 | derived | n_mac * a_mac                      | area they occupy
A_expand      | mm^2 | derived | n_mac_row * a_expand_lane          | area the expansion path occupies, one lane per row
ops_die       | flop/s | derived | n_flop_mac * n_mac * f_face      | operations a die can issue a second
ops_machine   | flop/s | derived | ops_die * n_die                  | and the whole machine
P_engine_die  | W  | derived | E_op * ops_die * util_design         | switching power of one die's multiplier array at the design utilisation
n_reuse       | 1  | derived | batch_design                         | how many times a weight is used from the slice for each time it is read from the core
I_step_engine | A  | derived | E_op * ops_die / V_logic             | current the array demands when every cell has an operand, which 031 sized the decoupling from
B_operand_die | bit/s | derived | (n_mac / batch_design * w_weight + n_mac_row * w_act) * f_face | operand bandwidth from the slice: a weight tile reloaded every batch cycles at four bits each, plus a row of activations every cycle at sixteen
acc_headroom  | 1  | derived | 2^(w_acc / b1 - 1) / (n_reduce_max * range_operand^2) | how much margin the accumulator has against the largest reduction in the model, each product at most the square of an operand's range. Written first against one row of the array, which is not the reduction -- the array accumulates across many passes and the real length is the model's widest tensor
```

## Constraints

```constraints
C-045-1 | A_mac_array + A_expand <= f_area_engine * A_die + f_area_expand * A_die | the array and its expansion path must fit the floorplan allocation in 041
C-045-2 | P_engine_die > P_leak_die      | the multipliers must dominate their own leakage. If this inverts the die is too large or too hot, and either way 041's floorplan is wrong
C-045-3 | I_step_engine ~= I_step_die    | and the current step must be the one 031 sized thirty-four microfarads against, which is the same statement in the electrical domain
C-045-4 | acc_headroom > 1               | the accumulator must not overflow on the largest reduction in the reference model. 077 supplies the operand magnitude; getting this wrong produces wrong answers with no fault raised
C-045-5 | n_reuse > 10                   | a weight must be used many times from the slice for each expensive read from the core, or the whole three-tier arrangement in 059 is not earning itself
C-045-6 | B_operand_die <= B_slice_read  | the slice must be able to feed the array at the rate it consumes, which is what 047's ports are sized for
C-045-7 | f_bwd_operand * B_operand_die <= B_slice_read | and it must still keep up during a backward pass, which streams differently rather than transposing the array. This is what the third option in the transpose trade actually costs
```

## What is still open

**`E_op` is measured with no source and everything scales with it** — the heat
budget, the cold plate's channel width, the radiator's area. A quarter of a
picojoule per operation is plausible for an eight-bit multiply-accumulate at a
leading node and it is the single most load-bearing unsourced number in the
project.

**The power map is uniform over the array's area.** `041`'s checkerboard makes
that truer than it was and does not make it true: within a tile, the multipliers
switch and the accumulator does not, and `025` integrates as though they did.

**The backward pass's operand factor is a `given`.** Two is what streaming
differently rather than transposing costs if the streaming is arranged well.
Nothing has arranged it.
