# 1206 — How long it lasts

Produces `src/086-reliability-and-lifetime.md`.

## Current behavior

**Done.** `src/086-reliability-and-lifetime.md` exists, and it fixes something
that was backwards: **four blueprints were already deriving numbers from a
lifetime target that did not exist.** It exists now and they check against it.

Seven constraints. Wear-out and random mechanisms are kept apart, because adding
them as though they were the same thing is the ordinary way to get this wrong — a
machine whose random rate is fine and whose wear-out cliff is at three years is
not the same product as one with the reverse.

The budget is **deliberately uneven**, and `C-086-2` asserts the asymmetry: the
serviceable half of the machine gets a larger allowance than the unrepairable
half, which is the whole reason `019`'s absence of repair matters.

**Silent corruption gets the smallest allocation of the nine**, even though it
breaks nothing — because the machine keeps running and lies.

**Six of the nine mechanisms have no derived number.** They are named, allocated
and not computed. **Bond fatigue is the largest gap**: `018` counts three thermal
swings and turns none of them into cycles to failure.

## Intended behavior

**The lifetime target, the failure mechanisms that threaten it, and the budget
that divides one between the others.**

### Why the target has to be set here rather than assumed

`405` sizes conductors against it. `507` sizes scrubbing against it. `1003` sizes
synchronisers against it. `908` sizes a hash against it. Four blueprints are
already deriving numbers from a target that does not exist, which is exactly
backwards, and this ticket fixes it.

### The mechanisms

| mechanism | where | owner |
|---|---|---|
| electromigration | every conductor | `405` |
| bond fatigue | every thermal cycle | `206` |
| seal compression set | the elastomer | `205` |
| soft errors, uncorrectable | the core | `507` |
| synchroniser failure | six domain crossings | `1003` |
| undetected spout error | the pane | `908` |
| dielectric breakdown | thin oxides | this blueprint |
| coolant fouling and corrosion | the wetted path | `308` |
| pump wear | outside the cube | `308` |

Nine, and they do not compose the same way. Some are wear-out, some are random,
and **the two must not be added as if they were the same thing**. The blueprint
must give a failure rate against time curve rather than a single figure, because
a machine whose random rate is fine and whose wear-out cliff is at three years is
not the same product as one with the reverse.

### The budget

Set the target, then divide it. Each mechanism gets an allocation and each owning
blueprint must meet its own — which is what turns "reliable" into nine checkable
constraints instead of one adjective.

The allocation should not be uniform. The mechanisms with no repair path deserve
the smallest allowance, and since `207` establishes that **nothing in this machine
has a repair path**, that is all of the ones inside the cube. The two outside —
pump wear and fouling — can take a much larger share because they are serviceable,
and the blueprint should say so explicitly, because that asymmetry is the whole
reason to distinguish inside from outside.

### The one that is not a hardware failure

A flipped weight bit that error correction misses changes one number in one matrix
and the model produces slightly different text forever, with no symptom. `507`
calls it out. **It is a reliability failure with no observable and no alarm**, and
the blueprint should treat it as the worst mechanism on the list even though it
breaks nothing, because the machine keeps running and lies.

### What the target should be

The blueprint must choose, and should choose against a use case rather than a
convention: a cube in a rack, powered continuously, replaced rather than repaired,
in a population where a certain annual replacement rate is tolerable. That gives a
number with a reason attached, which is worth more than a round figure.

## Symbols this must publish

Lifetime target and the use case it comes from. Allocation per mechanism. Failure
rate against time, separating random from wear-out. Wear-out cliff location.
Annual replacement rate at the target. The inside-versus-outside allocation
asymmetry.

## Constraints this must assert

- Allocations sum to the target.
- Every mechanism's owning blueprint meets its allocation. Nine cross-blueprint
  checks, and the reason this ticket exists.
- No wear-out mechanism has its cliff before the target.
- The undetected-error rate from `507` and `908` together is below the allocation
  for silent corruption, which is the smallest allocation on the list.

## Suggested implementation steps

1. Choose the target from a use case and write the reasoning down.
2. Enumerate the mechanisms and assign owners.
3. Allocate, unevenly, with the repair-path asymmetry stated.
4. Build the rate-against-time curve with the two kinds separated.
5. Close the nine cross-blueprint checks.

## Blocks

`205`, `206`, `405`, `507`, `908`, `1003`, `1303`.

## Blocked by

`205`, `206`, `308`, `405`, `507`, `908`, `1003`.

## Related documents

`207` for the absence of repair that shapes the allocation.
