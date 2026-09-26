# 019-the-machine.lua

The entry point, run by the root `machine` launcher with the project folder
and a command. Holds the command table (docs/012) and the shape of every run:

1. list the project's `input/` into the scratch log;
2. for a command on a case: load it, find new requests in its `input/`,
   take the lock, verify the ledger, then note the requests in the ledger;
3. run the command;
4. write the case's `output/goodbye` and the project's `output/goodbye`
   (done, waiting, failed), append `goodbye` to the ledger — only if the run
   held the lock over a verified ledger — and drop the lock.

A failure anywhere still produces steps 4's files, and the process exits 1.

Command rows: `run(run)`, `needs_case`, `usage`, `what`. A **run** table:
`command` (string), `args` (array of strings), `project` (paths table),
`case` (case table or nil), `say` (print function), `done`, `waiting`,
`failed` (arrays of sentences for the goodbye), `may_append` (boolean).

Later phases add rows through `LATER_COMMAND_MODULES`: each module returns a
table of rows keyed by command name.
