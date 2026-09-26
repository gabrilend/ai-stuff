-- store.lua: keeps notes in a plain text file, one note per line:
--   id <TAB> date <TAB> tags (comma-separated) <TAB> text
local store = {}

function store.load(path)
    local notes = {}
    local file = io.open(path, "r")
    if not file then
        return notes
    end
    for line in file:lines() do
        local id, date, tags, text = line:match("^(%d+)\t([^\t]*)\t([^\t]*)\t(.*)$")
        if id then
            local tag_list = {}
            for tag in tags:gmatch("[^,]+") do
                tag_list[#tag_list + 1] = tag
            end
            notes[#notes + 1] = { id = tonumber(id), date = date, tags = tag_list, text = text }
        end
    end
    file:close()
    return notes
end

function store.save(path, notes)
    local file = assert(io.open(path, "w"))
    for _, n in ipairs(notes) do
        file:write(n.id, "\t", n.date, "\t", table.concat(n.tags, ","), "\t", n.text, "\n")
    end
    file:close()
end

function store.next_id(notes)
    local highest = 0
    for _, n in ipairs(notes) do
        if n.id > highest then
            highest = n.id
        end
    end
    return highest + 1
end

return store
