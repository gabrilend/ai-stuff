# Conversation Summary: agent-a8e10c1a768578142

Generated on: 2026-09-26 12:47:43
Models: claude-fable-5-1

--------------------------------------------------------------------------------

### User Request 1

Your directive: You are filling in the bodies of the phase 7, 8 and 9 issue
files for supcom-derivative-clone: issues 701 through 708, 801 through 806, and
901 through 904. The frames already exist under
/mnt/mtwo/programming/ai-stuff/supcom-derivative-clone/issues/ (created by
./new-issue --from-list from the issues.list you saw). Each frame has a heading
line, a metadata table (Phase, Blocked by, Blocks, Reads, Open questions), and
TODO sections.

For each of the eighteen files:
1. Read the frame with cat so you keep its heading and metadata table EXACTLY as
   written (the validator compares the title to the roadmap, and the Blocks
   column was computed as the inverse of Blocked by).
2. Overwrite the file with `cat > path <<'EOF'` keeping the heading and the
   table verbatim, then write these sections: `## Current behavior` (present
   tense; today it is "Nothing." plus what already exists that bears on it: the
   test program — tests/025-other-players.lua, tests/026-the-handheld.lua,
   tests/027-an-opponent.lua — the document it reads, and for 805 the `compile
   --target handheld` script at the root which already refuses by name until
   libs/900-cera.c, the soren-ds cross-toolchain, and a maps/ directory exist;
   for 707 and 806 the current behavior must say plainly "design pending details
   on soren-ds wifi capabilities" and list the five unknowns from
   docs/011-other-players.md), `## Intended behavior` (the mechanism,
   concretely, and why — the blueprint), `## Suggested implementation steps`
   (numbered; name the source stems from docs/014-the-tests-come-first.md's
   table — lockstep, transport-loopback, discovery, the-bot — and their
   exports; for phase 8 the map file format of the ceramic core engine as
   described in docs/012 and the minimal-soramech README you read: station
   lines, `in`/`out` port lines, `$` for program arguments, boxes as plain C
   functions in src/boxes/ that may not remember anything, a maps/ directory in
   this project, the pinned engine files libs/900-cera.c and libs/901-cera.h
   installed by ./install-dependencies; prefer listing functions/data structures
   over code snippets), `## Related documents and tools` (bullet links, relative
   paths like `../docs/011-other-players.md`, `../docs/012-the-handheld.md`, the
   test file, and for 805 `../compile` and `../input/dependencies`), `## Still
   open` (restate each open question cited in the table, plus anything the issue
   itself raises).

Design points to honour: lockstep — every machine runs the whole simulation,
only tick-stamped commands cross the wire, a command is stamped tick+delay and
sent at once, a machine advances tick T only when it holds every peer's batch
for T including empty ones, a command for a past tick is refused by name, hashes
exchanged every so many ticks and a mismatch halts naming the tick and writing
both snapshots to the RAM tier, a dropped peer rejoins by replaying the command
log; UDP datagrams through LuaJIT's socket library on a computer with
resend-on-request and batches kept until acknowledged; discovery by broadcast
announcement on a periodic counter with aging; the handheld transport is the
soren-ds peer-named UDP port abstraction with the same lockstep code above it;
the loopback transport for tests delivers in order with no wire. Phase 8: the
simulation as hand-ported C boxes with the Lua as reference (G1 direction set),
each tick system a pure function that writes only its slice (the phase 8 test
asserts this on the Lua first), the map file wiring the systems in the tick's
order, two screens with top wide / bottom close-and-touched as the working
ruling, the energy menu on a drawer's radial menu (G2 working ruling), patterns
drawn with the stylus issuing one placement command, and the build steps that
`compile --target handheld` will grow. Phase 9: the bot sees only the snapshot
and issues commands through the door; two bots — a cheap deterministic
measuring one and one built to be played against — kept apart; ten thousand
matches overnight with one worker per core writing one line per match to
tmp/shared-memory/; difficulty from decision quality only.

House rules: LuaJIT source in src/, numbered by ./new-source-file, every file
with a .info.md companion, functions in vimfolds, dispatch tables over branches,
errors over fallbacks, comments say why. No balance numbers in prose. Refer to
issues by number; link only to documents that exist in docs/. Do not edit any
other file, do not touch the phase progress files, do not run git.

Keep each issue between roughly 45 and 100 lines. Write in the voice of the
existing documents. When done, reply with one line per issue saying what its
intended-behavior section commits to.

--------------------------------------------------------------------------------

*You've hit your session limit · resets 1am (America/Los_Angeles)*

--------------------------------------------------------------------------------

