-- {{{ Template library
-- Finding templates in storage (src/storage/template_storage.lua):
-- search by words and filters, favourites, recently used and how often
-- each is used. Preferences are kept in library_preferences.json beside
-- the templates.
--
--   TemplateLibrary:new(storage, options)  options.max_recent (10)
--   library:search(query, filters)  filters: category, unit_type,
--                                   ability (a name), favorites_only,
--                                   min_points, max_points
--   library:use(name, category)     loads it, counting the use
--   library:set_favorite(name, category, on) / is_favorite
--   library:recent()                {category, name}, newest first
--
-- Templates are keyed "category/name", so the same name in two
-- categories is two templates.
local TemplateLibrary = {}
TemplateLibrary.__index = TemplateLibrary

local json = require("libs.dkjson.dkjson")

TemplateLibrary.PREFERENCES_FILE = "library_preferences.json"

-- {{{ local function key_of
local function key_of(category, name)
    return tostring(category) .. "/" .. tostring(name)
end
-- }}}

-- {{{ TemplateLibrary:new
function TemplateLibrary:new(storage, options)
    options = options or {}
    local library = {
        storage = storage,
        max_recent = options.max_recent or 10,
        favorites = {},     -- key -> true
        recent_list = {},   -- keys, newest first
        usage = {}          -- key -> count
    }
    setmetatable(library, self)
    library:load_preferences()
    return library
end
-- }}}

-- {{{ TemplateLibrary:preferences_path
function TemplateLibrary:preferences_path()
    return self.storage:path(TemplateLibrary.PREFERENCES_FILE)
end
-- }}}

-- {{{ TemplateLibrary:load_preferences
function TemplateLibrary:load_preferences()
    local text = self.storage.backend.read(self:preferences_path())
    local data = text and json.decode(text)
    if type(data) ~= "table" then
        return false
    end
    for _, key in ipairs(data.favorites or {}) do
        self.favorites[key] = true
    end
    for _, key in ipairs(data.recent or {}) do
        table.insert(self.recent_list, key)
    end
    for key, count in pairs(data.usage or {}) do
        self.usage[key] = tonumber(count) or 0
    end
    return true
end
-- }}}

-- {{{ TemplateLibrary:save_preferences
function TemplateLibrary:save_preferences()
    local favorites = {}
    for key in pairs(self.favorites) do
        table.insert(favorites, key)
    end
    table.sort(favorites)
    local data = {favorites = favorites, recent = self.recent_list, usage = self.usage}
    return self.storage.backend.write(self:preferences_path(), json.encode(data, {indent = true}))
end
-- }}}

-- {{{ TemplateLibrary:set_favorite
function TemplateLibrary:set_favorite(name, category, on)
    local key = key_of(category or "user", name)
    self.favorites[key] = (on ~= false) or nil
    self:save_preferences()
end
-- }}}

-- {{{ TemplateLibrary:is_favorite
function TemplateLibrary:is_favorite(name, category)
    return self.favorites[key_of(category or "user", name)] == true
end
-- }}}

-- {{{ TemplateLibrary:add_to_recent
function TemplateLibrary:add_to_recent(name, category)
    local key = key_of(category or "user", name)
    for index = #self.recent_list, 1, -1 do
        if self.recent_list[index] == key then
            table.remove(self.recent_list, index)
        end
    end
    table.insert(self.recent_list, 1, key)
    while #self.recent_list > self.max_recent do
        table.remove(self.recent_list)
    end
end
-- }}}

-- {{{ TemplateLibrary:recent
function TemplateLibrary:recent()
    local list = {}
    for _, key in ipairs(self.recent_list) do
        local category, name = key:match("^([^/]+)/(.*)$")
        table.insert(list, {category = category, name = name})
    end
    return list
end
-- }}}

-- {{{ TemplateLibrary:use
-- Loads a template for play, counting the use and putting it first in
-- the recent list. Returns what TemplateStorage:load_template returns.
function TemplateLibrary:use(name, category)
    category = category or "user"
    local template, info = self.storage:load_template(name, category)
    if template then
        local key = key_of(category, name)
        self.usage[key] = (self.usage[key] or 0) + 1
        self:add_to_recent(name, category)
        self:save_preferences()
    end
    return template, info
end
-- }}}

-- {{{ TemplateLibrary:usage_count
function TemplateLibrary:usage_count(name, category)
    return self.usage[key_of(category or "user", name)] or 0
end
-- }}}

-- {{{ local function contains
local function contains(text, word)
    return type(text) == "string" and text:lower():find(word, 1, true) ~= nil
end
-- }}}

-- {{{ TemplateLibrary:relevance
-- How well an index entry matches the query's words: every word must
-- match somewhere, or the entry scores nil. A whole-name match scores
-- highest, then the start of the name, a word in the name, an ability
-- or tag, then the description.
function TemplateLibrary:relevance(entry, words, query)
    local score = 0
    local name = entry.name:lower()
    if query ~= "" and name == query then
        score = score + 100
    elseif query ~= "" and name:sub(1, #query) == query then
        score = score + 60
    end
    for _, word in ipairs(words) do
        local best = 0
        if contains(entry.name, word) then
            best = 40
        end
        for _, ability in ipairs(entry.abilities or {}) do
            if best < 20 and contains(ability, word) then
                best = 20
            end
        end
        for _, tag in ipairs(entry.tags or {}) do
            if best < 20 and contains(tag, word) then
                best = 20
            end
        end
        if best < 20 and contains(entry.unit_type, word) then
            best = 20
        end
        if best < 10 and contains(entry.description, word) then
            best = 10
        end
        if best == 0 then
            return nil
        end
        score = score + best
    end
    return score
end
-- }}}

-- {{{ TemplateLibrary:passes
function TemplateLibrary:passes(entry, filters)
    if filters.category and entry.category ~= filters.category then
        return false
    end
    if filters.unit_type and entry.unit_type ~= filters.unit_type then
        return false
    end
    if filters.favorites_only and not self:is_favorite(entry.name, entry.category) then
        return false
    end
    if filters.min_points and (entry.points_used or 0) < filters.min_points then
        return false
    end
    if filters.max_points and (entry.points_used or 0) > filters.max_points then
        return false
    end
    if filters.ability then
        local found = false
        for _, ability in ipairs(entry.abilities or {}) do
            if ability == filters.ability then
                found = true
            end
        end
        if not found then
            return false
        end
    end
    return true
end
-- }}}

-- {{{ TemplateLibrary:search
-- Matching index entries, best first: each a copy of the entry with
-- relevance, favorite and uses added. Favourites get a small lift and
-- frequent use a smaller one; ties go by name, then category.
function TemplateLibrary:search(query, filters)
    filters = filters or {}
    query = tostring(query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local words = {}
    for word in query:gmatch("%S+") do
        table.insert(words, word)
    end
    local results = {}
    for _, entry in ipairs(self.storage:list_templates()) do
        if self:passes(entry, filters) then
            local score = self:relevance(entry, words, query)
            if score then
                entry.favorite = self:is_favorite(entry.name, entry.category)
                entry.uses = self:usage_count(entry.name, entry.category)
                entry.relevance = score + (entry.favorite and 5 or 0) + math.min(entry.uses, 10) * 0.5
                table.insert(results, entry)
            end
        end
    end
    table.sort(results, function(a, b)
        if a.relevance ~= b.relevance then
            return a.relevance > b.relevance
        end
        if a.name ~= b.name then
            return a.name < b.name
        end
        return a.category < b.category
    end)
    return results
end
-- }}}

return TemplateLibrary
-- }}}
