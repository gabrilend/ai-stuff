-- Simple JSON wrapper module using dkjson
local dkjson = require("libs.dkjson")

local M = {}

function M.encode(data)
    return dkjson.encode(data)
end

function M.decode(json_string)
    return dkjson.decode(json_string)
end

return M