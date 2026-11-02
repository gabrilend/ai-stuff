-- 103-the-story.lua
--
-- A case's ledger told back as chapters in plain words (docs/069, issue
-- 1001). Three pieces, each a step on the one before:
--
--   turning points (1001b)  the ledger cut into chapters at its own turning
--                           points -- opened, surveyed, described, built,
--                           each request, each failure and repair -- in
--                           ledger order
--   no line twice (1001c)   each chapter's heading names the ledger lines it
--                           tells; a second telling starts after the last
--                           line already told, so the story grows like the
--                           ledger and an unchanged ledger adds nothing
--   whose it was (1001d)    each chapter names whose each thing was -- the
--                           person, the referee, the builder, and which
--                           harness (the stand-in, a named model) played them
--                           -- read from what the ledger already records
--
-- The chapters here are the machine's own plain telling, made from the
-- ledger alone and rebuilt at any time. A `storyteller` turn (034, 1001a)
-- may later retell them in richer words; these are its facts.

local ledger = require("016-ledger")
local fs = require("017-the-filesystem")

local story = {}

-- Which turning point each ledger kind belongs to. A kind missing here
-- (turn-started, turn-ended, goodbye) is working, not a turning point: it
-- joins the next chapter, since a turn's own lines come before the result
-- they lead to. One exception, below: a repair turn starting is itself a
-- turning point.
story.TURNING = {
    ["case-opened"] = "opened",
    ["surveyed"] = "surveyed",
    ["outlined"] = "described",
    ["described"] = "described",
    ["refereed"] = "refereed",
    ["built"] = "built",
    ["delivered"] = "delivered",
    ["audited"] = "wider look",
    ["inspected"] = "wider look",
    ["request-received"] = "request",
    ["graded"] = "request",
    ["held"] = "request",
    ["request-done"] = "request",
    ["outline-failed"] = "failure",
    ["describe-failed"] = "failure",
    ["build-failed"] = "failure",
    ["referee-failed"] = "failure",
    ["workflow-failed"] = "failure",
    ["request-failed"] = "failure",
    ["breach"] = "failure",
}

-- Turning points told one thing at a time: two requests in a row are two
-- chapters, two failures in a row are two failures. The rest are stretches
-- of one kind of work, and lines of them in a row make one chapter however
-- many issues they touch ("It described six pieces").
local ONE_THING_AT_A_TIME = { request = true, failure = true, repair = true }

-- {{{ local function turn_words
-- A turn-started line's text is "<turn kind> <about> by <harness>" (039).
-- Returns the turn kind, its about and the harness, or nil for text that
-- does not read that way.
local function turn_words(text)
    local turn_kind, about, harness = text:match("^(%S+) (.-) by (%S+)$")
    return turn_kind, about, harness
end
-- }}}

-- {{{ function story.turning_point
-- The turning point a ledger line belongs to, and the thing it is about
-- (for the turning points told one thing at a time); nil for a working line.
function story.turning_point(line)
    if line.kind == "turn-started" then
        local turn_kind, about = turn_words(line.text)
        if turn_kind == "repair" then
            return "repair", about
        end
        return nil
    end
    local turning = story.TURNING[line.kind]
    if not turning then
        return nil
    end
    if ONE_THING_AT_A_TIME[turning] then
        return turning, line.about
    end
    return turning, ""
end
-- }}}

