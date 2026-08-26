# 301 — The shape of a ComfyUI graph

## Current behavior

Everything needed to describe a picture exists. Nothing can write it in the form
the program that makes pictures reads.

## Intended behavior

**One description of a graph, emitted in both formats ComfyUI accepts.**

`docs/005` has the formats and the reason both are needed: the API format is what
a script posts, the UI format is what a human opens, and neither converts to the
other without facts that live outside both.

**The node catalogue is the substance of this ticket.** For each node type this
project uses: its input sockets in slot order with their types, its output sockets
in slot order with their types, and the order of its widget values. The UI format
identifies links by slot index, so a catalogue that lists sockets in the wrong
order produces a graph that loads cleanly and is wired wrong.

**And the interface-only widgets are marked**, which is the trap `docs/005`
describes at length. `KSampler` draws a control after its seed that occupies a
slot in `widgets_values` and corresponds to no field in the API format. Emit the
array without it and the step count lands in the CFG scale. The file loads. The
pictures are wrong in a way that looks like bad settings.

The builder itself is small: make a node of a named type, connect an output slot
to an input slot, set a widget by name, then emit. Connecting a socket that the
catalogue does not list, or connecting types that do not match, is an error at
build time — a mistyped socket name silently producing an unconnected input is
the failure this catalogue exists to prevent.

**Layout is computed, not authored.** Nodes are placed by walking the graph in
dependency order and putting each one to the right of everything it depends on.
A workflow that opens as a legible left-to-right pipeline is worth the twenty
lines, and hand-placed coordinates would be wrong the moment a node was added.

## Suggested implementation steps

1. **`src/028-the-shape-of-a-graph.lua`** — the catalogue, the builder, the two
   emitters, the layout pass.

2. **The catalogue covers about a dozen node types**, being the ones `302` uses,
   and does not aspire to cover ComfyUI. A node type that is needed and absent is
   an error naming the type, which is a five-line fix at the moment it is needed
   and is better than a catalogue full of guesses.

3. **Both formats come from one traversal.** Emitting them separately means two
   pieces of code that agree until one is edited.

4. **Test that the two formats describe the same graph**, by walking each and
   comparing the set of connections. That is the assertion that catches slot
   indices drifting from socket names, and it needs no ComfyUI to run.

## Related

`docs/005` — the formats and the catalogue's justification. `106` — ordered JSON.
