-- 119-checking-number-issuance.lua
--
-- Checks issue 901c: the next tag number is one more than the highest
-- recorded in any case's ledger; with nothing recorded it is 1; the
-- `number` command prints it and records nothing.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local case = require("018-the-case")
local ledger = require("016-ledger")
local numbers = require("117-tag-numbers")
local rows = require("118-the-switchboard-commands")

local project, folder = kit.project_copy("number-issuance")
kit.equal(numbers.next_free(project), 1, "with no cases at all, the next number is 1")

local source = folder .. "/source"
kit.write_file(source .. "/a.lua", "print('a')\n")
local notes = case.open(project, "notes", source, "stand-in")
local receipts = case.open(project, "receipts", source, "stand-in")
kit.equal(numbers.next_free(project), 1, "with cases but no number recorded, the next number is 1")

ledger.append(notes.ledger, "numbered", "1", "draw a circle")
ledger.append(notes.ledger, "numbered", "2", "chart these numbers")
ledger.append(receipts.ledger, "numbered", "3", "sum the receipts")
local found, highest = numbers.recorded(project)
kit.equal(highest, 3, "the highest recorded is read across every case's ledger")
kit.equal(found[3] and found[3].case, "receipts", "each number's first use names its case")
kit.equal(found[1] and found[1].line, 2, "each number's first use names its ledger line")
kit.equal(numbers.next_free(project), 4, "the next number is one more than the highest recorded")

-- {{{ local function a_run
local function a_run()
    local said = {}
    return { project = project, args = {}, done = {}, waiting = {}, failed = {},
        say = function(...) said[#said + 1] = table.concat({ ... }) end, said = said }
end
-- }}}

local run = a_run()
rows.number.run(run)
kit.equal(run.said[1], "language model prompt 4: <what is wanted>", "the command prints the tag with the next number")
kit.equal(numbers.next_free(project), 4, "asking for a number records nothing")
kit.equal(rows.number.needs_case, false, "the command works on the project, not a case")

kit.finish()
