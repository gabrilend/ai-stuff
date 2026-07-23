-- 03-cataloger.lua — walk ONE root, write down when every file was born and
-- last touched.
--
-- General description: this is the generation half's workhorse. Point it at one
-- drive and it lists every file, asks the filesystem for each file's birth date
-- and modified date, notes its size and kind, marks whether it lives in a junk
-- directory, and writes one line per file to a shard. It does exactly one root
-- because the run script starts one of these per drive at the same time -- five
-- drives, five walkers, in parallel, never one thread trudging through all five.
--
-- This file is a SCRIPT, not a module: nothing requires it. That keeps the
-- generation half sealed off from the viewing half. Invoke it as:
--     TAPESTRY_DIR=/path luajit src/03-cataloger.lua <root>

DIR = os.getenv("TAPESTRY_DIR")
    or "/home/ritz/programming/ai-stuff/filesystem-tapestry"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/libs/?.lua;" .. package.path

local cfg      = require("00-config")
local utils    = require("01-utils")
local exclusion = require("02-exclusion")
local dispatch = require("08-media-dispatch")

-- {{{ shell_quote
-- Wrap a path so the shell treats it as one literal argument, even with spaces
-- or quotes. WHY: roots come from config, but defence in depth is free.
local function shell_quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ root_tag
-- Turn a root path into a filename-safe tag for its shard, so /mnt/cmdo becomes
-- catalog-mnt_cmdo.jsonl.
local function root_tag(root)
    return (root:gsub("^/", ""):gsub("/", "_"):gsub("[^%w_]", "-"))
end
-- }}}

-- {{{ parse_record
-- One stat record is "birth\tmtime\tsize\tpath" (NUL-terminated upstream, so we
-- receive it without the NUL). The path is everything after the third tab and
-- may itself contain tabs, so we split on exactly the first three.
local function parse_record(rec)
    local birth, mtime, size, path =
        rec:match("^(%-?%d+)\t(%-?%d+)\t(%-?%d+)\t(.*)$")
    if not birth then return nil end
    return tonumber(birth), tonumber(mtime), tonumber(size), path
end
-- }}}

-- {{{ scan
-- The whole job. Enumerate with find (fast, handles odd names via -print0),
-- read both timestamps with stat (find CANNOT emit birth time -- that is the
-- reason stat is in the pipeline at all), classify, label, and write the shard.
local function scan(root)
    local matcher  = exclusion.build(cfg.exclusion_source, cfg.always_exclude)
    local out_path = cfg.paths.tmp .. "/catalog-" .. root_tag(root) .. ".jsonl"
    local out, oerr = io.open(out_path, "w")
    if not out then error("cannot open shard for writing: " .. tostring(oerr)) end

    -- -xdev keeps the walk on this one filesystem so we never cross a mount
    -- point and start re-walking another root's drive. stderr is left alone so
    -- permission-denied notices from find/stat are visible, not swallowed.
    local cmd = "find " .. shell_quote(root)
        .. " -xdev -type f -print0 | xargs -0 stat --printf "
        .. "'%W\\t%Y\\t%s\\t%n\\0'"
    local pipe, perr = io.popen(cmd, "r")
    if not pipe then error("cannot start scan pipeline: " .. tostring(perr)) end

    -- We read the whole stream then split on NUL. For a first version this is
    -- simple and correct; a future issue can stream it if a root's listing ever
    -- grows too large to hold at once.
    local blob = pipe:read("*a") or ""
    pipe:close()

    local total, excluded_n, fallback_n = 0, 0, 0
    for rec in (blob .. "\0"):gmatch("(.-)%z") do
        if rec ~= "" then
            local birth, mtime, size, path = parse_record(rec)
            if path then
                -- Birth time unknown (0) => fall back to modified time, and SAY
                -- so via the record flag and the run tally. Never a silent swap.
                local created_is_fallback = false
                local created = birth
                if not created or created <= 0 then
                    created = mtime
                    created_is_fallback = true
                    fallback_n = fallback_n + 1
                end

                local is_excluded = matcher:is_excluded(path)
                if is_excluded then excluded_n = excluded_n + 1 end

                out:write(utils.json_encode({
                    path = path,
                    created = created,
                    modified = mtime,
                    size = size,
                    kind = dispatch.kind_of(path),
                    excluded = is_excluded,
                    created_is_fallback = created_is_fallback,
                }), "\n")
                total = total + 1
            end
        end
    end
    out:close()

    utils.log_info(string.format(
        "%s: %d files (%d excluded, %d birth-time fallbacks) -> %s",
        root, total, excluded_n, fallback_n, out_path))
    return total
end
-- }}}

local root = arg and arg[1]
if not root then
    io.stderr:write("usage: TAPESTRY_DIR=<dir> luajit src/03-cataloger.lua <root>\n")
    os.exit(1)
end
scan(root)
