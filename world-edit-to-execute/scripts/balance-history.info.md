# balance-history.sh

Generates the balance history and its page into
`tmp/shared-memory/balance-history/` (RAM; rebuilt tiers first).

| Option | Does |
|--------|------|
| `[DIR]` | project root (first argument; defaults to the project path) |
| `--open` | opens the page in Firefox afterwards |

Adds `notes.js` from the cached patch notes when `wc3-installs/external-notes/` holds them (never fetches). Prints the page's path. The output is made from the player's own install and
stays on this machine.
