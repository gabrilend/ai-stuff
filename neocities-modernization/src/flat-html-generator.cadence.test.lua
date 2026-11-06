#!/usr/bin/env luajit

-- Guards issue 11-008: the writing-cadence histograms on the explore page.
--
-- What it pins. Every month and quarter between the first and last poem is
-- present, empty ones included (a gap in the writing is part of the figure);
-- image-only posts and boosts are left out and counted separately; both
-- histograms add up to the poems counted; and the explore page actually shows
-- them, through its editable template.
--
-- The page case copies page-templates/ into input/pages/ the way run.sh does
-- (scripts/sync-page-templates; input/ is ignored by git) and writes the page to
-- a scratch folder.
--
-- Run directly:  luajit src/flat-html-generator.cadence.test.lua [--dir PATH]

-- The project folder from --dir PATH, or nil when it was not given (the
-- folder above src/ is then used); a stray word on the command line stops the
-- program, named (libs/project-dir.lua, Issue 10-076).
local DIR = (function()
    local own = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"
    local dir = dofile(own .. "../libs/project-dir.lua").read(arg, "")
    if dir == "" then return nil end
    return dir:sub(-1) == "/" and dir or (dir .. "/")
end)()

-- {{{ local function setup_path()
local function setup_path()
    local this = debug.getinfo(1, "S").source:sub(2)
    local src_dir = this:match("(.*/)") or "./"
    local project_dir = DIR or src_dir:gsub("src/$", "")
    if project_dir == "" then project_dir = "./" end
    package.path = src_dir .. "?.lua;" .. project_dir .. "libs/?.lua;" .. package.path
    return project_dir
end
-- }}}

local PROJECT = setup_path()
local generator = require("flat-html-generator")

local SCRATCH = "/tmp/neocities-modernization/tmp/cadence-test"

local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, condition, detail)
    if condition then
        passed = passed + 1
        print("  ok   " .. name)
    else
        failed = failed + 1
        print("  FAIL " .. name .. (detail and ("  -- " .. detail) or ""))
    end
end
-- }}}

-- {{{ local function read_file()
local function read_file(path)
    local handle = io.open(path, "r")
    if not handle then return nil end
    local contents = handle:read("*a")
    handle:close()
    return contents
end
-- }}}

-- {{{ local function poem()
local next_index = 0
local function poem(date, fields)
    next_index = next_index + 1
    local p = {
        poem_index = next_index, id = next_index, category = "notes",
        content = "words of poem " .. next_index, creation_date = date,
    }
    for k, v in pairs(fields or {}) do p[k] = v end
    return p
end
-- }}}

-- November 2023 to March 2024, nothing at all in January: three poems in
-- November, one in December, none in January, two in February, one in March.
-- Plus an image-only post and a boost, which must not be counted, and a poem
-- with no id, which the chronological order leaves out too.
local poems_data = { poems = {
    poem("2023-11-02T10:00:00Z"),
    poem("2023-11-15T10:00:00Z"),
    poem("2023-11-30T23:00:00Z"),
    poem("2023-12-24T10:00:00Z"),
    poem("2024-02-01T10:00:00Z"),
    poem("2024-02-29T10:00:00Z"),
    poem("2024-03-10T10:00:00Z"),
    poem("2024-01-10T10:00:00Z", { is_image_only = true, content = "" }),
    poem("2024-01-11T10:00:00Z", { category = "fediverse_boost" }),
} }

