# transcript-reader.lua

Reads a saved conversation out of `llm-transcripts/` and hands back its
shape. Text in, table out: it opens no files (except its own list of archived
exceptions) and produces no HTML.

## Public functions

- `read(text) -> conversation` — a whole transcript as a string in, a table
  out. Raises when the text is not a transcript the exporter could have
  written: no session id; no generated-on line (unless archived); a `###`
  heading of an unknown shape under a rule line; a Contents entry of an
  unknown shape. Each of those means the exporter's format moved.
- `first_request(conversation) -> string or nil` — the first thing the person
  said; nil when the transcript holds no request.
- `turn_after_request(conversation, n) -> number` — the index into
  `exchanges` of the turn that begins request n + 1, or the last turn when n
  was the last request. Where a Contents entry "after Request n" points.
- `use_archived_list(set)` — replaces the archived list for this run
  (`find-archived-exceptions` passes an empty one).

## The conversation table

| field | type | what it is |
| --- | --- | --- |
| `session_id` | string | the id of Claude Code's log for the conversation |
| `generated_on` | string or nil | when the file was written; nil only for an archived transcript |
| `header_complete` | boolean | false for an archived transcript, whose missing lines were never written |
| `models` | list of strings | every model that served a reply, first-use order; empty when none was named |
| `contents` | list of tables | the recaps listed at the top: `when` (string, `YYYY-MM-DD HH:MM`), `after_request` (number, 0 = before request 1), `text` (string) |
| `exchanges` | list of tables | every turn, in the order it happened |

## An exchange

| field | type | what it is |
| --- | --- | --- |
| `kind` | string | `"user"`, `"assistant"`, `"recap"` (the summary after a conversation runs out of room), or `"harness"` (lines above the first request) |
| `number` | number or nil | the exporter's exchange number; nil for recap and harness |
| `body` | string | what was said, as markdown, separator lines removed |
| `continued` | boolean | the rest of a reply resumed after running out of room |
| `model` | string or nil | which model served an assistant reply |
| `commits` | list of tables | for an assistant reply, the commits it records making — `hash` (string, abbreviated hex) and `subject` (string) — read from the exporter's `*[commit] <hash> in <repository> - <subject>*` lines; empty otherwise |

## Worth knowing before changing it

- **A `###` line is structure only directly under the exporter's rule line.**
  Models write `###` headings in prose; the rule line is what only the
  exporter writes.
- **The archived list is generated, never hand-edited** — see
  `find-archived-exceptions`. It was empty when first generated: every
  transcript on the machine had a generated-on line.
- Taken from double-diaper-dungeon's `src/047-transcript-reader.lua`; that
  project keeps its own copy (see its `libs/README-vendored.md`).
