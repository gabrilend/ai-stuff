--[[
104-mend-links.lua -- repoints the links that moving a file broke.

WHAT THIS IS: every time an issue is finished it moves from issues/ into
issues/completed/, and every relative link inside it silently becomes wrong --
"../docs/004" now means "issues/docs/004", which is nothing. The file still
reads fine in an editor. Nothing complains. The link is simply dead, and it dies
at the moment of success, which is the least likely moment for anybody to check.

The first run of the documentation tool found a hundred and sixty-five of them.

WHY A TOOL AND NOT A CAREFUL AFTERNOON: because the breakage is structural and
recurs on every completion, forever. An afternoon fixes the ones that exist. This
fixes the ones that exist and the ones that will.

HOW IT MENDS: by BASENAME, not by guessing at paths. A link's target names a file;
if exactly one file in the project has that name, the link means that one and the
path is rewritten to reach it from wherever the link now lives. If two files
share a name, it says so and changes nothing -- an ambiguous mend is a wrong mend
half the time, and a wrong link that looks fixed is worse than a dead one that
looks dead.

It rewrites the MARKDOWN. Never the generated HTML: fixing generated output is
fixing a symptom in a file that is about to be overwritten.

Usage:
    ./mend-links                 -- report what is broken and mend it
    ./mend-links --dry           -- report only
    ./mend-links /path/to/prj    -- from a checkout somewhere else
]]

local DIR = "/mnt/mtwo/programming/ai-stuff/my-own-custom-vtt"
local DRY = false

for _, given in ipairs(arg or {}) do
    if given == "--dry" then
        DRY = true
    elseif given ~= "" then
        DIR = given
    end
end

-- {{{ local function shell_lines
local function shell_lines(command)
    local out = {}
    local pipe = io.popen(command)

    if pipe == nil then
        return out
    end

    for line in pipe:lines() do
        out[#out + 1] = line
    end

    pipe:close()
    return out
end
-- }}}

-- {{{ local function read_file
local function read_file(path)
    local handle = io.open(path, "r")

    if handle == nil then
        return nil
    end

    local text = handle:read("*a")
    handle:close()
    return text
end
-- }}}

--[[
Every file in the project worth linking to, indexed two ways: by its path, so a
link that already works can be left alone, and by its basename, so a link that
does not work can be recognised.

The RAM tiers and the generated site are excluded. Linking into either would be
linking at something that is regenerated, which is a link that works until the
next build.
]]
local by_path = {}
local by_base = {}
local ambiguous = {}

-- {{{ local function index_the_project
local function index_the_project()
    local found = shell_lines(string.format(
        "cd '%s' && find . -type f " ..
        "-not -path './.git/*' -not -path './tmp/*' " ..
        "-not -path './docs/HTML/*' -not -path './llm-transcripts/*' " ..
        "| sed 's|^\\./||' | sort", DIR))

    for _, relative in ipairs(found) do
        by_path[relative] = true

        local base = relative:match("([^/]+)$")

        if by_base[base] == nil then
            by_base[base] = relative
        elseif by_base[base] ~= relative then
            ambiguous[base] = true
        end
    end
end
-- }}}

-- {{{ local function resolve
local function resolve(from_relative, target)
    local base = from_relative:match("^(.*)/[^/]*$") or ""
    local parts = {}

    for piece in base:gmatch("[^/]+") do
        parts[#parts + 1] = piece
    end

    for piece in target:gmatch("[^/]+") do
        if piece == ".." then
            parts[#parts] = nil
        elseif piece ~= "." then
            parts[#parts + 1] = piece
        end
    end

    return table.concat(parts, "/")
end
-- }}}

-- {{{ local function path_from
local function path_from(from_relative, to_relative)
    -- How to reach one file from another, as a relative path with the right
    -- number of steps back up.
    local from_parts = {}
    local to_parts = {}

    for piece in (from_relative:match("^(.*)/[^/]*$") or ""):gmatch("[^/]+") do
        from_parts[#from_parts + 1] = piece
    end

    for piece in to_relative:gmatch("[^/]+") do
        to_parts[#to_parts + 1] = piece
    end

    -- Drop the shared beginning.
    local shared = 0

    while shared < #from_parts and shared < #to_parts - 1
          and from_parts[shared + 1] == to_parts[shared + 1] do
        shared = shared + 1
    end

    local out = {}

    for _ = shared + 1, #from_parts do
        out[#out + 1] = ".."
    end

    for i = shared + 1, #to_parts do
        out[#out + 1] = to_parts[i]
    end

    return table.concat(out, "/")
end
-- }}}

index_the_project()

local documents = shell_lines(string.format(
    "cd '%s' && find docs notes issues src input output desire faith strategems " ..
    "-type f 2>/dev/null | sort", DIR))

local mended = 0
local unmendable = {}
local files_touched = 0

for _, relative in ipairs(documents) do
    if relative:match("%.md$") or not relative:match("%.") then
        local text = read_file(DIR .. "/" .. relative)

        if text ~= nil then
            local changed = false

            local fixed = text:gsub("(%]%()([^%)]+)(%))", function(open, target, close)
                -- Anchors, absolute links and web links are not ours to mend.
                if target:match("^https?://") or target:match("^#")
                   or target:match("^/") then
                    return open .. target .. close
                end

                local path = target
                local anchor = ""
                local hash = target:find("#", 1, true)

                if hash ~= nil then
                    path = target:sub(1, hash - 1)
                    anchor = target:sub(hash)
                end

                if path == "" then
                    return open .. target .. close
                end

                local resolved = resolve(relative, path)

                if by_path[resolved] then
                    return open .. target .. close     -- already right
                end

                local base = path:match("([^/]+)$")

                if base == nil or by_base[base] == nil then
                    unmendable[#unmendable + 1] =
                        { from = relative, target = target, why = "nothing has that name" }
                    return open .. target .. close
                end

                if ambiguous[base] then
                    unmendable[#unmendable + 1] =
                        { from = relative, target = target,
                          why = "more than one file is called that" }
                    return open .. target .. close
                end

                changed = true
                mended = mended + 1

                return open .. path_from(relative, by_base[base]) .. anchor .. close
            end)

            if changed then
                files_touched = files_touched + 1

                if not DRY then
                    local handle = io.open(DIR .. "/" .. relative, "w")

                    if handle ~= nil then
                        handle:write(fixed)
                        handle:close()
                    end
                end
            end
        end
    end
end

print(string.format("  %d links mended across %d files%s",
                    mended, files_touched, DRY and " (dry run, nothing written)" or ""))

if #unmendable > 0 then
    print("")
    print(string.format("  %d could not be mended:", #unmendable))

    local shown = 0

    for _, one in ipairs(unmendable) do
        if shown < 30 then
            print(string.format("    %-52s %-34s %s", one.from, one.target, one.why))
            shown = shown + 1
        end
    end

    if #unmendable > shown then
        print(string.format("    ... and %d more", #unmendable - shown))
    end

    print("")
    print("  These need a person. A link naming a file that does not exist is")
    print("  either a typo or a document somebody meant to write.")
else
    print("  nothing was left broken")
end
