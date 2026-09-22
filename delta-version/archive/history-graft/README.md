# The history graft

On the day this file was committed the trunk was rebuilt so that the projects
which had their own repositories before the monorepo's first commit
(`930edf0d`, "Initial commit: AI project collection") join it
there: their earlier commits were moved into their folders, unchanged in
author, date and message, and became that commit's parents. Every commit
after it received a new id.

- `commits.map` lists every original commit and its new twin, one
  `old new` pair of full ids per line.
- The old trunk is kept, unchanged, as the tag `archive/main-before-history-graft`, and each
  project's last commit before the join as `archive/pre-import/<folder>`, so every
  old id quoted anywhere still resolves.
- Quoted ids in the trunk's files and commit messages were rewritten at the
  same time. To translate ids in a file written elsewhere:
  `delta-version/scripts/graft-project-histories translate <file>...`

The plan and its checks are in delta-version/issues/031-import-project-histories.md.
