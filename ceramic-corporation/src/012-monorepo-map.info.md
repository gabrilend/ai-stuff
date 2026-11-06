# 012-monorepo-map

Writes the monorepo's queue of open pull requests as an org map.

## What it is for

The project tried on the place it lives. The monorepo has the shape the vision
describes — many projects, one person who merges, a queue of pull requests
many of which are built on others — and the blocked board, run over it, says
which merge or answer frees the most waiting work. `./map-the-monorepo` is the
front door; `scripts/list-open-pull-requests` takes the snapshot.

## The model

| In the monorepo | In the map |
| --- | --- |
| the owner, who merges and answers | `person ritz` |
| the background builder | `person claude` |
| an open pull request | `work pr-N`, held by the owner; its title is its `says` |
| a pull request built on another's branch | `in base - pr-M.merged` |
| one built on a branch no open pull request carries | `in base = "..."`: a fixed value, because nothing blocks it but retargeting |
| a project directory | `role NAME`, held by the builder: its next round of work, which branches from main, so it waits on every open pull request touching it |
| an open question | `work question-NAME`, held by the owner, wired to its project |

## Exports

| Function | Returns |
| --- | --- |
| `read_snapshot(text)` | `{ taken, prs }`, or nil and a message |
| `read_questions(text, file)` | the questions (shared grammar: `question NAME` with `project`, `says`, `source`), or nil and a message |
| `build(snapshot, questions)` | the map's text, or nil and a message when two things would get one name |
| `project_name(dir)`, `quote(s)` | a directory as a map name; a quoted field |
| `main(args)` | `INPUT_DIR ORG_DIR`: writes `ORG_DIR/org.map` |

**Deterministic**: the same input writes the same bytes, so a fresh snapshot's
diff is exactly what changed in the queue. **Two directories that would get one
name are refused**, not merged.
