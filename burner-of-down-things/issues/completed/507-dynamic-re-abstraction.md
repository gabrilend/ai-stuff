# 507 — Dynamic re-abstraction

When a workflow fails, find the part at fault by looking narrowly first,
widening the view only when the narrow look finds nothing, and narrowing
again to fix. Replaces repairing every issue a failing workflow covers.

> do a small audit of the functionality to ensure that we didn't design it
> wrong. If no fixes are required, then the code won't change. Compare a
> before/after checksum of just that component, and if it's the same for all
> three, then combine them into groups of 2 (if there's one left over, then
> ignore it, because it's already been analyzed) and try again. The grouping
> is to see if there's a relationship between two of the components,
> selected randomly. If no, then try merging again. At this point in the
> example of three, there'd be one group. We'd then try and find the flaw in
> the one, massive group, which is harder, but, this is what happens when we
> can't fix it individually, we gotta look at the bigger picture. Once we
> identify the part that needs a fix, not what the fix is just the part that
> needs it, then we reduce our view again until we're within fixing range.
> Then we apply the fix. Dynamic re-abstraction.
>
> — the owner, 2026-09-27, answering open question 9

## Current Behavior

Built as `src/065-re-abstraction.lua`, with the `audit` and `inspect` kinds in `src/034-turn-kinds.lua`, the `audited` and `inspected` ledger kinds, and delivery in `src/050-building.lua` running one search per failing workflow in place of repairing every covered issue. One decision beyond the owner's words, recorded here: if an audit changed the design but the workflow still fails, the narrow audits get one more pass over the design as it now is before the view widens — a change means a narrow look found something, so the narrow range is tried again before the bigger picture. The fixture gained `audit` and `inspect` turns and two switches: `hidden_bug` (no audit alone sees the fault; a group holding 201 names it) and `unfindable_bug`. Checked by tests/066 (25 checks): the seeded shuffle, the owner's example of three as a ladder (one pair with the odd one left out, then all three), a fault fixed by one narrow audit with no wider look, a hidden fault named by an inspection and fixed by narrowing back, and a fault nobody finds ending `workflow-failed` after a look at all three. Shown as cases three and four of the phase 5 demo.

## Intended Behavior

For one failing workflow, covering issues C:

1. **Narrow: an audit of each issue alone**, one at a time, in the order a
   seeded shuffle gives (below). An `audit` turn sees the blueprint, the
   design, the workflow's name and output; it may change only its own
   issue's part, and must change nothing when the fault is not there. A
   checksum of the design before and after says whether it changed
   anything. After every change the workflow runs again; passing ends the
   search.
2. **Widen:** if no audit changed anything, the issues are paired at random;
   an odd one out is left out (it has already been looked at alone). Each
   pair gets an `inspect` turn: it sees both issues and the design, writes
   no code, and answers with the one issue whose part needs the fix — not
   the fix — and why, or `none`.
3. **Wider:** if no pair names a part, groups are merged pairwise again, and
   so on until one group holds every issue in C: the bigger picture, harder
   to look at, looked at last.
4. **Narrow again:** the first inspection that names a part hands its finding
   to an audit of that one issue — back within fixing range — and the fix
   is applied there. The checksum and the workflow say whether it worked.
5. If the widest look names nothing, or the named audit changes nothing and
   the workflow still fails, the workflow is `workflow-failed`.

**Random, and predictable:** the shuffle and the pairing are seeded from the
ledger's head hash when the search begins, so anyone holding the ledger
gets the same order — the center's rule, applied here.

Every audit and inspection is recorded: `audited` (about the issue; text
"changed" or "unchanged") and `inspected` (about the group, e.g. `102+201`;
text the named issue or `none`, and why).

| Decision | What each path leads to |
|---|---|
| An audit changes the design and the workflow now passes | Search over; the workflow is fixed |
| An audit changes the design but the workflow still fails | The search goes on with the design as it now is |
| No audit at one issue changes anything | Widen to pairs |
| An inspection names an issue outside its group, or writes no answer | Treated as `none` |
| The widest group names nothing | `workflow-failed` |

## Suggested Implementation Steps

1. Turn kinds `audit` (reads blueprint and design, writes design) and
   `inspect` (reads blueprint and design, writes only its turn folder).
   **Test:** an inspect turn cannot change the design without a breach.
2. The seeded shuffle and the grouping ladder (1, 2, 4, … up to all).
   **Test:** three issues give levels [a][b][c], then one pair with one left
   out, then all three; the same seed gives the same order.
3. The search. **Tests:** the quiet bug in 201 is fixed by 201's audit alone
   and 102 and 301 are never touched once it passes; a hidden bug that no
   single audit finds is named by an inspection and fixed by the narrowed
   audit; a bug nobody finds ends `workflow-failed`.
4. Replace the "repair every covered issue" rounds in delivery with the
   search.

## Blocked by

- 506

## Related documents and tools

- [007 — The design](../docs/007-datapath-the-design.md)
- [010 — Open questions](../docs/010-open-questions.md), question 9
