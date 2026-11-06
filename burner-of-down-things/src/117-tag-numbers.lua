-- 117-tag-numbers.lua
--
-- The numbers in tags (docs/068, issues 901c and 901d). A tag reads
-- `language model prompt <number>: <what is wanted>`, and the number is
-- given by the machine, never chosen by whoever writes the tag: the next
-- free number is always one more than the highest recorded (901c). A
-- number is recorded once, as a `numbered` line in the ledger of the case
-- whose parcel first used it; a parcel reusing a recorded number is
-- refused, naming that first use -- the case and the ledger line (901d).
--
-- Numbers belong to the whole project, not to one case: the highest
-- recorded is read across every case's ledger, so "prompt 7" means one
-- thing wherever it turns up.

local ledger = require("016-ledger")
local fs = require("017-the-filesystem")
local parcel = require("079-the-parcel")

local numbers = {}

-- {{{ function numbers.recorded
-- Every number recorded so far, across every case of the project:
-- {[number] = {case, line, wish}} for each number's first use (its
-- `numbered` ledger line), and the highest number recorded (0 for none).
-- Reads only; a case folder with no ledger is skipped.
function numbers.recorded(project)
    local found, highest = {}, 0
    if not fs.is_folder(project.cases) then
        return found, highest
    end
    for _, case_name in ipairs(fs.list(project.cases)) do
        local ledger_path = project.cases .. "/" .. case_name .. "/ledger"
        if fs.exists(ledger_path) then
            for _, line in ipairs(ledger.read(ledger_path)) do
                if line.kind == "numbered" then
                    local n = tonumber(line.about)
                    if n and not found[n] then
                        found[n] = { case = case_name, line = line.seq, wish = line.text }
                        if n > highest then
                            highest = n
                        end
                    end
                end
            end
        end
    end
    return found, highest
end
-- }}}

-- {{{ function numbers.next_free
-- The number the machine gives the next tag: one more than the highest
-- recorded in any case's ledger, 1 when none is.
function numbers.next_free(project)
    local _, highest = numbers.recorded(project)
    return highest + 1
end
-- }}}

-- {{{ local function first_use_text
local function first_use_text(n, use)
    return string.format("number %d was first used in case %s, ledger line %d (%s)",
        n, use.case, use.line, use.wish)
end
-- }}}

-- {{{ function numbers.accept
-- Takes a parcel (079's `read` shape) arriving at case `record`. Returns:
--   { tagged = false }                    no tag: accepted as it is, and
--                                         nothing is recorded
--   { tagged = true, number, wish, line } a fresh number, now recorded once
--                                         as a `numbered` ledger line
--   nil, finding                          refused: a malformed tag, a
--                                         number already recorded (naming
--                                         its first use), or one the
--                                         machine has not given yet
-- The case's lock must be held, as for any ledger append.
function numbers.accept(project, record, p)
    local n, wish_or_finding = parcel.tag(p)
    if n == nil then
        if wish_or_finding then
            return nil, wish_or_finding
        end
        return { tagged = false }
    end
    local found, highest = numbers.recorded(project)
    if found[n] then
        return nil, "refused: " .. first_use_text(n, found[n])
    end
    if n > highest + 1 then
        return nil, string.format("refused: number %d was not given by the machine; the next free number is %d",
            n, highest + 1)
    end
    local line = ledger.append(record.ledger, "numbered", tostring(n), wish_or_finding)
    return { tagged = true, number = n, wish = wish_or_finding, line = line.seq }
end
-- }}}

return numbers
