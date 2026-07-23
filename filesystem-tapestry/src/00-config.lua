-- 00-config.lua — every knob the tapestry turns, in one place.
--
-- General description (fit for a CEO): this is the settings sheet. It says which
-- drives to catalogue, where the shared "ignore this junk" list lives, which
-- date to sort by, and where the catalogue file is kept. Nothing here *does*
-- anything; it only declares. Every path is built from ${DIR} so the whole
-- project can be moved or copied and still find itself.

-- DIR is injected by run.sh / the entry script. We fall back to the install
-- path so a module required in isolation (e.g. a unit test) still resolves.
-- WHY a fallback with a warning is acceptable here: a wrong DIR only mislocates
-- config, it never destroys data — but we still make it visible.
local DIR = DIR or "/home/ritz/programming/ai-stuff/filesystem-tapestry"

local M = {}

M.dir = DIR

-- {{{ M.roots
-- The "hard drive filesystem" the user chose to walk: the data drives, not the
-- OS. Each is an independent mount, so the scanner fans out one process per root
-- (see run.sh) — the walk is parallel, never one thread grinding all five.
M.roots = {
    "/mnt/cmdo",
    "/mnt/mtwo",
    "/mnt/dile",
    "/mnt/kaun",
    "/home/ritz",
}
-- }}}

-- {{{ M.exclusion_source
-- The single source of truth for "unimportant directories": the unified
-- .gitignore that the delta-version project maintains across these drives. We
-- read it at runtime rather than keeping our own copy. If it is missing, the
-- exclusion matcher warns and excludes nothing (a flagged fallback).
M.exclusion_source = "/mnt/mtwo/programming/ai-stuff/.gitignore"

-- Names git omits from .gitignore by convention (git self-ignores .git), plus
-- anything else we always want out of the browse walk. Appended to the shared
-- list, never a replacement for it.
M.always_exclude = { ".git" }
-- }}}

-- {{{ M.paths
-- Where generated data lives. tmp/ is a symlink into RAM (see run.sh); shards
-- are written there. The merged catalog is the ONE file the viewing half reads.
M.paths = {
    tmp     = DIR .. "/tmp",
    assets  = DIR .. "/assets",
    catalog = DIR .. "/assets/catalog.jsonl",
    input   = DIR .. "/input",
    output  = DIR .. "/output",
}
-- }}}

-- {{{ M.chronology
-- Defaults for the chronological walk. field: which date sorts the thread
-- ("created" = birth time, "modified" = mtime). direction: "asc" walks oldest
-- -> newest (the story from the beginning), "desc" newest -> oldest.
M.chronology = {
    field     = "modified",
    direction = "asc",
}
-- }}}

-- {{{ M.walk
-- Behaviour of next/previous. skip_excluded: the browse walk steps over files in
-- unimportant directories (they remain in the catalog, only the walk skips them
-- — "excluded but referenced chronologically").
M.walk = {
    skip_excluded = true,
}
-- }}}

-- {{{ M.viewer_overrides
-- Optional per-kind viewer overrides. Empty = use the defaults baked into
-- libs/08-media-dispatch.lua. A user who wants images in a different program
-- adds e.g. image = { program = "sxiv", args = {} } here — one row, no code.
M.viewer_overrides = {}
-- }}}

return M
