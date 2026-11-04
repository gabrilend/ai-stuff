# 304 — Git sync: main out, work in

phase 3, the link

## Current behavior

Nothing exists.

## Intended behavior

Two more steps in the courier's visit (`docs/datapath-steward.md`,
"Branches"):

- **work in**: `git fetch` the distant clone's `distant-work` branch into
  `refs/distant/work` on kuvalu. Each commit on it that is not yet on
  `main` and has no request yet gets a `commit` request written into the
  gate's `incoming/` by the courier on the steward's behalf, using the
  commit's own message as the reason.
- **main out**: `git push` kuvalu's `main` to the distant clone's `main`.
  The distant clone's `main` is only ever moved by this push.

The push and fetch go to the monorepo, which other sessions on kuvalu also
commit to. The courier never commits, never touches the working tree, and
never touches the shared staging area. It only moves refs.

## Suggested implementation steps

1. Fetch and listing of new commits, tested on two throwaway repositories.
2. Request writing for each new commit; no duplicate when a visit repeats.
3. Push of `main`; a test where the distant `main` was moved by hand shows
   the push refuses (not forced) and the courier reports it.

## Open questions

- Should the courier ever force-push the distant `main`? The design says no:
  a refused push is a sign that something wrote there that should not have.

## Related documents

- `docs/datapath-steward.md`, `docs/datapath-gate.md`

## Blocked by

202, 301, 302.

## Blocks

305, 602.
