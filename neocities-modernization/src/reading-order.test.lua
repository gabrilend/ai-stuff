#!/usr/bin/env luajit

-- Guards issue 10-064: the `--reverse` reading order.
--
-- What it pins. One flag, two operations, and a default that does not move:
--
--   * chronological pages: under --reverse page 1 holds the NEWEST slice of
--     the timeline and each page still reads oldest to newest; the page a
--     poem's links point at (compute_chronological_mapping) is the page the
--     chronological generator actually puts it on, in both modes;
--   * similar / different lists: the poems the build shows are the same set,
--     laid out by date -- similar newest first, different oldest first -- and
--     the rest of the list is untouched;
--   * without --reverse every output is byte-for-byte what it was.
--
-- It builds real chronological and explore pages from made-up poems into a
-- scratch folder (syncing page-templates/ into input/pages/ as run.sh does).
--
-- Run directly:  luajit src/reading-order.test.lua [project-dir]

local DIR = arg and arg[1] or nil

-- {{{ local function setup_path()
local function setup_path()
    local this = debug.getinfo(1, "S").source:sub(2)
    local src_dir = this:match("(.*/)") or "./"
    local project_dir = DIR or src_dir:gsub("src/$", "")
    if project_dir == "" then project_dir = "./" end
    if project_dir:sub(-1) ~= "/" then project_dir = project_dir .. "/" end
    package.path = src_dir .. "?.lua;" .. project_dir .. "libs/?.lua;" .. package.path
    return project_dir
end
-- }}}

local PROJECT = setup_path()
local R = require("reading-order")
local generator = require("flat-html-generator")

local SCRATCH = "/tmp/neocities-modernization/tmp/reading-order-test"
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

-- {{{ local function fresh()
local function fresh(sub)
    local d = SCRATCH .. "/" .. sub
    os.execute('rm -rf "' .. d .. '"; mkdir -p "' .. d .. '"')
    return d
end
-- }}}

-- {{{ Case: the chronological page arithmetic
do
    -- The issue's worked example: 250 poems, 100 per page.
    local f, l = R.chrono_page_range(1, 100, 250, true)
    check("reversed page 1 holds the newest 100 (151..250)", f == 151 and l == 250, f .. ".." .. l)
    f, l = R.chrono_page_range(2, 100, 250, true)
    check("reversed page 2 holds the 100 before them (51..150)", f == 51 and l == 150, f .. ".." .. l)
    f, l = R.chrono_page_range(3, 100, 250, true)
    check("the short page is the last, holding the oldest (1..50)", f == 1 and l == 50, f .. ".." .. l)
    check("the final poem is on reversed page 1", R.chrono_page(250, 100, 250, true) == 1)
    check("the first poem is on the last reversed page", R.chrono_page(1, 100, 250, true) == 3)
    check("forward numbering is unchanged", R.chrono_page(1, 100, 250, false) == 1
        and R.chrono_page(250, 100, 250, false) == 3 and R.chrono_page(101, 100, 250, nil) == 2)
    check("unpaginated is page 1 in both modes",
        R.chrono_page(7, nil, 9, true) == 1 and select(2, R.chrono_page_range(1, nil, 9, true)) == 9)

    -- Every position lands on exactly one page, and chrono_page agrees with the
    -- range that holds it, in both modes, for awkward sizes too.
    local agree = true
    for _, case in ipairs({ { 1, 1 }, { 5, 2 }, { 7, 3 }, { 10, 5 }, { 11, 4 }, { 13, 13 }, { 2, 7 } }) do
        local total, size = case[1], case[2]
        for _, rev in ipairs({ false, true }) do
            local seen = {}
            local pages = math.ceil(total / size)
            for page = 1, pages do
                local first, last = R.chrono_page_range(page, size, total, rev)
                for pos = first, last do
                    if seen[pos] or R.chrono_page(pos, size, total, rev) ~= page then agree = false end
                    seen[pos] = true
                end
            end
            for pos = 1, total do if not seen[pos] then agree = false end end
        end
    end
    check("every position is on exactly one page, the one chrono_page names", agree)
end
-- }}}

-- {{{ Case: how much of a list the build shows
do
    check("all pages, capped by the storage ceiling", R.shown_count(950, 200, true, nil, 3) == 600)
    check("all pages, the list shorter than the ceiling", R.shown_count(450, 200, true, nil, 10) == 450)
    check("a page list shows through its highest page", R.shown_count(950, 200, false, { 1, 3 }, 10) == 600)
    check("never more than the list holds", R.shown_count(50, 200, false, { 2 }, 10) == 50)
end
-- }}}

-- Seven poems, a day apart (poem_index 1 oldest .. 7 newest), with two sharing
-- a timestamp so the tie-break is exercised.
local poems = {}
for i = 1, 7 do
    local day = (i == 5) and 4 or i   -- poems 4 and 5 share 2024-01-04
    poems[i] = {
        poem_index = i, id = i, category = "notes", title = "Poem " .. i,
        content = "words of poem " .. i,
        creation_date = string.format("2024-01-%02dT12:00:00Z", day),
    }
