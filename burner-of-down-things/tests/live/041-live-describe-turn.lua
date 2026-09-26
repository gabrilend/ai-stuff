-- 041-live-describe-turn.lua
--
-- ONE REAL TURN OF CLAUDE CODE. This spends the owner's subscription, so it
-- is kept out of tests/run-tests (it lives in tests/live/) and is run only by
-- hand, when the owner says so:
--
--   luajit tests/live/041-live-describe-turn.lua /mnt/mtwo/programming/ai-stuff/burner-of-down-things
--
-- It opens a scratch case on a two-file source, prepares one describe turn,
-- runs it through the claude-code harness row exactly as the machine would,
-- and reports the verdict, the file written, and whether the turn stayed in
-- its folders. It is the check that the command line in the harness table is
-- accepted by the installed Claude Code and that confinement holds against a
-- real model.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local fs = kit.fs
local case = require("018-the-case")
local kinds = require("034-turn-kinds")
local pool = require("039-the-turn-pool")

local project, folder = kit.project_copy("live")
local src = folder .. "/source"
kit.write_file(src .. "/greet.lua", 'local names = require("names")\nfor _, n in ipairs(names) do print("hello, " .. n) end\n')
kit.write_file(src .. "/names.lua", 'return { "ada", "grace" }\n')
local record = case.open(project, "live", src, "claude-code")

local turn = kinds.make_turn(record, "describe", {
    about = "101", name = "greeting-everyone", blocked_by = "-",
    covered_files = "greet.lua\nnames.lua",
    issue_path = record.issues .. "/101-greeting-everyone.md",
    outline_text = "#id\tname\tblocked_by\tcovers\n101\tgreeting-everyone\t-\tgreet.lua names.lua",
    findings = "none",
})
local results = pool.run_set(project, record, { turn }, { limit = 600 })
local r = results[1]
print("verdict: " .. r.verdict .. " (" .. r.why .. ")")
for _, c in ipairs(r.changes) do
    print("  " .. c.how .. " " .. c.path)
end
kit.equal(r.verdict, "kept", "the real turn is kept")
kit.check(fs.exists(record.issues .. "/101-greeting-everyone.md"), "it wrote the issue file")
print(fs.read(turn.folder .. "/result.json"):sub(1, 400))
kit.finish()
