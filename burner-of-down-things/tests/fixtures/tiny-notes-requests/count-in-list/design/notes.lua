#!/usr/bin/env luajit
-- notes.lua (built from blueprint issue 301): the program a person runs.
local here = (arg[0]:match("^(.*)/[^/]*$") or ".")
package.path = here .. "/?.lua;" .. package.path
local store = require("src.store")
local tags = require("src.tags")
local dates = require("src.dates")
local show = require("src.show")
local search = require("src.search")

local path = os.getenv("NOTES_FILE") or "notes.txt"
local notes = store.load(path)

-- The count line after a list (301, amended: "N notes", "1 note" for one).
local function count_line(shown)
    return #shown .. (#shown == 1 and " note" or " notes")
end

-- One row per command (301's table); anything else prints the usage.
local COMMANDS = {
    add = function(args)
        local text = table.concat(args, " ", 2)
        local note = { id = store.next_id(notes), date = dates.today(), tags = tags.parse(text), text = text }
        notes[#notes + 1] = note
        store.save(path, notes)
        print("added " .. note.id)
    end,
    list = function(args)
        local shown = notes
        if args[2] then
            shown = tags.filter(notes, args[2])
        end
        print(show.list(shown))
        print(count_line(shown))
    end,
    find = function(args)
        print(show.list(search.find(notes, args[2] or "")))
    end,
}

local run = COMMANDS[arg[1] or ""]
if not run then
    print("usage: notes add <text> | notes list [#tag] | notes find <word>")
    os.exit(1)
end
run(arg)
