# 035-to-voices — info

Each new version, mailed to the voices (issue 303): a publisher in the
blitter's list that rewrites `outbox/the-canvas` in the guide mailbox, one
living rmail message with a `to:` line for each voice in `input/blitter`,
by a dot name (rmail skips those) and a rename. The body is the version in
the to-voices form (`docs/canvas-format.md`): `canvas`, `size`, `mode`,
`project` (the commit read from the project's checkout at every version),
`written`; the rows; the marks; with tell-the-voice on, a `cuts:` section
with each voice's cut words from its latest turn that landed; and an
`endpoints:` section, each voice's endpoint line from a fresh read of the
project-root `endpoints` file at every version (issue 402). A voice whose
endpoint cannot be given a line gets none, and the log says why. A file
that cannot be read sends the version with an empty section, logged and
counted as `versions-without-endpoints`.

`input/to-voices`, read when the blitter starts:

| Setting | Type | Meaning |
|---|---|---|
| `send` | `on` / `off` | mail every version, or nothing |
| `mailbox` | text | the guide mailbox's folder (`~` is home) |
| `tell-the-voice` | `on` / `off` | the `cuts:` section |
| `project-checkout` | text | the project's git checkout, for its commit |

| Function | Meaning |
|---|---|
| `publisher(opts)` | the publisher, or nil and why (send off). Refuses a missing mailbox, a voice with no contact, an `endpoints` file that cannot be read, or a folder that is not a checkout. `opts.root`, `opts.voices` |
| `body(record, commit, cuts, endpoints)` | a version's to-voices text |
| `endpoint_lines(root, voices)` | each voice's endpoint line now, and the reasons for any voice left out |
| `message(voices, body)` | the outbox file's text |
| `commit_of(checkout)` | seven hex digits, or nil |

The blitter's receipt counts `versions-to-voices`.
