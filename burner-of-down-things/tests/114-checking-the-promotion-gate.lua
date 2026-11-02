-- 114-checking-the-promotion-gate.lua
--
-- Checks issue 1003d (and 1003's second test): a draft never appears in
-- strategems/ without the person's promotion script having been run --
-- drafting, however many times and however often a mechanism recurs, only
-- ever writes in strategems/drafts/; the script moves a draft out, and
-- after that the machine leaves the kept strategem as the person has it.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local lesson = require("085-the-lesson")
local drafts = require("111-the-strategem-drafts")
local rows = require("115-the-strategem-commands")

-- A project copy with a strategems folder of its own, holding one
-- hand-written strategem, so the script and the command run on the copy.
local project_dir = kit.scratch("promotion-gate")
kit.fs.run("cp -r " .. kit.fs.quote(kit.DIR .. "/src") .. " " .. kit.fs.quote(project_dir .. "/src"))
local strategems = project_dir .. "/strategems"
kit.write_file(strategems .. "/a-referee-never-sees-the-answer.md",
    kit.fs.read(kit.DIR .. "/strategems/a-referee-never-sees-the-answer.md"))
local lessons_path = project_dir .. "/output/story/lessons.md"
local mechanism = "a builder grading its own work passes itself"
local name = drafts.name_for(mechanism)

-- {{{ local function top_level
-- The strategems/ folder's own files, drafts/ aside.
local function top_level()
    local out = {}
    for _, n in ipairs(kit.fs.list(strategems)) do
        if n ~= "drafts" then out[#out + 1] = n end
    end
    return table.concat(out, " ")
end
-- }}}

-- {{{ local function run_command
local function run_command()
    local run = { project = { dir = project_dir, output = project_dir .. "/output" },
        args = {}, done = {}, waiting = {}, failed = {}, say = function() end }
    rows.strategems.run(run)
    return run
end
-- }}}

local before = top_level()
for i = 1, 4 do
    lesson.append(lessons_path, lesson.build({ case = "case-" .. i, ledger_lines = { i },
        what_happened = "lesson " .. i, mechanism = mechanism }))
    local run = run_command()
    kit.equal(top_level(), before, "after recurrence " .. i .. ", drafting has written nothing in strategems/ itself")
    if i == 2 then
        kit.check(run.waiting[1] and run.waiting[1]:find(name, 1, true) ~= nil,
            "the new draft is named as waiting for the person")
    end
end
kit.check(kit.fs.exists(strategems .. "/drafts/" .. name), "the draft sits in strategems/drafts/")
kit.equal(rows.strategems.needs_case, false, "the drafting command works on the project, not a case")

-- The person's own step.
local script = kit.DIR .. "/scripts/116-promote-strategem.lua"
local output, ok = kit.fs.capture("luajit " .. kit.fs.quote(script) .. " " .. kit.fs.quote(project_dir)
    .. " " .. kit.fs.quote(name:gsub("%.md$", "")) .. " 2>&1")
kit.check(ok, "the promotion script runs")
kit.check(output:find("kept " .. strategems .. "/" .. name, 1, true) ~= nil, "it says where the strategem is kept")
kit.check(output:find("still to write in your own words: What it means; The shape; When not to use it", 1, true) ~= nil,
    "it names the sections still to be written")
kit.check(kit.fs.exists(strategems .. "/" .. name), "the strategem is in strategems/ after the person's step")
kit.check(not kit.fs.exists(strategems .. "/drafts/" .. name), "and no longer among the drafts")
local kept = kit.fs.read(strategems .. "/" .. name)
kit.check(kept:find("^# Strategem: A builder grading") ~= nil, "a kept strategem is no longer titled a draft")

-- After keeping, a further recurrence neither re-drafts nor touches it.
kit.write_file(strategems .. "/" .. name, kept .. "\nThe person's own last word.\n")
local kept_text = kit.fs.read(strategems .. "/" .. name)
lesson.append(lessons_path, lesson.build({ case = "case-5", ledger_lines = { 5 },
    what_happened = "lesson 5", mechanism = mechanism }))
local result = drafts.draft_due(lessons_path, strategems)
kit.equal(#result.drafted, 0, "a kept mechanism is not drafted again")
kit.equal(#result.kept, 1, "its recurrence is reported, not written")
kit.equal(kit.fs.read(strategems .. "/" .. name), kept_text, "the kept strategem is left as the person has it")
kit.check(not kit.fs.exists(strategems .. "/drafts/" .. name), "no new draft appears beside it")

-- The gate refuses what it should.
local _, again_ok = kit.fs.capture("luajit " .. kit.fs.quote(script) .. " " .. kit.fs.quote(project_dir)
    .. " " .. kit.fs.quote(name) .. " 2>&1")
kit.check(not again_ok, "promoting a draft that is not there is refused")
kit.raises(function() drafts.promote(strategems, "../a-referee-never-sees-the-answer.md") end,
    "file name alone", "a name reaching outside drafts/ is refused")
kit.write_file(strategems .. "/drafts/a-referee-never-sees-the-answer.md", "# Strategem (draft): x\n")
kit.raises(function() drafts.promote(strategems, "a-referee-never-sees-the-answer") end,
    "already kept", "a draft never overwrites a strategem already kept under its name")

kit.finish()
