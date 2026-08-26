# 040 — Catching a bit that flipped

```meta
phase  | 5
issues | 507
```

## Why this is not optional

Six hundred and thirty thousand million bits. At an ordinary soft error rate for
static memory at sea level that is **one upset roughly every ninety minutes**.

Without correction this machine produces a wrong answer several times a day and
never says so — and the failure is silent in the worst possible way. **A flipped
weight bit crashes nothing.** It changes one number in one matrix and the model
produces slightly different text, forever, until the memory is reloaded. There is
no symptom, no counter that moves, and no way to notice from the outside.

That sentence is why this blueprint exists and it should be the first thing in
it.

## The scheme

Single error correct, double error detect, over a line whose width follows from
`052`'s transfer size. Two hundred and fifty-six data bits need nine bits to
locate an error among them and a tenth to detect a second: **under four per cent
overhead**, against the twelve and a half a sixty-four bit line would cost.

The sieve's reads are enormous and sequential, so a wide line is nearly free.
`009` entry M1 asked whether correction should be per word or per line, and the
answer is per line **provided** `048`'s small control reads do not pay a line's
latency for eight bytes. `053`'s count of small reads per token is what decides
it, and that count is what this blueprint waits on.

## Scrubbing

Correction only helps if errors do not accumulate. Two upsets in one line is a
detected uncorrectable, which is better than silence and is still a stopped
machine.

So the whole core is read and rewritten on a cycle short compared with the time
for a second upset to land in a line that already has one. The arithmetic is
gentle: at an hour's period the mean time between uncorrectable errors comes out
in the millions of years, and the bandwidth it costs is about a millionth of the
core's. **Scrubbing is close to free here and there is no reason to be clever
about it.**

## Repair

Soft errors are transient. **Hard failures are not**, and in a stack of
twenty-four tiers they are `083`'s yield problem wearing a different hat.

**Spare rows and columns** within a tier, blown at test. **A redundant tier**,
one of the twenty-four held in reserve — which is what turns a twenty-four-way
series product into something survivable and is already in `034`'s capacity
chain. And **runtime remap**, which needs somewhere to keep the map that survives
power loss.

**Nothing in this machine is non-volatile.** `009` entry M4, and `033` needs the
same missing thing for its fault record. Two dependents on one gap is enough to
say plainly: **runtime repair is not available in this design**, and what exists
is test-time sparing plus the redundant tier.

## Symbols

```symbols
fit_per_bit   | 1/(bit*s) | measured | 2.78e-19 | soft error rate for static memory at sea level: a thousand failures per thousand million hours per megabit, converted once here so that nothing downstream has to multiply by three thousand six hundred and hope
n_ecc_line    | bit | given | 256   | data bits one correction line covers
n_ecc_check   | bit | given | 10    | check bits on that line: nine to locate a single error among two hundred and fifty-six, one more to detect a second
t_scrub       | s   | given | 3600  | period over which the whole core is read and rewritten
n_spare_row   | 1   | given | 64    | spare rows per tier, blown at test
n_redundant   | 1   | given | 1     | whole tiers held in reserve
n_ecc_min     | bit | given | 10    | the fewest check bits that can locate one error among two hundred and fifty-six and detect a second
f_scrub_max   | 1   | given | 1e-4  | the most of the core's bandwidth the scrubber may take before it stops being invisible
n_scrub_margin| 1   | given | 100   | how many times over the scrub must complete between upsets

lam_core      | 1/s | derived | fit_per_bit * C_core_raw              | upsets a second anywhere in the core
t_upset       | s   | derived | 1 / lam_core                          | mean time between them
n_line        | 1   | derived | C_core_raw / n_ecc_line               | correction lines in the core
lam_line      | 1/s | derived | 1 / (t_upset * n_line)                | upset rate in any one line
t_double      | s   | derived | 2 / (lam_core * lam_line * t_scrub)   | mean time to two upsets landing in the same line within one scrub period, which is the only way a correctable machine becomes an uncorrectable one
B_scrub       | bit/s | derived | C_core_raw / t_scrub                | bandwidth the scrubber consumes
f_scrub       | 1   | derived | B_scrub / B_core                      | that as a share of the core's, which is what makes it invisible
t_scrub_period| s   | derived | t_scrub                               | the same figure, under the name 037's starvation bound refers to
f_ecc_line    | 1   | derived | n_ecc_check / (n_ecc_line + n_ecc_check) | overhead of this code
f_ecc_64      | 1   | derived | 8 / 72                                | what a sixty-four bit line would have cost, for the comparison
runtime_repair| 1   | given | 0                                       | whether a line can be retired and remapped while the machine runs. It cannot: the map would have to survive power loss and nothing in this cube is non-volatile
```

## Constraints

```constraints
C-040-1 | t_double > t_life_seconds     | the mean time to an uncorrectable error must exceed the machine's whole life in 086. It does by orders of magnitude, which is the point: scrubbing is cheap here and the alternative -- not scrubbing -- turns a correctable machine into one that accumulates
C-040-2 | f_scrub < f_scrub_max         | the scrubber must be invisible against the core's bandwidth
C-040-3 | f_ecc_line ~= f_ecc_overhead  | the overhead derived here must be the figure 034's capacity chain deducted. Two blueprints agreeing about the same few per cent
C-040-4 | f_ecc_line < f_ecc_64         | the wide line must cost less than the narrow one would, which is the whole reason for choosing it and is asserted so that narrowing the line has to argue
C-040-5 | n_ecc_check >= n_ecc_min      | nine bits locate a single error among two hundred and fifty-six and the tenth detects a second. Fewer means the code cannot do what the rest of this blueprint assumes
C-040-6 | t_scrub < t_upset * 100       | the scrub must complete many times between upsets, or a line can be hit twice before it is ever visited
C-040-7 | runtime_repair == 0           | runtime repair is not available. Asserted as a value rather than left unsaid, so that a blueprint assuming a line can be retired while the machine runs fails outright
```

## What is still open

**`009` entry M1 is not closed.** Per-line correction is chosen and it depends on
`048`'s small control reads not paying a line's latency for a few bytes. `053`
owes a count of small reads per token and has not produced one.

**Runtime repair is abandoned rather than solved**, which is a real reduction in
what this machine can survive: a tier that develops a hard failure in service can
only be handled by the redundant tier, and there is exactly one of those. A
second one costs another twenty-fourth of the capacity and nobody has priced
whether that is the right trade.

**The soft error rate is a sea-level figure with no altitude term.** Cosmic ray
flux roughly doubles every two thousand metres. A machine at altitude sees
several times this rate, and nothing in `086` says where these are allowed to
live.
