-- 090-switchboard-settings.lua
--
-- The switchboard's own settings record (docs/068; docs/010 open question
-- 12): today, just which model the ollama row (903c) should read and run.
-- This does not pick a model — which one to run on the owner's GTX 1080 Ti
-- is still the owner's own open question — it only builds the slot that
-- answer will go into, and the record that holds it, so 903c has
-- somewhere real to read from the day the question is answered.

local fs = require("017-the-filesystem")
local text_tables = require("014-text-tables")

local settings = {}

-- {{{ function settings.path
function settings.path(project)
    return project.dir .. "/switchboard-settings.lua"
end
-- }}}

-- {{{ function settings.read
-- The settings record. A missing file, and a file with no router_model
-- key, both read the same way: `.router_model` is nil, which is a fact to
-- report ("no model chosen yet"), not an error — refusing a turn that
-- needs one and finds none is 903c's own job, not this record's.
function settings.read(project)
    local path = settings.path(project)
    if not fs.exists(path) then
        return {}
    end
    return text_tables.read_record(path)
end
-- }}}

-- {{{ function settings.write
function settings.write(project, fields)
    text_tables.write_record(settings.path(project), fields)
end
-- }}}

-- {{{ function settings.resolve_model
-- The model an ollama turn should run (issue 903c): the case's own
-- override first (a `router-model` file in its folder, one line), then
-- the switchboard's own setting (read/write above). Refuses when neither
-- names one, saying both places checked — never a silent default model.
function settings.resolve_model(project, record)
    local override_path = record.folder .. "/router-model"
    local file = io.open(override_path, "rb")
    if file then
        local model = file:read("*l")
        file:close()
        if model and model ~= "" then
            return model
        end
    end
    local switchboard = settings.read(project)
    if switchboard.router_model then
        return switchboard.router_model
    end
    error("switchboard settings: no model named for the router -- neither "
        .. override_path .. " nor router_model in " .. settings.path(project))
end
-- }}}

return settings
