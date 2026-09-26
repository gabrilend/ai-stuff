-- dates.lua (built from blueprint issue 103).
local dates = {}

function dates.today()
    return os.date("%Y-%m-%d")
end

function dates.is_date(text)
    return type(text) == "string" and text:match("^%d%d%d%d%-%d%d%-%d%d$") ~= nil
end

return dates
