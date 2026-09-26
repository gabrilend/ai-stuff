# Conversation Summary: agent-aef2b598721e5d0d0

Generated on: 2026-09-26 12:47:43
Models: claude-fable-5-1

--------------------------------------------------------------------------------

### User Request 1

Your directive: You are filling in the bodies of the phase 4 and phase 5 issue
files for supcom-derivative-clone: issues 401 through 407 and 501 through 506.
The frames already exist under
/mnt/mtwo/programming/ai-stuff/supcom-derivative-clone/issues/ (created by
./new-issue --from-list from the issues.list you saw). Each frame has a heading
line, a metadata table (Phase, Blocked by, Blocks, Reads, Open questions), and
TODO sections.

For each of the thirteen files:
1. Read the frame with cat so you keep its heading and metadata table EXACTLY as
   written (the validator compares the title to the roadmap, and the Blocks
   column was computed as the inverse of Blocked by).
2. Overwrite the file with `cat > path <<'EOF'` keeping the heading and the
   table verbatim, then write these sections: `## Current behavior` (present
   tense; today it is "Nothing." plus what already exists that bears on it: the
   test program — tests/022-the-cloud.lua for phase 4,
   tests/023-the-big-things.lua for phase 5 — and the document it reads), `##
   Intended behavior` (the mechanism, concretely, and why — the blueprint),
   `## Suggested implementation steps` (numbered; name the source stem from
   docs/014-the-tests-come-first.md's table — the-cloud, plane-upgrades,
   experimentals — the exports the tests call, the fields and their types, the
   mission dispatch table rows; prefer listing functions/data structures over
   code snippets), `## Related documents and tools` (bullet links, relative
   paths like `../docs/007-the-cloud.md` and
   `../docs/009-enforcers-and-experimentals.md`, and the test file), `## Still
   open` (restate each open question cited in the table in one sentence, plus
   anything the issue itself raises).

Design points to honour: the cloud is one place above the field's centre; planes
are unit rows with the air domain and a mission field that indexes a dispatch
table (to-cloud, in-cloud, defensive, intercepting, bombing, returning); rounds
fire on a periodic counter and pair opposing planes, resolved by air strength on
the `cloud-round` named stream; a weaker side goes defensive over friendly
ground, a stronger side intercepts, and an interceptor over enemy ground is shot
by every anti-air gun with a sightline; anti-air does not reach the cloud (E2
working ruling); a scout report sends planes that are unbothered (in the cloud,
not in a round, not defensive) and equipped; a bombing run damages and claims
the cell; air strength is a per-team upgrade table copied at birth. Phase 5:
everyone has the same experimentals at a thousand of the leaning resource;
artillery has a flat falloff and fires at what the team can see (working
ruling); the gunship flies a pattern and ignores the cloud; carriers are
factories with patterns that build for free while moving, hold their contents,
unleash when still unless keep-hold, and retaliate when hit; the underwater
carrier is submerged while moving; the air-factory experimental unleashes
bombers; 506 (submarines and torpedo planes) is designed but explicitly not in
the demo and its current-behavior section should say it is blocked by the demo's
completion, not by a design question.

House rules: LuaJIT source in src/, numbered by ./new-source-file, every file
with a .info.md companion, functions in vimfolds, dispatch tables over branches,
flat arrays with integer zero for nothing, errors over fallbacks, comments say
why. No balance numbers in prose — the vision's own numbers may be quoted once
as the vision's. Refer to issues by number; link only to documents that exist in
docs/. Do not edit any other file, do not touch the phase progress files, do not
run git.

Keep each issue between roughly 45 and 100 lines. Write in the voice of the
existing documents. When done, reply with one line per issue saying what its
intended-behavior section commits to.

--------------------------------------------------------------------------------

### Assistant Response 1

Filled the bodies of issues 401–407 and 501–506 (thirteen files under
`issues/`), each keeping its heading and metadata table verbatim, with all three
required sections present and each file 68–97 lines. No other files touched,
no git.