-- {{{ function story.chapters
-- lines: 016's `read()` output, or any slice of it in ledger order. Returns
-- { chapters = array, waiting = array of lines }. A chapter: turning (the
-- turning point's name), thing (what it is about, "" for a stretch of
-- work), lines (the ledger lines it tells, in order), first and last (their
-- seq numbers). `waiting` holds working lines at the end with no turning
-- point after them yet: they belong to a chapter not yet begun, and are
-- told when it is.
function story.chapters(lines)
    local chapters = {}
    local pending = {}
    local current = nil
    for _, line in ipairs(lines) do
        local turning, thing = story.turning_point(line)
        if not turning then
            pending[#pending + 1] = line
        else
            if not (current and current.turning == turning and current.thing == thing) then
                current = { turning = turning, thing = thing, lines = {} }
                chapters[#chapters + 1] = current
            end
            for _, waiting_line in ipairs(pending) do
                current.lines[#current.lines + 1] = waiting_line
            end
            pending = {}
            current.lines[#current.lines + 1] = line
        end
    end
    for _, chapter in ipairs(chapters) do
        chapter.first = chapter.lines[1].seq
        chapter.last = chapter.lines[#chapter.lines].seq
    end
    return { chapters = chapters, waiting = pending }
end
-- }}}

-- Whose each thing was (1001d). A ledger kind's role: the person, the
-- machine itself, or a role a turn plays -- `turn_kinds` are the turn kinds
-- that play it, so the harness of the latest such turn names who played it.
story.ROLES = {
    ["case-opened"] = { role = "the person" },
    ["request-received"] = { role = "the person" },
    ["held"] = { role = "the person" },
    ["surveyed"] = { role = "the machine" },
    ["graded"] = { role = "the machine" },
    ["delivered"] = { role = "the machine" },
    ["request-done"] = { role = "the machine" },
    ["request-failed"] = { role = "the machine" },
    ["breach"] = { role = "the machine's confinement check" },
    ["goodbye"] = { role = "the machine" },
    ["outlined"] = { role = "the outliner", turn_kinds = { outline = true } },
    ["outline-failed"] = { role = "the outliner", turn_kinds = { outline = true } },
    ["described"] = { role = "the describer", turn_kinds = { describe = true, amend = true } },
    ["describe-failed"] = { role = "the describer", turn_kinds = { describe = true, amend = true } },
    ["refereed"] = { role = "the referee", turn_kinds = { referee = true } },
    ["referee-failed"] = { role = "the referee", turn_kinds = { referee = true } },
    ["workflow-failed"] = { role = "the referee's check", turn_kinds = { referee = true } },
    ["built"] = { role = "the builder", turn_kinds = { build = true, repair = true } },
    ["build-failed"] = { role = "the builder", turn_kinds = { build = true, repair = true } },
    ["audited"] = { role = "the auditor", turn_kinds = { audit = true } },
    ["inspected"] = { role = "the inspector", turn_kinds = { inspect = true } },
}

-- The role each turn kind plays, for turn lines themselves.
story.TURN_ROLES = {
    outline = "the outliner", describe = "the describer", amend = "the describer",
    referee = "the referee", build = "the builder", repair = "the builder",
    audit = "the auditor", inspect = "the inspector", locate = "the locator",
    storyteller = "the storyteller",
}

-- {{{ local function harness_words
-- A harness's name as a reader would say it.
local function harness_words(harness)
    if harness == "stand-in" then
        return "the stand-in"
    end
    return harness
end
-- }}}

-- {{{ function story.whose
-- Who did each line: lines in ledger order (a whole ledger, so the turns
-- before a slice are known). Returns {[seq] = words}, e.g. "the person",
-- "the builder (the stand-in)". A role played by a turn names the harness of
-- the latest turn of a kind that plays it; with no such turn earlier in the
-- ledger the role is named alone.
function story.whose(lines)
    local whose = {}
    -- turn kind -> { seq, harness } of the latest turn of that kind started.
    local latest = {}
    for _, line in ipairs(lines) do
        local role, harness
        if line.kind == "turn-started" then
            local turn_kind, _, h = turn_words(line.text)
            if turn_kind then
                latest[turn_kind] = { seq = line.seq, harness = h }
            end
            role, harness = turn_kind and story.TURN_ROLES[turn_kind] or "a turn", h
        elseif line.kind == "turn-ended" then
            -- A turn id is NNNN-kind-about (034).
            local turn_kind = line.about:match("^%d+%-(%a+)")
            role = turn_kind and story.TURN_ROLES[turn_kind] or "a turn"
            harness = turn_kind and latest[turn_kind] and latest[turn_kind].harness
        else
            local row = story.ROLES[line.kind] or { role = "the machine" }
            role = row.role
            local best = nil
            for turn_kind in pairs(row.turn_kinds or {}) do
                local seen = latest[turn_kind]
                if seen and (not best or seen.seq > best.seq) then
                    best = seen
                end
            end
            harness = best and best.harness
        end
        whose[line.seq] = harness and (role .. " (" .. harness_words(harness) .. ")") or role
    end
    return whose
end
-- }}}

-- {{{ local function sentence_for
-- One plain sentence for one ledger line, naming who did it.
local function sentence_for(line, who)
    local about, text = line.about, line.text
    local said = {
        ["case-opened"] = function() return who .. " opened the case: " .. text .. "." end,
        ["request-received"] = function() return who .. " asked for something new, in " .. about .. "." end,
        ["surveyed"] = function() return who .. " read the source: " .. text .. "." end,
        ["turn-started"] = function()
            local turn_kind, turn_about = turn_words(text)
            if turn_kind then
                return who .. " began a " .. turn_kind .. " turn on " .. turn_about .. "."
            end
            return who .. " began a turn (" .. text .. ")."
        end,
        ["turn-ended"] = function() return who .. " ended turn " .. about .. ": " .. text .. "." end,
        ["breach"] = function() return who .. " caught a write where none was allowed, in " .. about .. ": " .. text .. "." end,
        ["outlined"] = function() return who .. " outlined the source into " .. text .. "." end,
        ["outline-failed"] = function() return who .. "'s outline did not pass (" .. about .. "): " .. text .. "." end,
        ["described"] = function() return who .. " described issue " .. about .. " (" .. text .. ")." end,
        ["describe-failed"] = function() return who .. " could not describe issue " .. about .. ": " .. text .. "." end,
        ["refereed"] = function() return who .. ", who never saw the design, wrote the checks: " .. text .. "." end,
        ["referee-failed"] = function() return who .. "'s checks did not pass: " .. text .. "." end,
        ["workflow-failed"] = function() return who .. " caught it: " .. about .. " still failed (" .. text .. ")." end,
        ["built"] = function() return who .. " built issue " .. about .. " (" .. text .. ")." end,
        ["build-failed"] = function() return who .. " could not build issue " .. about .. ": " .. text .. "." end,
        ["audited"] = function() return who .. " looked again at issue " .. about .. ": " .. text .. "." end,
        ["inspected"] = function() return who .. " looked at " .. about .. " together: " .. text .. "." end,
        ["delivered"] = function() return who .. " delivered the design: " .. text .. "." end,
        ["graded"] = function() return who .. " graded " .. about .. ": " .. text .. "." end,
        ["held"] = function() return who .. " still has to say go on " .. about .. ": " .. text .. "." end,
        ["request-done"] = function() return who .. " finished " .. about .. ": " .. text .. "." end,
        ["request-failed"] = function() return who .. " gave up on " .. about .. ": " .. text .. "." end,
        ["goodbye"] = function() return who .. " said goodbye (" .. text .. ")." end,
    }
    local say = said[line.kind]
    if say then
        return say()
    end
    return who .. ": " .. line.kind .. " " .. about .. ": " .. text .. "."
end
-- }}}

-- {{{ local function capital
local function capital(text)
    return (text:gsub("^%l", string.upper))
end
-- }}}

-- {{{ function story.heading
-- A chapter's first line: its number, its turning point (and thing), and
-- the ledger lines it tells -- the line 1001c reads back.
function story.heading(number, chapter)
    local name = chapter.turning
    if chapter.thing ~= "" then
        name = name .. " " .. chapter.thing
    end
    return string.format("## Chapter %d: %s (ledger lines %d-%d)", number, name, chapter.first, chapter.last)
end
-- }}}

-- {{{ function story.chapter_text
-- A chapter in plain words: its heading, who took part (each named once, in
-- order of first appearance), then one sentence per line it tells.
function story.chapter_text(number, chapter, whose)
    local out = { story.heading(number, chapter), "" }
    local named, order = {}, {}
    for _, line in ipairs(chapter.lines) do
        local who = whose[line.seq] or "the machine"
        if not named[who] then
            named[who] = true
            order[#order + 1] = who
        end
    end
    out[#out + 1] = "Whose: " .. table.concat(order, "; ") .. "."
    out[#out + 1] = ""
    for _, line in ipairs(chapter.lines) do
        out[#out + 1] = string.format("%d. %s", line.seq,
            capital(sentence_for(line, whose[line.seq] or "the machine")))
    end
    out[#out + 1] = ""
    return table.concat(out, "\n") .. "\n"
end
-- }}}

-- {{{ function story.told_so_far
-- Reads a story file's own chapter headings: the last ledger line already
-- told (0 for none) and how many chapters there are. Text, not a path, so a
-- story not yet written is simply "".
function story.told_so_far(text)
    local last, count = 0, 0
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        local last_seq = line:match("^## Chapter %d+: .-%(ledger lines %d+%-(%d+)%)$")
        if last_seq then
            count = count + 1
            last = math.max(last, tonumber(last_seq))
        end
    end
    return last, count
end
-- }}}

-- {{{ function story.path_for
-- Where a case's story lives: output/story/<case>.md inside the case.
function story.path_for(record)
    return record.folder .. "/output/story/" .. record.name .. ".md"
end
-- }}}

-- {{{ function story.tell
-- Tells the ledger lines not yet told, appending one chapter per new
-- turning point to the story file; the first telling also writes its
-- title. The ledger is verified first: a story is never told from a
-- history that does not check. Returns { chapters (the new ones), waiting
-- (working lines held for the next chapter), told_through (the last line
-- told, after this telling) }. Telling an unchanged ledger again appends
-- nothing.
function story.tell(ledger_path, story_path, case_name)
    local verified = ledger.verify(ledger_path)
    if not verified.ok then
        error("story.tell: " .. ledger.describe_failure(verified))
    end
    local all = ledger.read(ledger_path)
    local existing = fs.exists(story_path) and fs.read(story_path) or ""
    local told_through, count = story.told_so_far(existing)
    local untold = {}
    for _, line in ipairs(all) do
        if line.seq > told_through then
            untold[#untold + 1] = line
        end
    end
    local cut = story.chapters(untold)
    if #cut.chapters > 0 then
        local whose = story.whose(all)
        local parts = {}
        if existing == "" then
            parts[#parts + 1] = "# The story of " .. case_name .. "\n\n"
        end
        for i, chapter in ipairs(cut.chapters) do
            parts[#parts + 1] = story.chapter_text(count + i, chapter, whose)
        end
        local folder = story_path:match("^(.*)/[^/]*$")
        if folder then
            fs.make_folder(folder)
        end
        -- Append only, in one write: what is already told is never rewritten.
        local file = assert(io.open(story_path, "ab"))
        file:write(table.concat(parts))
        file:close()
        told_through = cut.chapters[#cut.chapters].last
    end
    return { chapters = cut.chapters, waiting = cut.waiting, told_through = told_through }
end
-- }}}

return story
