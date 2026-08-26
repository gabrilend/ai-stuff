# 069 — Knowing the pane arrived whole

```meta
phase  | 9
issues | 908
```

## The problem with a pane

Millions of conductors carry millions of bits and **nothing else**. No address, no
length, no type, no framing. There is no room in a single edge to do anything
conditionally, and no protocol layer to put a header in.

So a pane is meaningless on its own. The receiver must already know what it
means, and the small amount of state that makes that true has to travel another
way.

## The out-of-band state

Carried on the strobes' spare conductors, or on the port field's control group:

- **which core window** the pane was aliased to, from `038`'s register
- **a sequence number**, so a repeat is recognisable and a gap is too
- **a hash over the pane**, computed while the pane was being read out of the
  core — which costs nothing, because the read takes far longer than the hash
  and the hash folds into it
- **the inversion bits** from `064`'s data conditioning, without which the far
  end cannot undo it

## Checked afterward, not before

**A pane is always sent and sometimes wrong.** There is no way to hold one back
pending a check, because the check needs the data and the data leaves in one
edge.

That is acceptable here in a way it would not be elsewhere: the recovery is to
send it again, and at tens of microseconds for the entire core, resending one
pane is a rounding error. **No cleverer protocol earns its complexity**, and the
argument is made explicitly so that somebody does not later add forward error
correction to sixteen million lanes.

## The two error sources want different answers

**A conductor that failed at assembly** is permanent and shows on every pane in
the same place. Retrying forever does not help. It wants **detection plus
diagnosis** — a per-conductor failure record that `063`'s spare remap can act on.

**A transient** is what the hash and the retry are for.

Distinguishing them is the useful part: a mismatch in the same tile on several
consecutive panes is a broken conductor, not bad luck, and the machine should say
so rather than retrying indefinitely.

## Symbols

```symbols
w_hash_pane   | bit | given | 128     | hash width over one pane
n_retry_max   | 1 | given | 3          | retries before a pane is declared permanently bad
n_consec_fail | 1 | given | 3          | consecutive failures in the same tile that mean a broken conductor rather than bad luck
w_seq_pane    | bit | given | 32       | sequence number width
p_bit_transient | 1 | measured | 1e-18 | chance one bit is wrong in flight across a bond, per transfer

w_win_reg     | bit | given | 64 | width of the pane window's aliasing register, which travels with every pane so the far end knows what it received
w_oob         | bit | derived | w_hash_pane + w_seq_pane + w_win_reg + n_pane_tile * b1 | out-of-band state per pane: hash, sequence, the window register, and one inversion bit per tile
p_pane_bad    | 1 | derived | n_pane_bit / b1 * p_bit_transient   | chance a pane carries at least one wrong bit
p_undetected  | 1 | derived | p_pane_bad / 2^(w_hash_pane / b1)   | chance a wrong pane passes its hash
rate_pane     | 1/s | derived | f_spout_sust                 | panes a second, sustained
rate_undet    | 1/s | derived | p_undetected * rate_pane            | undetected errors a second at that rate
t_undet_mean  | s | derived | 1 / rate_undet                        | mean time between them
f_retry_cost  | 1 | derived | p_pane_bad * n_retry_max              | share of pane transfers spent retrying
n_seq_wrap    | 1 | derived | 2^(w_seq_pane / b1)                   | panes before the sequence number wraps
```

## Constraints

```constraints
C-069-1 | t_undet_mean > t_life_seconds | the mean time between undetected errors must exceed the machine's whole life. A pane that is wrong and passes its hash is corruption with no symptom, which is the same failure mode 040 calls the worst one it has
C-069-2 | w_oob < n_spare_pane * b1     | the out-of-band state must fit in the spare conductors 063 already provides, rather than needing its own array
C-069-3 | f_retry_cost < 0.001          | retrying must cost under a thousandth of the transfers, which is what makes always-send-sometimes-wrong the right protocol and forward error correction the wrong one
C-069-4 | n_seq_wrap > n_pane_core      | the sequence number must not wrap within a whole-core transfer, or a repeat and a gap become indistinguishable in the one operation that matters most
C-069-5 | n_consec_fail <= n_retry_max  | a broken conductor must be diagnosed no later than the retries give up, or the machine hammers a dead wire and never says why
```

## What is still open

**The failure record has nowhere to live.** `063`'s remap needs to know which
conductors are bad and that knowledge must outlive a power cycle — the same
missing non-volatile store `033` needs for its fault record and `040` needs for
its repair map. **Three dependents on one gap.**

**Nothing says who retries.** The cube emits; the far end detects. Asking for a
resend means the far end can talk back, and `069b` establishes a request path for
a different reason. Whether integrity retries use it, or whether the cube simply
sends every pane twice, is not decided.
