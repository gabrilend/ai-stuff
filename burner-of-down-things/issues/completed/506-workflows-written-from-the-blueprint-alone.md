# 506 — Workflows written from the blueprint alone

The design is checked by people's-eye workflows written by a turn that has
never seen the design, not by tests the builder wrote for itself.

> the user is expected to test their own application. The system should
> make workflows that use the same types of input that the user would
> provide, to test behavior from end-to-end. We don't have to test against
> the real product, we just have to describe how it works, and then utilize
> that description to build our own to solve the same problem, but in our
> own way, that is customizable as we go. Protocols, not procedures.
>
> — the owner, 2026-09-27, answering "what proves a rebuilt Dropbox
> behaves like Dropbox?"

The problem this fixes, from the strategem *other people's software as a
rubric* (rao-chat and wow-chat-2026): "a referee that shares code with the
thing it checks grades nothing." Until now each issue's acceptance command
runs a test file the build turn wrote in the same turn as the code; a turn
could write broken code and a test that passes it.

## Current Behavior

Built as `src/063-workflows.lua`, the `referee` kind in `src/034-turn-kinds.lua` (reads only `blueprint/`, writes only `workflows/`), the case's `workflows/` folder, and delivery in `src/050-building.lua`; `src/055-updating.lua` rewrites the workflows after every amend. The fixture referee (`tests/fixtures/tiny-notes-referee.lua`) writes five workflows for the notes program from the blueprint as the case holds it, so an amended blueprint changes what they expect. Two fixture switches exercise it: `quiet_bug` (201 built with the tags dropped and its own test weakened to match — its acceptance passes, workflow 02 catches it) and `toothless_referee`. Checked by tests/064 (22 checks) and shown as case three of the phase 5 demo. While building it, a real bug surfaced and was fixed: the person's `input/crafts` file would have been taken as a change request. One coarseness is recorded as docs/010 question 9: a failing workflow repairs every issue it covers, not only the one at fault.

## Intended Behavior

- **A referee turn** (a new turn kind, `referee`) reads the blueprint and
  nothing else — not the source, not the design — and writes end-to-end
  **workflows** into the case's `workflows/` folder. The design folder is
  where build turns write; `workflows/` is outside it, so a build or repair
  turn that touched a workflow would be a breach.
- **A workflow** is a shell script, `NN-<name>.sh`, run from the design
  folder, that uses the design the way a person would — the commands a
  person types, the files a person hands it — and checks only what a person
  could observe: output, files, exit status. Protocols, not procedures: it
  never calls the design's internal functions. Its second line names the
  issues whose behaviour it exercises: `# covers: 201 301`. Exit 0 is a
  pass.
- **Teeth:** when written, every workflow is run against an empty design (a
  scratch folder with nothing in it) and must fail there. A workflow that
  passes an empty design grades nothing and is sent back.
- **Delivery** now needs, after every issue's own acceptance passes, every
  workflow to pass. A failing workflow gets repair turns for the issues it
  covers, shown the workflow's name and output but not its text, up to two
  rounds; still failing, the design is not delivered and the ledger says
  `workflow-failed`.
- **Updates:** after a request's amend, the workflows are written again from
  the amended blueprint before the reach is rebuilt, so the rebuilt design
  is checked against the changed behaviour.
- The issues' own acceptance commands stay: they are the builder's checks
  on its own work, useful for repair, but no longer what delivery trusts.

| Decision | What each path leads to |
|---|---|
| A referee turn writes no workflow, or one without a `# covers:` line naming real issues | A new referee turn with the findings, up to three; then `referee-failed` and the design cannot be delivered |
| A workflow passes against an empty design | Same: sent back as having no teeth |
| A build or repair turn writes into `workflows/` | Breach, like any write outside its folders |
| A workflow fails after the repairs | `workflow-failed`, not delivered; the issues it covers are named in the goodbye |

## Suggested Implementation Steps

1. The `referee` kind (reads `blueprint/`, writes `workflows/`) and the
   case's `workflows/` folder. **Test:** no build or repair turn can write
   there; the referee cannot read the source or the design.
2. Writing workflows, with the covers and teeth checks. **Test:** a stand-in
   referee whose first workflow passes an empty design is sent back.
3. Running workflows at delivery, with repair of covered issues. **Test:** a
   build whose own tests pass but whose behaviour breaks a workflow is
   repaired and then delivered; one that never passes is not delivered.
4. Rewriting workflows after an amend. **Test:** the fixture's count-in-list
   request changes the listing workflow, and the rebuilt design passes it.
5. Fixture workflows for tiny-notes, written from its blueprint alone, with
   amended versions for each fixture request.

## Blocked by

- 503
- 504

## Related documents and tools

- [007 — The design](../docs/007-datapath-the-design.md)
- `/home/ritz/programs/rao-chat/strategems/other-peoples-software-as-a-rubric.md`
