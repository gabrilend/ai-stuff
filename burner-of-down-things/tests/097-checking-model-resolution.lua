-- 097-checking-model-resolution.lua
--
-- Checks issue 903c: a case naming a model wins over the switchboard
-- default; neither present is refused, naming what is missing.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local settings = require("090-switchboard-settings")

-- A minimal project table of our own, not kit.project_copy: that helper
-- isolates only `.cases`, and settings.path is built from `.dir` — using
-- the shared copy would read and write the real project's own file
-- (091's test learned this the same way).
local folder = kit.scratch("model-resolution")
local project = { dir = folder }
local record = { folder = folder .. "/fixture-case" }
kit.fs.make_folder(record.folder)

kit.raises(function() settings.resolve_model(project, record) end, "no model named",
    "neither a case override nor a switchboard setting is refused")

settings.write(project, { router_model = "llama3.2" })
kit.equal(settings.resolve_model(project, record), "llama3.2",
    "the switchboard's own setting is used when the case names nothing")

kit.write_file(record.folder .. "/router-model", "qwen2.5:7b\n")
kit.equal(settings.resolve_model(project, record), "qwen2.5:7b",
    "the case's own override wins over the switchboard default")

kit.finish()
