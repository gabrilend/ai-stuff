# 908 — Knowing the pane arrived whole

Produces `src/069-spout-integrity.md`.

## Current behavior

**Done.** `src/069-spout-integrity.md` exists. A pane carries millions of bits and
no address, no length, no type and no framing, so the small amount of state that
makes it meaningful travels out of band on the spare conductors `063` already
provides.

Five constraints. `C-069-3` makes the argument the blueprint exists to make:
retrying costs under a thousandth of transfers, which is why **always-send-and-
sometimes-wrong** is the right protocol and forward error correction across
sixteen million lanes is the wrong one. The argument is written explicitly so
that somebody does not add one later.

The two error sources are separated — a bond that failed at assembly shows on
every pane in the same place and retrying forever does not help — with a rule for
telling them apart.

**The failure record has nowhere to live.** `063`'s remap needs to know which
conductors are bad and that must outlive a power cycle. It is the same missing
non-volatile store `033` needs for its fault record and `040` for its repair map.
**Three dependents on one gap now.**

## Intended behavior

**How the receiving side knows what it got, and what happens when it is wrong.**

### The problem with a pane

Sixteen million conductors carry sixteen million bits and **nothing else**. No
address, no length, no type, no framing. There is no room in a single edge to do
anything conditionally, and no protocol layer to put a header in.

So a pane is meaningless on its own. The receiver must already know what it means,
and the small amount of state that makes that true has to travel some other way.

### The out-of-band state

Three things, carried on a side channel — the strobes' spare conductors, or the
port field's control group:

- **Which core window the pane was aliased to**, from `505`'s register.
- **A sequence number**, so a repeat is recognisable as a repeat and a gap as a
  gap.
- **A hash over the pane**, computed by the sending side *while the pane was being
  read out of the core*, which costs nothing because the read takes fifty-four
  nanoseconds and the hash can be folded into it.

### Checked afterward, not before

**A pane is always sent and sometimes wrong.** There is no way to hold it back
pending a check, because the check needs the data and the data leaves in one edge.

That is acceptable here in a way it would not be elsewhere: the recovery is to
send it again, and at thirty-three microseconds for the entire core, resending a
two mebibyte pane is a rounding error. **No cleverer protocol earns its
complexity**, and the blueprint should make that argument explicitly so that
somebody does not later add forward error correction to sixteen million lanes.

### What the hash has to be

Strong enough that an undetected error is rarer than the machine's other failure
modes, and cheap enough to compute at thirty-nine terabytes a second in a fold of
the read path. Those two pull opposite ways and the blueprint must pick a point
and show the arithmetic: an undetected-error rate, derived, compared against
`1206`'s target.

### The two error sources, which want different answers

**A conductor that failed at assembly** is permanent and shows on every pane in
the same place. Retrying forever does not help. This wants **detection plus
diagnosis** — a per-conductor failure record that `902`'s spare remap can act on,
built at bring-up in `1205` rather than at runtime.

**A transient** is what the hash and the retry are for.

Distinguishing them is the useful part: a hash mismatch in the same tile on three
consecutive panes is a broken conductor, not bad luck, and the machine should say
so rather than retrying indefinitely. The blueprint must specify that rule.

## Symbols this must publish

Side channel conductor count and rate. Hash function, width, and undetected error
rate. Hash computation cost in the read path. Sequence number width and wrap.
Retry policy and its limit. Permanent-failure detection rule. Per-conductor
failure record size.

## Constraints this must assert

- Undetected error rate is below `1206`'s target, given the pane rate.
- Side channel conductors fit `902`'s spare allocation.
- Hash computation adds nothing to the pane read time — the fold, asserted.
- Sequence number does not wrap within the retry window.
- The permanent-failure rule triggers before the retry limit, so a broken
  conductor is reported rather than hammered.

## Suggested implementation steps

1. State that a pane is unframed and derive the need for a side channel from that.
2. Choose the hash from the two-way pull and show the arithmetic.
3. Write the always-send-sometimes-wrong argument so nobody adds a code later.
4. Separate the two error sources and specify the discrimination rule.

## Blocks

`909`, `1205`, `1206`.

## Blocked by

`505`, `901`, `902`, `903`.

## Related documents

`007`. `004` for the parallel argument about load-time versus in-flight checking.
