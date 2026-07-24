# The Library

This directory holds generated, read-only views over the collection's
history. Nothing in here is edited by hand; every subdirectory is rebuilt by
a script, and the scripts are the thing to fix when a view looks wrong.

## storyline/

One symlink per LLM transcript in the entire collection, named
`YYYY-MM-DD_<project>_<original-name>.md` so that a plain `ls` reads as a
chronology — the storyline of programming from beginning to end, sessions
from different projects interleaving on the days they actually overlapped.

- **Rebuild it**: `../scripts/build-storyline-library.sh`
- **It is gitignored**: the links are pointers into each project's
  `llm-transcripts/` directory (the single source of truth), regenerated on
  demand; tracking hundreds of churning symlinks would bury every commit.
- **Blueprint**: issue 057 (centralized transcript storyline library).