What each intended-behavior section commits to:

- **401** — The cloud is one world record (position at the field's centre, an
  altitude above every gun's sight, a `cloud-round` periodic counter); planes
  are unit rows whose `mission` indexes a six-row `MISSIONS` dispatch table;
  membership is derived by array walk, never maintained.
- **402** — The emit pass picks a newborn's first mission by domain through a
  table; air starts `to-cloud` with no pattern, an air-factory placement
  carrying a pattern is refused by name, and the plane flips to `in-cloud`
  within one cell of the cloud.
- **403** — `round_pass` runs posture, pairing, resolution in that order on
  the counter's tick: sides compared by summed strength (weaker goes defensive,
  stronger intercepts), pairing by array order with newly-arrived planes sitting
  out, one draw per pair from the `cloud-round` stream, damage buffered as a
  shot rather than written; strength copied at birth.
- **404** — A defensive plane stations over the nearest friendly-owned cell
  (stored as a negative cell index in `target`); an interceptor pursues a named
  enemy plane and resolves a round of two wherever it catches it; defensive
  planes re-posture against airborne sums each round and return to the cloud
  when no longer weaker.
- **405** — Every catalogue row gets a `reaches` bitmask over land/sea/air,
  the aim pass filters candidates by reach before asking the sightline, and
  `in-cloud` planes are excluded from every shooter's candidates by rule (E2's
  working ruling); everything else is issue 205 unchanged.
- **406** — Reports are a per-team flat queue; each tick the cloud sends all
  unbothered (in-cloud, unpaired, not defensive) planes with the bombing `gear`
  bit to the oldest report; a run buffers shots against enemies within one cell
  and flips the cell unless contested, then returns.
- **407** — Upgrades are an `assets/` table of integer rows (cost, strength,
  gear bits) plus per-team bought flags; buying is a `buy-upgrade` command
  constructed as a resource stream; a plane copies its team's total strength and
  gear at birth and never reads the table again.
- **501** — Experimentals are ordinary catalogue rows with `tier` three,
  priced by a three-row tier multiplier so the thousand is derived, each with a
  line any team can lay; the validator asserts no row carries a team.
- **502** — Falloff becomes a dispatch table of curve shapes
  (`linear-to-floor`, `flat`); the artillery has the flat row and a `team_sight`
  flag, fed by an unsliced `gather_sight` step that builds per-team seen flags
  from every unit's chosen target, so the slice rule holds.
- **503** — A `flies_pattern` catalogue flag replaces 402's domain rule for
  air placement (a line all-cloud refuses a pattern, a line with a pattern-flier
  requires one, a mixed line is refused); the gunship flies a new
  `pattern-flight` mission reusing `movement`'s leg walk and is never in the
  swarm.
- **504** — A carrier is a unit row carrying a factory row via `carried_by`;
  it builds at its own build power drawing zero resources while
  `moved_this_tick`, holds output with mission `carried`, unleashes along a
  second attack pattern when standing unless `keep_hold`, unleashes toward its
  attacker when held and hit (read off the land pass's hit list), and the
  underwater variant sets `submerged` while moving.
- **505** — Bombers are carrier contents unleashed straight into 406's
  `bombing` mission with the attack pattern's last point as target; a new `home`
  field sends `returning` planes back to their carrier and into its `held` list
  instead of the cloud.
- **506** — Explicitly blocked by the demo's completion, not a design
  question: `submerged` becomes a fourth reach bit, submarines stay submerged
  while standing and reach sea+submerged, torpedo planes fly a pattern with the
  same reach, and a submerged unit's sightline profile is the water line.

One thing outside my directive, noted only: issue 405's reach bitmask and 502's
falloff dispatch table are additions to the issue 202/205 record shapes that
those phase-2 issue files (being written by another fork) may want to mention.

--------------------------------------------------------------------------------