-- {{{ Case: the counts
do
    local c = generator.writing_cadence(poems_data)
    check("seven poems counted", c.counted == 7, tostring(c.counted))
    check("the image-only post is counted apart", c.image_only == 1, tostring(c.image_only))
    check("the boost is counted apart", c.boosts == 1, tostring(c.boosts))
    check("the range runs from the first to the last counted poem",
        c.first == "2023-11" and c.last == "2024-03", tostring(c.first) .. " .. " .. tostring(c.last))

    local labels, counts = {}, {}
    for _, b in ipairs(c.months) do labels[#labels + 1] = b.label; counts[#counts + 1] = b.count end
    check("every month in the range is present, the empty one too",
        table.concat(labels, ",") == "2023-11,2023-12,2024-01,2024-02,2024-03", table.concat(labels, ","))
    check("each month holds its poems, January none",
        table.concat(counts, ",") == "3,1,0,2,1", table.concat(counts, ","))

    labels, counts = {}, {}
    for _, b in ipairs(c.quarters) do labels[#labels + 1] = b.label; counts[#counts + 1] = b.count end
    check("quarters are labelled by year and number",
        table.concat(labels, ",") == "2023 Q4,2024 Q1", table.concat(labels, ","))
    check("each quarter sums its months", table.concat(counts, ",") == "4,3", table.concat(counts, ","))
end
-- }}}

-- {{{ Case: a gap of whole quarters still shows them
do
    local c = generator.writing_cadence({ poems = {
        { poem_index = 1, id = 1, category = "notes", content = "a", creation_date = "2020-01-05T00:00:00Z" },
        { poem_index = 2, id = 2, category = "notes", content = "b", creation_date = "2021-02-05T00:00:00Z" },
    } })
    check("a year-long gap keeps all fourteen months", #c.months == 14, tostring(#c.months))
    check("and all five quarters, empty ones included", #c.quarters == 5, tostring(#c.quarters))
    check("the empty quarters hold zero",
        c.quarters[2].count == 0 and c.quarters[3].count == 0 and c.quarters[4].count == 0)
end
-- }}}

-- {{{ Case: nothing to count
do
    local c = generator.writing_cadence(nil)
    check("no poem list counts nothing", c.counted == 0 and #c.months == 0)
    c = generator.writing_cadence({ poems = {
        { poem_index = 1, id = 1, category = "notes", is_image_only = true, content = "",
          creation_date = "2024-01-01T00:00:00Z" },
    } })
    check("only image posts counts nothing", c.counted == 0 and #c.quarters == 0)
end
-- }}}

-- {{{ Case: the explore page shows both histograms
do
    os.execute('rm -rf "' .. SCRATCH .. '"')
    os.execute('mkdir -p "' .. SCRATCH .. '"')
    local synced = os.execute('"' .. PROJECT .. 'scripts/sync-page-templates" --dir "' .. PROJECT .. '" >/dev/null')
    check("the page templates are synced into input/pages", synced == 0 or synced == true)

    local ok, err = pcall(generator.generate_explore_page, SCRATCH, poems_data)
    check("the explore page builds", ok, tostring(err))
    local page = read_file(SCRATCH .. "/explore.html") or ""
    check("the figure has its heading", page:find("WHEN THEY WERE WRITTEN", 1, true) ~= nil)
    check("the heading names the count",
        page:find("WHEN THEY WERE WRITTEN (7 poems", 1, true) ~= nil)
    check("the quarter heading names the range",
        page:find("the trend (2023-11 to 2024-03):", 1, true) ~= nil)
    check("the month heading names how many months",
        page:find("per month, the last 5 months,", 1, true) ~= nil)
    check("a corpus shorter than the window shows all its months, and says from when",
        page:find("(2023-11 to 2024-03):", 1, true) ~= nil and page:find("2023-11 | ", 1, true) ~= nil)
    check("what was left out is said",
        page:find("Not counted: 1 image-only", 1, true) ~= nil and page:find("1 boosts", 1, true) ~= nil)
    check("the empty month is drawn, all dots and a zero",
        page:find("2024-01 | " .. string.rep("·", 40) .. "  0", 1, true) ~= nil)
    check("the busiest month fills the bar",
        page:find("2023-11 | " .. string.rep("█", 40) .. "  3", 1, true) ~= nil)
    check("a quiet month still shows",
        page:find("2023-12 | " .. string.rep("█", 13) .. string.rep("·", 27) .. "  1", 1, true) ~= nil)
    check("the quarters are drawn",
        page:find("2023 Q4 | " .. string.rep("█", 40) .. "  4", 1, true) ~= nil
        and page:find("2024 Q1 | ", 1, true) ~= nil)
    check("no marker is left unfilled", not page:find("{CADENCE", 1, true))
    check("the rest of the page is still there", page:find("sources:", 1, true) ~= nil
        and page:find("chronological/01.html", 1, true) ~= nil)

    -- Without a poem list the figure drops out rather than failing the page.
    ok, err = pcall(generator.generate_explore_page, SCRATCH, nil)
    check("the explore page builds without a poem list", ok, tostring(err))
    page = read_file(SCRATCH .. "/explore.html") or ""
    check("and then draws no bars or headings", not page:find(" Q%d | ")
        and not page:find("WHEN THEY WERE WRITTEN", 1, true)
        and not page:find("per quarter", 1, true) and not page:find("per month", 1, true)
        and not page:find("{CADENCE", 1, true))
end
-- }}}

-- {{{ Case: the month chart shows only the recent window; quarters keep it all
-- Issue 11-008 follow-up: the whole history by month runs to well over a
-- hundred lines, so the month chart shows the last cadence_recent_months
-- months (config.explore_page), counted back from the newest poem, and the
-- quarter chart still covers everything.
do
    -- Four poems: Jan 2020, Jun 2020, Mar 2024, May 2024 -- 53 months in all.
    local long = { poems = {
        poem("2020-01-15T10:00:00Z"), poem("2020-06-15T10:00:00Z"),
        poem("2024-03-15T10:00:00Z"), poem("2024-05-15T10:00:00Z"),
    } }
    local c = generator.writing_cadence(long)
    check("the counts still run over the whole history", #c.months == 53, tostring(#c.months))

    local recent = generator.recent_months(c.months, { cadence_recent_months = 36 })
    check("the window keeps 36 months", #recent == 36, tostring(#recent))
    check("ending at the newest poem's month", recent[36].label == "2024-05", tostring(recent[36].label))
    check("and starting 35 months before it", recent[1].label == "2021-06", tostring(recent[1].label))
    check("a window wider than the corpus keeps every month",
        #generator.recent_months(c.months, { cadence_recent_months = 100 }) == 53)
    check("a one-month window is the newest month",
        generator.recent_months(c.months, { cadence_recent_months = 1 })[1].label == "2024-05")

    local function refused(cfg) return not pcall(generator.recent_months, c.months, cfg) end
    check("a missing section is refused", refused(nil))
    check("a missing count is refused", refused({}))
    check("zero is refused", refused({ cadence_recent_months = 0 }))
    check("a fraction is refused", refused({ cadence_recent_months = 2.5 }))
    check("a string is refused", refused({ cadence_recent_months = "36" }))

    local shipped = dofile(PROJECT .. "config.lua").explore_page
    check("the shipped config shows 36 months", shipped and shipped.cadence_recent_months == 36)

    os.execute('mkdir -p "' .. SCRATCH .. '"')
    local ok, err = pcall(generator.generate_explore_page, SCRATCH, long, { cadence_recent_months = 12 })
    check("the explore page builds with a 12-month window", ok, tostring(err))
    local page = read_file(SCRATCH .. "/explore.html") or ""
    local month_rows, quarter_rows = 0, 0
    for _ in page:gmatch("\n    %d%d%d%d%-%d%d | ") do month_rows = month_rows + 1 end
    for _ in page:gmatch("\n    %d%d%d%d Q%d | ") do quarter_rows = quarter_rows + 1 end
    check("the month chart draws 12 rows", month_rows == 12, tostring(month_rows))
    check("the quarter chart still draws every quarter", quarter_rows == 18, tostring(quarter_rows))
    check("the heading says the window and its span",
        page:find("per month, the last 12 months,", 1, true) ~= nil
        and page:find("(2023-06 to 2024-05):", 1, true) ~= nil)
    check("an old month is not in the month chart", not page:find("2020-01 | ", 1, true))
    check("the quarter heading keeps the whole range", page:find("the trend (2020-01 to 2024-05):", 1, true) ~= nil)
    -- The window's own busiest month fills the bar.
    check("the month bars are scaled to the window",
        page:find("2024-05 | " .. string.rep("█", 40) .. "  1", 1, true) ~= nil)

    check("the explore page refuses a bad window",
        not pcall(generator.generate_explore_page, SCRATCH, long, { cadence_recent_months = 0 }))
end
-- }}}

os.execute('rm -rf "' .. SCRATCH .. '"')
print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
