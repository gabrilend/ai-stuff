# Phase 6 progress — the listening porch

Goal: prose learns to knock — grammar-constrained local models
translate plain English to scene scripts, three independent readings
face the wall and stand as thumbnails beside the prose, the person
picks, and a spoken vision renders beside the typed one.

- [~] 601 prose-to-scene translator — IN PROGRESS: grammar, prompt,
      collector, retry loop, roster reader, and (2026-10-31) the live
      door to llama.cpp's server with `./porch` in front, all proven
      against fakes; waits on a run against a real model on her
      machine (steps in the issue).
- [ ] 602 three readings — 601's live transport is built; waits on
      a first run of it.
- [ ] 603 spoken-vision demo (capstone) — blocked on the cluster.

The porch stands and listens to fakes fluently; when gabrilend
lights the orchestrator and copies cluster.example to cluster with
a real door named, the last mile is one thin HTTP adapter.
- [~] 604 say it and see it — IN PROGRESS: `./say` types prose into a
      box, teaches every unknown word at once (one Claude Code session
      and one `words/` file per word), records them in the tracker (605),
      has a director session draw the gif, shows it in the LÖVE viewer
      and chats until it is right. Word files and `pattern{}` (604a) and
      the unknown-word finder (604b) complete; the rest built and proven
      with stand-ins, waiting on a first run with real sessions.
- [ ] 605 the growing vocabulary — the tracker `say` keeps; open until
      someone moves it to completed, reopened by the next new word.
