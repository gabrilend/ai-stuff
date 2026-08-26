# 909 — The thing on the other end

Produces `src/069a-the-translation-unit.md`.

## Current behavior

**Done, and it closes `009` entry O1** — what had been called the largest
unspecified block in the project.

`src/069a-the-translation-unit.md` exists. The cube is built once and adapters
are built many times, which is the right way round because host interfaces change
every few years and a cube does not.

Six constraints. `C-069a-2` is the property that actually justifies sixteen
million wires, and it is not throughput: **the cube is occupied for under a
thousandth of the time a whole-core handover takes.** It is a zero-cost output,
not a fast one.

**The receive circuit had to shrink by a factor of three and a half.** A hundred
and forty square microns a conductor makes the unit two and a half thousand
square millimetres — three reticle fields — and it cannot be larger than the
sending side's anyway, because the far end meets the same pitch.

**Only one variant is worked out**, which is `069b`. **The receiving side's own
skew is not budgeted.** **And data conditioning leaks into the interface**: `064`
inverts a tile's data and sends a bit saying so, and something must undo it,
which means the core-side interface is not quite as protocol-free as `062`
claims.

## Intended behavior

**A companion part that sits on the spout and converts panes into whatever the
receiving machine actually speaks.**

The spout emits two mebibytes on one edge across sixteen million conductors. There
is no computer that accepts that. So between the cube and anything else there is a
**translation unit**: a die, or a small board, whose whole job is to be fluent in
the pane on one side and in an ordinary interface on the other.

### Why this is the right shape

Putting the translation inside the cube would mean choosing, at silicon design
time, which host interface the machine speaks — and host interfaces change every
few years while a cube takes years to build. Putting it outside means **the cube
is built once and the adapter is built many times**, one per thing worth attaching
to.

It also means the cube's side of the interface can be exactly what suits the cube:
maximally wide, minimally clever, no protocol, no addressing, no negotiation. All
the awkwardness lives in the part that is cheap to respin.

### What one looks like

```
   the cube            the translation unit                 the host
 ┌──────────┐      ┌──────────────────────────┐        ┌─────────────┐
 │  spout   │ pane │  pane receiver, deskew   │        │             │
 │  face    │═════▶│  buffer, reorder         │───────▶│  memory bus │
 │ 16.8 M   │ 2MiB │  protocol engine         │  cable │  or fabric  │
 │ wires    │      │  ~2 MiB of buffer        │        │             │
 └──────────┘      └──────────────────────────┘        └─────────────┘
```

Three blocks. The **receiver** is `903`'s circuit, four thousand and ninety-six
tiles' worth, plus `904`'s per-tile deskew. The **buffer** holds at least one pane
and probably four, because the host side is between one and three orders of
magnitude slower and the mismatch has to go somewhere. The **protocol engine** is
whatever the far side needs.

### The variants

The blueprint should specify the interface to the cube once and then a table of
far sides, because that is the point of the part:

| far side | what it gives the host | rate |
|---|---|---|
| a memory fabric | the core as addressable memory — see `910` | high |
| a general peripheral bus | a device the host reads and writes | moderate |
| a network interface | the cube as a service on a wire | low |
| another translation unit | two cubes joined, bonded or cabled | high |

### The bandwidth reality

Worth stating early so nobody is disappointed. The spout can burst at two
petabytes a second. A memory fabric link carries a few tens of gigabytes a second.
**The translation unit is a funnel with a ratio of about fifty thousand to one**,
and what it is actually for is not sustained throughput — it is that the cube can
hand over any two mebibytes it holds *without the cube spending any time on it*.
The cube's side of the transfer costs one edge. The host's side takes as long as
the host takes, and the cube is free the whole while.

That reframes the spout: it is not a fast output, it is a **zero-cost output**.
The blueprint should say so in those words, because it is the property that
justifies sixteen million wires.

## Symbols this must publish

Buffer depth in panes. Cube-side and host-side rates and their ratio. Receiver
area and power. Deskew range. Latency from pane arrival to first host-visible
byte. Variant table with a rate and a part count for each. Which of `066`, `067`
and `068` each variant mates with.

## Constraints this must assert

- Buffer depth times pane size exceeds the host-side rate times the worst-case
  host stall, or panes are dropped.
- Receiver deskew range covers `904`'s worst-case tile skew.
- Cube-side interface is identical across all variants. **The whole point of the
  part**, asserted so a variant cannot quietly special-case it.
- Translation unit power is outside the cube's budget in `301` and inside its own.

## Suggested implementation steps

1. Specify the cube-side interface once and freeze it.
2. Size the buffer from the rate mismatch and the host stall.
3. Write the variant table, and write the memory-fabric row in full because `910`
   depends on it.
4. State the funnel ratio and the zero-cost-output reframing plainly.

## Blocks

`910`, `1301`, `1302`.

## Blocked by

`901`, `903`, `904`, `906`, `907`.

## Related documents

`007`. `009` entry O1, which this ticket closes.
