-- dates.lua: notes are stamped with the day they were written.
local dates = {}

function dates.today()
    return os.date("%Y-%m-%d")
end

function dates.is_date(text)
    return text:match("^%d%d%d%d%-%d%d%-%d%d$") ~= nil
end

return dates