end
local poems_data = { poems = poems }

-- {{{ Case: the mapping every link is built from
do
    local fwd = generator.compute_chronological_mapping(poems_data, 3)
    local rev = generator.compute_chronological_mapping(poems_data, 3, true)
    check("forward: oldest on page 1, newest on page 3", fwd[1].page_number == 1 and fwd[7].page_number == 3)
    check("reversed: newest on page 1, oldest on page 3", rev[7].page_number == 1 and rev[1].page_number == 3)
    check("reversed page 1 holds the newest three", rev[5].page_number == 1 and rev[6].page_number == 1
        and rev[4].page_number == 2)
    check("positions stay oldest-first in both modes", fwd[3].position == rev[3].position and rev[1].position == 1)
    check("each entry carries its timestamp", type(rev[2].timestamp) == "number"
        and rev[2].timestamp < rev[3].timestamp)
    local same = true
    local default = generator.compute_chronological_mapping(poems_data, 3, nil)
    for k, v in pairs(fwd) do
        if v.page_number ~= default[k].page_number or v.position ~= default[k].position then same = false end
    end
    check("no reverse argument is the forward mapping", same)
end
-- }}}

-- {{{ Case: similar / different laid out by date
do
    local mapping = generator.compute_chronological_mapping(poems_data, 3, true)
    -- A score-ordered list: 3, 7, 1, 5, 4, 2, 6 -- then a gallery picture (not in
    -- the mapping) dated between poems 2 and 3, and one with no date at all.
    local list = {}
    for _, idx in ipairs({ 3, 7, 1, 5, 4, 2, 6 }) do list[#list + 1] = { id = idx, poem = poems[idx] } end
    list[#list + 1] = { id = 900, poem = { poem_index = 900, creation_date = "2024-01-02T18:00:00Z" } }
    list[#list + 1] = { id = 901, poem = { poem_index = 901 } }

    local function ids(l, n)
        local out = {}
        for i = 1, (n or #l) do out[#out + 1] = tostring(l[i].id) end
        return table.concat(out, ",")
    end

    local similar = R.reorder_by_date(list, "similar", #list, mapping)
    check("similar is newest first, ties by chronological position, the undated last",
        ids(similar) == "7,6,5,4,3,900,2,1,901", ids(similar))
    local different = R.reorder_by_date(list, "different", #list, mapping)
    check("different is oldest first, the undated last",
        ids(different) == "1,2,900,3,4,5,6,7,901", ids(different))

    local seen = {}
    for _, e in ipairs(similar) do seen[e.id] = (seen[e.id] or 0) + 1 end
    local same_set = #similar == #list
    for _, e in ipairs(list) do if seen[e.id] ~= 1 then same_set = false end end
    check("the same poems, each once", same_set)
    check("the list it was given is not changed", ids(list) == "3,7,1,5,4,2,6,900,901")

    local part = R.reorder_by_date(list, "similar", 4, mapping)
    check("only the shown part is re-sorted; the rest keeps its score order",
        ids(part) == "7,5,3,1,4,2,6,900,901", ids(part))

    -- The worker threads' similarity entries carry the poem but no id. These
    -- poems also carry no creation_date of their own, so only the mapping (keyed
    -- by poem_index) can date them; left undated they would keep score order.
    local no_ids = {}
    for _, idx in ipairs({ 2, 6, 4 }) do
        no_ids[#no_ids + 1] = { poem = { poem_index = idx }, rank = #no_ids + 1 }
    end
    local sorted_no_ids = R.reorder_by_date(no_ids, "similar", 3, mapping)
    check("entries without an id are dated by their poem's index",
        sorted_no_ids[1].poem.poem_index == 6 and sorted_no_ids[3].poem.poem_index == 2)

    check("an unknown kind is refused", not pcall(R.reorder_by_date, list, "sideways", 3, mapping))
    check("no mapping is refused", not pcall(R.reorder_by_date, list, "similar", 3, nil))
end
-- }}}

-- {{{ Case: the chronological pages themselves
do
    local default_dir = fresh("default")
    local reverse_dir = fresh("reverse")
    local legacy_dir = fresh("legacy")
    check("forward pages build", pcall(generator.generate_chronological_index_with_navigation,
        poems_data, default_dir, 3, false))
    check("reversed pages build", pcall(generator.generate_chronological_index_with_navigation,
        poems_data, reverse_dir, 3, true))
    check("pages build without the new argument", pcall(generator.generate_chronological_index_with_navigation,
        poems_data, legacy_dir, 3))

    local same = true
    for p = 1, 3 do
        local name = string.format("/chronological/%02d.html", p)
        if read_file(default_dir .. name) ~= read_file(legacy_dir .. name) then same = false end
    end
    check("the default build is byte-for-byte what it was", same)

    local function order_on(dir, page)
        local text = read_file(string.format("%s/chronological/%02d.html", dir, page)) or ""
        local out = {}
        for n in text:gmatch("words of poem (%d)") do out[#out + 1] = n end
        return table.concat(out, ",")
    end
    check("forward page 1 is the oldest three", order_on(default_dir, 1) == "1,2,3", order_on(default_dir, 1))
    check("reversed page 1 is the newest three, oldest at the top",
        order_on(reverse_dir, 1) == "5,6,7", order_on(reverse_dir, 1))
    check("reversed page 2 is the three before them", order_on(reverse_dir, 2) == "2,3,4", order_on(reverse_dir, 2))
    check("the short page is the last, with the oldest poem", order_on(reverse_dir, 3) == "1", order_on(reverse_dir, 3))

    -- The link promise: every poem is on the page the mapping sends links to.
    local mapping = generator.compute_chronological_mapping(poems_data, 3, true)
    local all_there = true
    for idx, info in pairs(mapping) do
        local page = read_file(string.format("%s/chronological/%02d.html", reverse_dir, info.page_number)) or ""
        if not page:find("words of poem " .. idx, 1, true) then all_there = false end
    end
    check("every poem is on the page its links point to", all_there)

    local r1 = read_file(reverse_dir .. "/chronological/01.html") or ""
    check("a reversed page says so", r1:find("Newest poems first", 1, true) ~= nil)
    check("a forward page does not", not (read_file(default_dir .. "/chronological/01.html") or "")
        :find("Newest poems first", 1, true))
end
-- }}}

-- {{{ Case: the explore page states the order the build used
do
    local synced = os.execute('"' .. PROJECT .. 'scripts/sync-page-templates" "' .. PROJECT .. '" >/dev/null')
    check("the page templates are synced into input/pages", synced == 0 or synced == true)
    local a, b, c = fresh("explore-a"), fresh("explore-b"), fresh("explore-c")
    check("explore builds without the argument", pcall(generator.generate_explore_page, a, poems_data))
    check("explore builds forward", pcall(generator.generate_explore_page, b, poems_data, false))
    check("explore builds reversed", pcall(generator.generate_explore_page, c, poems_data, true))
    local pa, pb, pc = read_file(a .. "/explore.html") or "", read_file(b .. "/explore.html") or "",
        read_file(c .. "/explore.html") or ""
    check("the default page has no ordering note and is unchanged",
        pa == pb and not pa:find("built newest first", 1, true) and not pa:find("{ORDERING_NOTE}", 1, true))
    check("the default page keeps its paragraph break",
        pa:find("third poem.\n\nThere's also a wordcloud", 1, true) ~= nil)
    check("a reversed build says how it is ordered",
        pc:find("This copy of the site is built newest first.", 1, true) ~= nil
        and pc:find("third poem.\n\nThis copy", 1, true) ~= nil
        and pc:find("the oldest.\n\nThere's also a wordcloud", 1, true) ~= nil)
end
-- }}}

-- {{{ Case: the flag reaches main.lua
do
    local utils = require("utils")
    local opts = utils.parse_cli_args({ "--html-only", "--reverse", "--chrono-per-page", "3" })
    check("main.lua's parser reads --reverse", opts.reverse == true and opts.chrono_per_page == 3)
    check("and it is off by default", utils.parse_cli_args({ "--html-only" }).reverse == false)
end
-- }}}

-- {{{ Case: run.sh forwards --reverse wherever it forwards the page size
-- The pre-flight gate needs the real poem list, so a dry run cannot reach the
-- stage commands on a machine without it; this reads run.sh instead. The rule
-- the issue calls critical: every command that is handed --chrono-per-page is
-- handed the reading order too, or its links number the pages differently.
do
    local run_sh = read_file(PROJECT .. "run.sh") or ""
    local with_size, with_both = 0, 0
    for line in run_sh:gmatch("[^\n]+") do
        if line:find("luajit", 1, true) and line:find("$chrono_per_page_arg", 1, true) then
            with_size = with_size + 1
            if line:find("$reverse_arg", 1, true) then with_both = with_both + 1 end
        end
    end
    check("run.sh hands the page size to six commands (three programs, run and dry run)", with_size == 6,
        tostring(with_size))
    check("and the reading order to every one of them", with_both == with_size,
        with_both .. " of " .. with_size)
    check("run.sh parses --reverse", run_sh:find("        --reverse)\n            REVERSE=true", 1, true) ~= nil)
    check("its help lists it", run_sh:find("\n  --reverse ", 1, true) ~= nil)
    check("the menu offers it", run_sh:find('menu_add_item "config" "reverse"', 1, true) ~= nil)
    check("the build record says which order was used", run_sh:find('"reverse": $REVERSE,', 1, true) ~= nil)
    for _, prog in ipairs({ "wordcloud-generator.lua", "generate-word-pages.lua" }) do
        local src = read_file(PROJECT .. "src/" .. prog) or ""
        check(prog .. " reads --reverse and numbers its links with it",
            src:find('a == "--reverse"', 1, true) ~= nil
            and src:find("compute_chronological_mapping(poems_data, per_page, CLI_REVERSE)", 1, true) ~= nil)
    end
end
-- }}}

os.execute('rm -rf "' .. SCRATCH .. '"')
print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
