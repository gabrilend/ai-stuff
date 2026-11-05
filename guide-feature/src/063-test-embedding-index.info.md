# 063-test-embedding-index — info

Tests the embedding index (issue 502): 060's rules and files, 061's
builder, 062's checker and hooks, against a stand-in embedding server
(047) on 127.0.0.1.

    luajit src/063-test-embedding-index.lua --dir ROOT

- **names-v1** in Lua, shell and C; a query; languages by extension and
  `#!`.
- **pieces-v1**: folds, functions at the left edge, shell functions, long
  pieces cut, nameless ones left out.
- **The files**: written and read back, and each thing the checker refuses.
- **The builder** in a throwaway monorepo: the commit's index, not the
  working tree's; the files it skips; up to date; renamed for a commit to
  another project; only a changed piece embedded; batches; the endpoints
  file's embedder; refusals that leave the index as it was; one build at a
  time, and a stale lock taken over.
- **The hooks**: added beside an existing hook and before its exit, once;
  a commit rebuilding the index in the background; removed again.
- **guide-feature's own index**, built from the project's files as they are,
  which is checked and has the clone keeper's choice of RAM as a piece.

About 15 seconds. `KEEP=1` keeps the throwaway folder after a failure.
