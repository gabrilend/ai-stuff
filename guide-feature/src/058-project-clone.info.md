# 058-project-clone — info

The clone keeper (issue 501): each voice's git clone of the project the
canvas names, at the commit it names, in RAM if it fits. The turn (055)
calls it at its start (step 2); `scripts/project-clone` runs it by hand:

    scripts/project-clone --voice NAME --project NAME --commit COMMIT

| Function | Meaning |
|---|---|
| `keep(opts)` | the keeper: `root`, `voice`, `project` (`{ name, commit }`); returns `{ place, path, project, made, fetched, checked_out, moved, was, full, bytes, estimate, why, seconds, index, ... }`, raises with the reason |
| `describe(kept)` | the log line |
| `bring_index(kept)` | the project's embedding index copied from the source into the clone (503): `{ state = "already" \| "copied" \| "behind" \| "none" \| "failed", why, pieces, commit, renamed }`; never raises. `keep` calls it unless `opts.index` is false, into `kept.index` |
| `describe_index(kept)` | the index's log line |
| `on_host(repository, command)` | a shell command run where the source is: here, or over SSH |
| `choose(opts)` | RAM or disk for a new clone, the reason, the numbers |
| `measure(repository, commit, folder)` | the project folder's bytes and files at the commit on the source, and the commit's full name |
| `on_source(repository, git_args)` | the shell command for git on the source: here, or `ssh -o BatchMode=yes HOST` |
| `parse_repository(address)` | `{ host, path }` from `HOST:/PATH` or a path here; refuses URLs |
| `path(root, text)` | a folder setting as a path (`~/`, `/`, or under the root) |
| `memory()`, `filesystem_of(path)`, `free_space(path)`, `size_of(path)` | the machine's readings; `keep` takes the first three as seams |
| `size_text(bytes)` | `1.5 KiB` and the like |

A clone holds one commit at a time: fetched by its full name with
`--depth 1 --filter=blob:none`, sparse to the project's folder, the filter
asked of the source's `upload-pack` with `uploadpack.allowFilter`. RAM is
`ram-folder` when it is a tmpfs that can be written and the estimate (the
folder's files twice) plus `working-room` fits `ram-share` of
`MemAvailable`; a RAM clone measured too big once made is moved to disk.

Settings: `input/project-clone`: `repository.NAME`, `folder.NAME`,
`ram-folder`, `disk-folder`, `ram-share` (decimal, above 0 to 1),
`working-room` (MiB). Clones go in `<folder>/<voice>/<project>`.

Exit status of the program: 0 kept, 1 refused (the reason on stderr),
2 wrong arguments.
