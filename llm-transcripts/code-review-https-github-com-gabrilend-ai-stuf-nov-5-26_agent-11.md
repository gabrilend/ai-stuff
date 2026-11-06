# Conversation Summary: agent-abc8c53f3e1495b69

Generated on: 2026-11-05 23:59:15
Models: claude-opus-5-5

--------------------------------------------------------------------------------

### User Request 1

Review target: `https://github.com/gabrilend/ai-stuff/pull/318 medium`

`high effort → 8 inline angles → dedup (no verify) → ≤10 findings`

You are reviewing for **recall** at high effort: catch every real bug a careful
reviewer would catch in one sitting. At this level, catching real bugs matters
more than avoiding false positives. Err on the side of surfacing.

## Phase 0 — Gather the diff

Run `git diff @{upstream}...HEAD` (or `git diff main...HEAD` / `git diff HEAD~1`
if there's no upstream) to get the unified diff under review. If there are
uncommitted changes, or the range diff is empty, also run `git diff HEAD` and
include the working-tree changes in scope — the review often runs before the
commit. If a PR number, branch name, or file path was passed as an argument,
review that target instead. Treat this diff as the review scope.

## Phase 1 — Find candidates (3 correctness angles + 3 cleanup angles + 1 altitude angle + 1 conventions angle, up to 6 each)

Run **8 independent finder angles** in sequence yourself, in THIS context — do
NOT spawn subagents for them. Each
surfaces **up to 6 candidate findings** with `file`, `line`, a one-line
`summary`, and a concrete `failure_scenario`.

## Angle A — line-by-line diff scan

Read every hunk in the diff, line by line. Then Read the enclosing function for
each hunk — bugs in unchanged lines of a touched function are in scope (the PR
re-exposes or fails to fix them). For every line ask: what input, state, timing,
or platform makes this line wrong? Look for inverted/wrong conditions,
off-by-one, null/undefined deref, missing `await`, falsy-zero checks,
wrong-variable copy-paste, error swallowed in catch, unescaped regex metachars.

## Angle B — removed-behavior auditor

For every line the diff DELETES or replaces, name the invariant or behavior it
enforced, then search the new code for where that invariant is re-established.
If you can't find it, that's a candidate: a removed guard, a dropped error
path, a narrowed validation, a deleted test that was covering a real case.

## Angle C — cross-file tracer

For each function the diff changes, find its callers (Grep for the symbol) and
check whether the change breaks any call site: a new precondition, a changed
return shape, a new exception, a timing/ordering dependency. Also check callees:
does a parallel change in the same PR make a call unsafe?

## Reuse

The angles above hunt for bugs; this one and the next two hunt for cleanup in
the changed code. Flag new code that re-implements something the codebase
already has — Grep shared/utility modules and files adjacent to the change,
and name the existing helper to call instead.

## Simplification

Flag unnecessary complexity the diff adds: redundant or derivable state,
copy-paste with slight variation, deep nesting, dead code left behind. Name
the simpler form that does the same job.

## Efficiency

Flag wasted work the diff introduces: redundant computation or repeated I/O,
independent operations run sequentially, blocking work added to startup or
hot paths. Also flag long-lived objects built from closures or captured
environments — they keep the entire enclosing scope alive for the object's
lifetime (a memory leak when that scope holds large values); prefer a
class/struct that copies only the fields it needs. Name the cheaper
alternative.

## Altitude

Check that each change fixes the root cause at the right depth rather than
patching a symptom with a fragile bandaid. Special cases layered on shared
infrastructure are a sign the fix isn't deep enough — prefer the simpler, more
general change to the underlying mechanism over adding special cases, and name
that change.

## Conventions (CLAUDE.md)

Find the CLAUDE.md files that govern the changed code: the user-level
~/.claude/CLAUDE.md, the repo-root CLAUDE.md, plus any CLAUDE.md or
CLAUDE.local.md in a directory that is an ancestor of a changed file (a
directory's CLAUDE.md only applies to files at or below it). Read each one
that exists, then check the diff for clear violations of the rules they state.

Only flag a violation when you can quote the exact rule and the exact line
that breaks it — no style preferences, no vague "spirit of the doc"
inferences. In the finding, name the CLAUDE.md path and quote the rule so the
report can cite it. If no CLAUDE.md applies, return nothing for this angle.

Cleanup, altitude, and conventions candidates use the same
`file`/`line`/`summary` shape; in `failure_scenario`, state the concrete
cost (what is duplicated, wasted, harder to maintain, or which CLAUDE.md rule
is broken) instead of a crash. Correctness bugs always outrank cleanup,
altitude, and conventions findings when the output cap forces a cut.

Pass every candidate with a nameable failure scenario through — finders that
silently drop half-believed candidates are the dominant cause of misses.

## Phase 2 — Dedup only (no verify)

Pool all candidates. Dedup near-duplicates only (same defect, same location,
same reason → keep one). Do NOT run verifiers; do NOT re-judge. Sort by
severity.

## Output

Target **at least 5 findings**. If fewer genuine findings exist, emit what you
have — do not invent to hit the floor.

Return findings as a JSON array of at most 10 objects:

```json
[
  {
    "file": "path/to/file.ext",
    "line": 123,
    "summary": "one-sentence statement of the bug",
    "failure_scenario": "concrete inputs/state → wrong output/crash"
  }
]
```

Ranked most-severe first. If more than 10 survive, keep the 10 most
severe. If nothing survives, return `[]`. Do not call the
ReportFindings tool even if it is available - this review's
output contract is the JSON block above.

--------------------------------------------------------------------------------

### Assistant Response 1

Ten findings on PR #318 (the new unit art-fields reader, `unit_visuals.lua`, and
its test), most severe first. Six are bugs, one is duplicated code, and three
break CLAUDE.md rules. I read the code but did not run the test or the
real-install path.

```json
[
  {
    "file": "world-edit-to-execute/src/gamedata/unit_visuals.lua",
    "line": 158,
    "summary": "The model path is passed on unchanged, so a model the map sets keeps its file extension while a stock model has none. Both forms end up in the field the model chooser is meant to look models up by.",
    "failure_scenario": "Stock hfoo gives model 'units\\human\\Footman\\Footman', but the map's otau gives 'war3mapImported\\BigTauren.mdx' (the PR's own test asserts this). The planned chooser looks up row.model without the cleanup assets.model_for already does (it strips .mdl/.MDL/.mdx before looking up). A lookup that adds '.mdx' gets 'BigTauren.mdx.mdx'; one that doesn't misses stock models. Either way one of the two kinds silently falls back to a placeholder shape."
  },
  {
    "file": "world-edit-to-execute/src/gamedata/unit_visuals.lua",
    "line": 159,
    "summary": "Only '_' and '' count as 'no value'. The '-' that WC3 tables also use for empty cells is kept as a real model path or move type, and quotes kept from profile files are not removed.",
    "failure_scenario": "A UnitUI 'file' cell of '-' gives row.model = '-', and the chooser tries to load a model called '-'. A profile entry file=\"units\\x\\Y\" (the profile parser keeps quotes) gives a model path with literal quote marks. The repo's existing object_stock:stock_value already treats '-', '_' and '' as nothing and strips quotes."
  },
  {
    "file": "world-edit-to-execute/src/gamedata/unit_visuals.lua",
    "line": 193,
    "summary": "The module cannot run without the install. stock_fields reads stock.tables, so a nil stock crashes, and stock_rows.load needs a chain. The planned map-load call therefore gives no rows when no install is present, not even the map's own scale and tint changes.",
    "failure_scenario": "A checkout with no Frozen Throne install (the PR notes this checkout has none) runs the planned follow-up in game.lua. stock_rows.load errors on the missing chain, or a nil stock reaches for_types, which fails with 'attempt to index nil'. The window cannot load the map at all. object_stock.new(nil, objects), which game.lua already uses, keeps working with only the map's changes."
  },
  {
    "file": "world-edit-to-execute/src/gamedata/unit_visuals.lua",
    "line": 152,
    "summary": "from_map only comes from 'map' labels in the merged rows. Units defined or changed through a map's own shipped copy of UnitUI.slk (stock_rows' map_defined rows, or stock types the copy overrides) are never marked as the map's.",
    "failure_scenario": "An optimized map ships its own UnitUI.slk that rescales hfoo and defines h00X only there. stock_rows labels those columns 'fact' or 'borrowed', never 'map'. row.from_map is empty and counts.from_map leaves both types out, so the issue's check that a map's changed scale or tint shows wrongly reports nothing changed."
  },
  {
    "file": "world-edit-to-execute/src/gamedata/unit_visuals.lua",
    "line": 151,
    "summary": "Profile-file fields are looked up with the metadata's exact spelling, but profile keys keep the capitalisation they were written with, and WC3 reads them ignoring case.",
    "failure_scenario": "Metadata names the field 'file' with slk 'Profile', but the profile file writes 'File=units\\...'. values['file'] is nil, so the model reads as none and the unit gets a placeholder. object_stock:profile_field already handles this with a lowercase match and the comment 'profile keys aren't consistently capitalised'."
  },
  {
    "file": "world-edit-to-execute/src/gamedata/unit_visuals.lua",
    "line": 138,
    "summary": "A custom type that stock_rows.merge dropped (its parent is not in the stock tables, or it is an orphan) is reported as 'in neither the map's object data nor the stock tables'. That is wrong, and merge's own problem record is never mentioned.",
    "failure_scenario": "A map's custom h005 copies a parent the current patch layer lacks. merge records 'unknown_parent' and gives no row. for_types then reports h005 as unknown_type, saying the map does not have it, which points the person debugging away from the real cause, the missing parent."
  },
  {
    "file": "world-edit-to-execute/src/gamedata/unit_visuals.lua",
    "line": 129,
    "summary": "This rebuilds 'map change, else stock value, by field code' lookup that the codebase already has: object_stock:value(id, code) returns the value and 'map' or 'stock', and assets.model_for and scale_for already read umdl and usca. The new copy differs from the existing ones in sentinels, quote stripping, key case and extension stripping.",
    "failure_scenario": "game.lua already holds an object_stock for units (opts.stock). A third way to read the same fields means the window's model and scale (from assets) and the shape and tint (from unit_visuals) can disagree for one unit, and any fix has to be made in three places. Building each row from S:value(id, code) and taking origin == 'map' for from_map would reuse the existing reader."
  },
  {
    "file": "world-edit-to-execute/src/gamedata/unit_visuals.lua",
    "line": 170,
    "summary": "This breaks the CLAUDE.md fallback rule. Values that cannot be read, or are missing, are silently replaced with defaults and no problem is reported.",
    "failure_scenario": "~/.claude/CLAUDE.md: 'prefer error messages and breaking functionality over fallbacks. Be sure to notify the user every time a fallback is used'. Here a modelScale of 'big' quietly becomes 1, and a column missing from the row quietly becomes scale 1 and tint 255. Only codes missing from the metadata are reported, and the test even asserts 'an unreadable number falls back'."
  },
  {
    "file": "world-edit-to-execute/src/gamedata/unit_visuals.lua",
    "line": 64,
    "summary": "This breaks the CLAUDE.md vimfold rule. In stock_fields, flag, placeholder, of and for_types, a comment block sits between the fold-marker line and the function definition.",
    "failure_scenario": "~/.claude/CLAUDE.md: 'They should open with a comment that has the comment symbol, then the name of the function without arguments. On the next line, the function should be defined with arguments.' Example: '-- {{{ local function stock_fields' is followed by '-- A stock type's columns, per table...' rather than 'local function stock_fields(stock, id)'. The same happens at lines 84, 107, 124 and 184."
  },
  {
    "file": "world-edit-to-execute/src/gamedata/unit_visuals.lua",
    "line": 145,
    "summary": "This breaks the CLAUDE.md rule against nil checks. Lookups are guarded against nil instead of the cause being found and an error raised.",
    "failure_scenario": "~/.claude/CLAUDE.md: 'nil checks are just asking for errors. Never assume that \"NULL\" is an option. Find out why it would be null, then fix that real error.' Examples: 'stock.metadata and stock.metadata.rows and stock.metadata.rows[code]', 'merged and merged.rows and merged.rows[id]', 'stock.tables or {}' at line 69. A broken stock object, such as one with no metadata, is turned into eight no_metadata problems instead of an error. The test file also has dead code ('local empty' and '_ = empty' in files_with, lines 112 and 120)."
  }
]
```

--------------------------------------------------------------------------------

