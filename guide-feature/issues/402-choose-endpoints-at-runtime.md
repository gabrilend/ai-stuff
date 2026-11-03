# 402 — Choose endpoints at runtime, including outside providers

phase 4, the turn

## Current behavior

The endpoints file and reader exist (401), and every role points at
kuvalu.

## Intended behavior

- **`scripts/use-endpoint ROLE NAME`**: checks the endpoint answers, then
  rewrites the one `use.ROLE` line in `endpoints` (temporary file, then
  rename). The next turn of that role uses it, with nothing restarted. It
  prints the old and new choice.
- **`scripts/list-endpoints`**: every endpoint, its kind, whether it answers
  now, and which roles use it.
- **Outside providers**: an endpoint with a `key-file`. The key is read from
  that file, which lives outside the repository, at the start of each turn,
  and sent as the provider requires. A missing or unreadable key file is an
  error for that turn. Under the owner's router rules
  (`docs/network.md`), an outside provider is reachable only on connections
  a voice opens, and that is the only way the model caller uses it.

Every turn records the endpoint it used in the log and goodbye receipt, so a
canvas's history can be traced to the models that wrote it.

## Suggested implementation steps

1. The two scripts.
2. Key handling in the model caller.
3. Tests: switching a role between two endpoints while the rehearsal runs
   (the switch shows in the next turn's log); a missing key file.

## Related documents

- `docs/endpoints.md`
- `docs/network.md`

## Open questions

- None left: kuvalu names each voice's endpoint in the canvas it sends
  (`docs/endpoints.md`).

## Blocked by

401.

## Blocks

406, 703.
