#!/usr/bin/env luajit
-- notes.lua: a small note keeper.
--   notes add <text with #tags>     add a note
--   notes list [#tag]               list notes, or those with a tag
--   notes find <word>               notes whose text holds the word
-- Notes live in the file named by NOTES_FILE, or ./notes.txt.
package.path = (arg[0]:match("^(.*)/[^/]*$") or ".") .. "/?.lua;" .. package.path
local store = require("src.store")
local tags = require("src.tags")
local dates = require("src.dates")
local show = require("src.show")
local search = require("src.search")

local path = os.getenv("NOTES_FILE") or "notes.txt"
local command = arg[1]
local notes = store.load(path)

if command == "add" then
    local text = table.concat(arg, " ", 2)
    local note = { id = store.next_id(notes), date = dates.today(), tags = tags.parse(text), text = text }
    notes[#notes + 1] = note
    store.save(path, notes)
    print("added " .. note.id)
elseif command == "list" then
    if arg[2] then
        notes = tags.filter(notes, arg[2])
    end
    print(show.list(notes))
elseif command == "find" then
    print(show.list(search.find(notes, arg[2] or "")))
else
    print("usage: notes add <text> | notes list [#tag] | notes find <word>")
    os.exit(1)
end
