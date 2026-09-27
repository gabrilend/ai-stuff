-- store.lua (built from blueprint issue 101): notes in a plain text file,
-- one per line — id, date, tags joined by commas, text — tab-separated.
local store = {}

-- The first line of every notes file (101, amended).
store.HEADER = "# notes v1"

function store.load(path)
    local notes = {}
    local file = io.open(path, "r")
    -- A missing file is an empty notebook, not an error (101).
    if not file then
        return notes
    end
    for line in file:lines() do
        local id, date, tag_text, text = line:match("^(%d+)\t([^\t]*)\t([^\t]*)\t(.*)$")
        -- The header, and lines of any other shape, are skipped (101).
        if id then
            local tags = {}
            for tag in tag_text:gmatch("[^,]+") do
                tags[#tags + 1] = tag
            end
            notes[#notes + 1] = { id = tonumber(id), date = date, tags = tags, text = text }
        end
    end
    file:close()
    return notes
end

function store.save(path, notes)
    local file = assert(io.open(path, "w"))
    file:write(store.HEADER, "\n")
    for _, note in ipairs(notes) do
        file:write(note.id, "\t", note.date, "\t", table.concat(note.tags, ","), "\t", note.text, "\n")
    end
    file:close()
end

function store.next_id(notes)
    local highest = 0
    for _, note in ipairs(notes) do
        highest = math.max(highest, note.id)
    end
    return highest + 1
end

return store
