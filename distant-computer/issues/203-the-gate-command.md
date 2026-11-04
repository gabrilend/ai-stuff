# 203 — The gate command

phase 2, the gate

## Current behavior

Nothing exists.

## Intended behavior

`scripts/gate`, the owner's way to answer requests. It is a viewer over the
gate module, holding no gate logic of its own:

    gate                         list waiting requests: id, kind, from, reason
    gate show <id>               the kind's reader
    gate approve <id> ["note"]   answer approved
    gate decline <id> "note"     answer declined; a note is required, so the
                                 steward learns why
    gate note <id> "text"        a ledger note about a request (e.g. what the
                                 owner did for an outward one)
    gate -I                      walk the waiting requests one at a time and ask
    gate --help

Standard `${DIR}` handling: a hard-coded project path at the top, and an
optional first argument to replace it.

## Suggested implementation steps

1. The bash entry point calling a Lua main.
2. Sub-commands as a dispatch table.
3. `-I` mode using the house `scripts/libs/menu.lua` if it fits.
4. Tests calling each sub-command against a throwaway gate.

## Related documents

- `docs/datapath-gate.md`

## Blocked by

201, 202.

## Blocks

204, 901.
