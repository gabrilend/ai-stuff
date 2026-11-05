# 065-test-look — info

Tests the look tool (issue 503, 064) and what it stands on: the embedder's
line in the canvas (035, 046), the clone keeper copying the index (058),
and the turn answering look calls (055), against stand-in llama.cpp
servers (047) on 127.0.0.1.

    luajit src/065-test-look.lua --dir ROOT [--write-references]

- **Choosing by focus**: the counts and reach at 1, 0.5 and 0, a project
  with fewer pieces than chosen, every focus and size, the focus words, and
  `input/look`'s refusals.
- **Scoring and answering**, on an index made by hand: nearest first, the
  labels, the words embedded as their names, the budget (a longer piece
  left out, a shorter one after it in), a file missing from the clone.
- **Every refusal**, with no pieces in it.
- **The embedder's line**: written last when `endpoints` has
  `use.embedder`, none without it, none with no timeout (and why), read as
  an embedding endpoint.
- **The keeper**: no index at the source, copied, already there, copied
  and renamed for a commit to another project, behind for one to the
  project (and a look refused), copied once rebuilt, a copy per voice, two
  copies that do not check.
- **The turn**: a model that looks focused, then broad, then writes; the
  pieces in its prompts; the log and the receipt; a canvas with no embedder.
- **guide-feature's own index** at commit be7b82761 (issue 502's): "canvas
  width" at focus 1, 0.5 and 0, compared with `assets/test-looks/`, and the
  sets visibly different. Skipped, saying so, in a checkout without that
  commit.

About 5 seconds. `KEEP=1` keeps the throwaway folder after a failure.
