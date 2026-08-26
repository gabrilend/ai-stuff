# 089 — The one page somebody reads

```meta
phase  | 13
issues | 1303
```

**One page. Generated, not written.** Every figure pulled from the ledger by
`097`, so that it cannot disagree with the design it describes.

## What is on it

| | |
|---|---|
| **Physical** | edge length, mass, volume, mounting |
| **Power** | input voltage and current, dissipation at three operating points |
| **Cooling** | fluid, flow, pressure, inlet temperature, heat rejected |
| **Memory** | usable capacity, aggregate bandwidth |
| **Compute** | operations a second, at the stated numeric format |
| **Storage** | line count, aggregate, model load time |
| **Output** | grade, width, pane size, whole-core transfer time |
| **Performance** | tokens a second, one sequence and aggregate; prompt rate |
| **Model** | the largest that fits, at stated context and batch |
| **Life** | target, and the annual replacement rate implied |

## The two figures that mean the most

**Tokens a second on one sequence** — what one person waits — and **the largest
model that fits**.

The sheet must say what happens past the second one, because `059` chose refusal
over degradation and **a specification that gives a maximum without saying what
lies beyond it invites somebody to try.**

## What a good specification sheet also does

**Says what it is not.** No operating system, no protection, no general-purpose
computing, no training beyond low-rank adaptation, unremarkable capacity next to
its bandwidth, and no field-serviceable parts. Five sentences that save everybody
a month.

**Names its own assumptions.** Every figure is for the reference model at the
reference context and batch. `078`'s surface and `080`'s sensitivity table are
where the other cases live.

**Gives the comparison honestly** — both halves. Eleven times on memory bandwidth,
which is the win. About half on capacity, which is not.

## Why generated

Because a specification sheet is the document most likely to be copied into a
slide, quoted in an email, and believed a year after it stopped being true. If it
is regenerated from the ledger every time, **the copy in the slide is at least
wrong in a way somebody can date.**

## Symbols

```symbols
n_sheet_row   | 1 | given | 10       | sections on the sheet
n_sheet_not   | 1 | given | 5        | sentences in the what-it-is-not section
n_sheet_own   | 1 | given | 0        | symbols this blueprint declares of its own. It is a view, and a view that invents a number has a bug
n_sheet_fig   | 1 | given | 34       | figures on the sheet, every one of which must resolve to a symbol declared elsewhere

f_headline_bw | 1 | derived | gain_bw                     | the ratio the sheet leads with
f_headline_cap| 1 | derived | gain_cap                    | and the one it must not omit
r_sheet_single | 1/s | derived | tok_s_single             | tokens a second, one sequence, as the sheet prints it
r_sheet_agg   | 1/s | derived | tok_s_agg                 | and aggregate
C_sheet_model | GB | derived | C_weights                  | the largest model that fits, as weights
m_sheet       | kg | derived | m_cube                     | mass
P_sheet       | W | derived | P_heat                      | power drawn, and heat rejected, which are the same number
```

## Constraints

```constraints
C-089-1 | n_sheet_own == 0            | this blueprint declares no symbols of its own beyond views of other people's. Asserted as a value, because the failure mode of a summary document is a number that appears only in it
C-089-2 | f_headline_cap < 1          | the capacity comparison must be the losing one and must still be on the sheet. A sheet quoting only the bandwidth ratio would be selling something this machine is not
C-089-3 | n_sheet_not >= 5            | at least five sentences saying what the machine is not. They save everybody a month and they are the first thing a summary drops
C-089-4 | r_sheet_agg > r_sheet_single | aggregate throughput exceeds single-sequence throughput, which is trivially true and is here because the sheet prints both and a reader must not confuse them
C-089-5 | P_sheet ~= P_input          | the power the sheet prints must be what the machine draws, which is also what it rejects as heat
C-089-6 | n_sheet_fig > 30            | the sheet must carry enough figures to be a specification rather than a headline
```

## What is still open

**The template does not exist as a file.** This blueprint says what is on the
sheet and `097` is what would render it; the template itself — the actual page
with symbol names in it — is `097`'s to carry and is not written.

**One sheet, one configuration.** Every figure is the reference model at the
reference context and batch. A machine sold in speed grades, or with a chiller
and without, would need several — and `074` and `027` are still arguing over the
thermal margin that would produce exactly that split.
