# 029-the-survey.lua

Reads a whole source across every core and writes the survey's two tables.

| Name | In | Out |
|---|---|---|
| `read_source(project, root, threads, limit)` | paths table; source folder; thread count or nil (all hardware threads); file limit or nil | file rows text, link rows text (escaped, newline-joined, path order), slices used, file count |
| `run(project, case, threads)` | paths table; case table; thread count or nil | writes `survey/files.tsv` and `survey/links.tsv`; returns `{ files, links, threads }` (numbers) |
| `FILE_HEADER`, `LINK_HEADER` | | `path language role lines bytes`; `from to kind inside` |

Entries are dealt round-robin to worker threads (effil); each row comes back
tagged with its walk number and is put back in walk order, so output is
identical at any thread count. Refuses when the thread library cannot load.
