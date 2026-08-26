# 402 — Five voltages, or four

Produces `src/029-voltage-domains.md`.

## Current behavior

Five domains are used in the documentation and none is justified.

## Intended behavior

**Each supply rail, what it feeds, why it is separate from its neighbour, and what
collapsing it would cost.** A domain is expensive — its own regulator, its own
plane, its own decoupling, its own sequencing step — so each one must earn itself.

| domain | V | feeds | why not merged |
|---|---|---|---|
| `V_logic` | 0.75 | die logic, matrix engines | the largest load; everything else is measured against it |
| `V_array` | 0.85 | static memory, core tiers and face slices | cells need more headroom than logic to stay stable while being read |
| `V_link` | 0.60 | radial link drivers | short reach permits a small swing, and energy goes as the square |
| `V_port` | 1.20 | port field, storage lines, spout | must interoperate with things this machine did not design |
| `V_aux` | 3.30 | sensors, telemetry, the interlock | must survive when everything else is off |

### The three arguments worth making properly

**Array against logic.** Running the whole die at the array's voltage would cost
about eleven per cent of total power for nothing. Running the array at the logic
voltage would cost read stability, which shows up as a soft error rate rather than
as a failure, which is worse. The eleven per cent is the number the blueprint must
derive.

**The link's small swing.** Energy per bit goes as the square of the swing, and the
link carries thirty-nine terabytes a second. Six hundred millivolts against seven
hundred and fifty is a thirty-six per cent saving on a term worth seventy watts.
The limit is noise margin over the radial interface, which is `702`'s to state.

**Auxiliary must outlive the others.** The interlock in `308` has to cut power when
the coolant stops, which means it cannot be powered by the thing it is cutting.
This is the only domain whose justification is about failure rather than
efficiency, and it is the one most likely to be dropped by somebody optimising.

### What collapsing would buy

The blueprint should price the merge candidates explicitly, because the answer is
not obvious and somebody will ask. Merging port into auxiliary saves a regulator
and costs the ability to power the interlock separately. Merging link into logic
saves a plane and costs twenty-five watts.

## Symbols this must publish

Nominal voltage, tolerance band, load current at each operating point, allowed
droop and allowed ripple, per domain. The merge costs as derived numbers.

## Constraints this must assert

- Every domain's tolerance band is wider than its droop plus its ripple. Otherwise
  the rail is out of specification during normal operation, which is the kind of
  thing that is obviously wrong and quietly true.
- The array voltage exceeds the logic voltage by at least the read stability
  margin from `502`.
- The link swing exceeds the noise margin from `702`.
- Auxiliary is not derived from any other domain.

## Suggested implementation steps

1. List the domains with their loads from `401`.
2. Derive the eleven per cent and the twenty-five watts rather than asserting them.
3. Set tolerance, droop and ripple per domain and assert the sum.
4. Write the merge analysis, including the ones that should not happen, so the
   argument is on record.

## Blocks

`401`, `403`, `404`, `406`.

## Blocked by

`401` for the loads, `502` and `702` for the two margins.

## Related documents

`006`. `009` entry P1 is a related question about the intermediate voltage, which
belongs to `403` rather than here.
