-- 091-checking-switchboard-settings.lua
--
-- Checks the open-question-12 groundwork: the router model slot reads as
-- unset until written, and round-trips once it is.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local settings = require("090-switchboard-settings")

-- A minimal project table of our own, not kit.project_copy: that helper
-- isolates only `.cases`, and settings.path is built from `.dir` — using
-- the shared copy would read and write the real project's own file.
local project = { dir = kit.scratch("switchboard-settings") }

kit.equal(settings.read(project).router_model, nil, "no model chosen yet reads as nil, not an error")

settings.write(project, { router_model = "llama3.2" })
kit.equal(settings.read(project).router_model, "llama3.2", "a written model round-trips")

kit.finish()
