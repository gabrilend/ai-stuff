# 061-build-embedding-index — info

guide-feature's embedding index builder (issue 502), made by following
`docs/embedding-index-build-guide.md`. Run as:

    scripts/build-embedding-index [--url URL --timeout SECONDS [--key-file FILE]] [--hook NAME ARGS...]

It reads the project's code files at the checked-out commit from git, cuts
them into pieces with their names (060), embeds the names with the
embedder endpoint, and writes `.embedding-index/` beside, checks it, and
swaps it in.

| Function | Meaning |
|---|---|
| `build(opts)` | `root` (the project's folder in a checkout), `log_root`, `endpoint` or `url`/`timeout`/`key_file`, `log`; returns `{ outcome, commit, pieces, files, embedded, reused, model, dimensions, endpoint, seconds }` |
| `describe(result)` | the log line |
| `read_settings(root)` | `input/embedding-index` of the project, read without making RAM tiers in it |
| `where(root)` | the full commit, the project folder's tree, its folder in the repository |
| `files(root, values, place)` | the code files at the commit, with their text and language |
| `endpoint_of(opts)` | the embedder: given, `--url`, or `use.embedder` in the project's `endpoints` |

Outcomes: `built`; `up to date` (the index is the commit's); `renamed` (the
commit did not touch the project's folder, so the same index now names it,
nothing embedded); `busy` (another build of this project holds
`.embedding-index.lock/`; exit 3). A piece whose names are unchanged keeps
its vector. With `--hook`, it never fails (exit 0, the log says what
happened), skips a post-checkout of files, and builds again when the commit
moved meanwhile.

Settings `input/embedding-index`: `extensions`, `shebang`, `skip`,
`piece-lines`, `batch`. Log `tmp/shared-memory/build-embedding-index.log`
and receipt `output/goodbye-build-embedding-index` under `log_root`
(counts: the outcome, `pieces`, `embedded`, `reused`, `milliseconds`, or
`failed`).
