# 201 — Request files

phase 2, the gate

## Current behavior

Nothing exists.

## Intended behavior

A Lua module for the file format in `docs/request-format.md`, used by both
computers:

- **make an id** from the time, kind and four random hex digits;
- **write** a request (header table + body) under a temporary name, then
  rename it;
- **parse** a request file into a header table and a body. The body is kept
  as exact bytes; a `write` body may hold anything;
- **check** a parsed request: the general fields, then the kind's own check
  from a table of kind → check function (unknown kind is refused);
- **write and parse answers**.

## Suggested implementation steps

1. Id, write, parse, round-trip test.
2. The general check and one check per kind, in a dispatch table.
3. Tests: each refusal in `docs/request-format.md` "Refusals", one each;
   a `write` body with binary bytes and blank lines survives a round trip.

## Related documents

- `docs/request-format.md`

## Blocked by

101.

## Blocks

202, 203, 302, 602.
