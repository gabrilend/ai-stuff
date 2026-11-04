# neocities-modernization: project instructions

Instructions for any Claude Code session working in this project, on top of
the owner's global CLAUDE.md. Written 2026-10-20 at the owner's request.

## Word-cloud records ride along in every commit

Every build writes a small text record of its word cloud into
`archive/wordclouds/` (Issue 10-073). Treat these like the
`llm-transcripts/`: low priority, but kept in git whenever we can. (Owner:
"treat them like llm-transcripts. They are low priority, but should be kept in
git whenever we can.")

So, before every commit in this project, whatever the commit is about:

1. List the records git does not have yet:
   `git -C <repo> status --short -- neocities-modernization/archive/wordclouds/`
2. Claim each new or changed record as this session's change:
   `/home/ritz/programming/ai-stuff/scripts/claim-own-change <file>...`
   (they are written by the build, a route the edit ledger cannot see).
3. Commit as usual with `commit-own-changes`; the records go in with the
   work, and the commit message says in one line that they rode along.

Records are never edited by hand once committed, only added.
