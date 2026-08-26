# 052 — What a transfer looks like

```meta
phase  | 7
issues | 703
```

## The traffic, which is unusually simple

Almost all of it is one face reading a long sequential run of weights out of the
core. Not scattered, not small, not read-modify-write, and shared with nobody —
each face reads its own layers. The rest is one activation handoff per stage per
token, a handful of small sequencer reads, and the spout.

**A protocol for that traffic can be very simple**, and this blueprint resists
generality. There is no coherence (`039` says so as a value), no snooping, no
ownership, and no retry except on a corrected error.

## The transfer size

The most-cited number in the phase, and it has to satisfy four things at once
from four different blueprints:

- large enough that header overhead is negligible against the weight stream
- a whole number of `040`'s correction lines, so a transfer is a whole number of
  protected units
- no larger than `038`'s bank interleave, so one transfer is never split across
  two banks
- small enough that `037`'s round-robin quantum does not starve a face longer
  than `053` tolerates

Four constraints from four phases on one number. **This is exactly what the
checker exists for**, and the number is derived here rather than picked.

## Credits

A reader must not issue more than the cage can absorb. One credit per
outstanding transfer, returned on completion. The count must cover the
bandwidth-delay product or the link idles waiting for returns — which is a
silent loss, not a visible one, so it is derived rather than chosen.

```drawing
one read, end to end [not-dimensioned]

   face                          cage                    tier
    │  header + address           │                       │
    ├────────────────────────────▶│  decode, arbitrate    │
    │            (credit spent)   ├──────────────────────▶│
    │                             │                       │  access
    │                             │◀──────────────────────┤
    │◀────────────────────────────┤  [w_transfer] of data │
    │      (credit returned)      │                       │
```

## Symbols

```symbols
w_header      | bit | given | 128    | header on one transfer: operation, address, sequence and credit accounting
n_txn_type    | 1 | given | 5        | transaction types: read, write, staging release, control read, control write
w_transfer    | bit | given | 4096    | payload of one transfer. Sixteen of 040's correction lines, an eighth of 038's interleave, and large enough that the header is three per cent
n_credit      | 1 | given | 256       | outstanding transfers one port may have

f_overhead    | 1 | derived | w_header / (w_header + w_transfer)  | share of the link spent on headers
n_line_txfr   | 1 | derived | w_transfer / n_ecc_line             | correction lines in one transfer
bdp_face      | bit | derived | B_face_even * t_link_rt           | bandwidth-delay product for one face at its even share
n_credit_need | 1 | derived | bdp_face / w_transfer               | credits needed to cover it
B_eff_face    | bit/s | derived | min(B_face_even, n_credit * w_transfer / t_link_rt) | what a face actually achieves, given its credits
f_credit_loss | 1 | derived | 1 - B_eff_face / B_face_even        | bandwidth lost to running out of credits, which is a loss with no symptom
n_line_per_token | 1 | derived | C_weights * 8e9 / n_ecc_line / n_face | correction lines one face touches per token, which 048's small reads are judged rare against
```

## Constraints

```constraints
C-052-1 | n_line_txfr == floor(n_line_txfr) | a transfer must be a whole number of correction lines, or a transfer straddles a protected unit and a single error in the wrong place becomes two partial ones
C-052-2 | w_transfer <= w_interleave        | a transfer must fit inside one bank's interleave stride, or every transfer is split across two banks
C-052-3 | f_overhead < 0.05                 | headers must cost under a twentieth of the link
C-052-4 | n_credit >= n_credit_need         | credits must cover the bandwidth-delay product. Falling short does not fail, it silently costs bandwidth, which is why this is derived rather than chosen
C-052-5 | f_credit_loss < 0.01              | and the loss must be under a hundredth even so
C-052-6 | w_transfer <= q_arb               | a transfer must fit inside 037's arbitration quantum, or the arbiter reconsiders in the middle of one
C-052-7 | t_link_rt < t_stage / 1000        | a round trip must be under a thousandth of a pipeline stage, or 048's prefetch has to run further ahead than two buffers allow
```

## What is still open

**Writes are treated as reads with a payload.** The traffic is overwhelmingly
reads and the writes that exist — staging buffers, the request region — are small
and latency-sensitive in a way this protocol does not distinguish. `037` noticed
the same gap from the arbiter's side. Neither has done anything about it.

**Errors are corrected and not reported.** `040` corrects a single error in a
line and the transfer completes normally. Nothing counts how often that happens
per link, which is the one signal that would show a conductor failing slowly
rather than all at once — and `051` has no way to find out which conductors to
remap without it.
