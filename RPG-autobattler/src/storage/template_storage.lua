-- {{{ Template storage
-- Saves unit templates (src/data/unit_template.lua) to files and loads
-- them back, sorted into categories: "user" (a player's own), "default"
-- (shipped with the game) and "imported" (brought in from elsewhere).
--
-- Layout, under the storage root (default "templates"):
--   <category>/<name-slug>.template   one template, as JSON
--   backups/<category>/<slug>.<n>.template
--                                     earlier copies, kept before every
--                                     overwrite or delete
--   template_index.json               what's where, so nothing has to
--                                     list folders
--
-- A file holds an envelope:
--   {format = "rpg-autobattler-template", format_version, game_version,
--    saved_at, template = <UnitTemplate:to_save_data()>, metadata =
--    {author, description, tags}}
-- Files from older formats are moved forward on load by MIGRATIONS;
-- files from a newer format load with a warning, their unknown fields
-- ignored.
--
--   TemplateStorage:new(options)  options: backend (src/storage/
--                                 file_backends.lua; LÖVE's save folder
--                                 in the game, memory otherwise), root,
--                                 clock (seconds), max_backups (5),
--                                 game_version
--   storage:save_template(template, category, metadata)
--   storage:load_template(name, category)    template, info or nil, why
--   storage:list_templates(category)         index entries, by name
--   storage:delete_template(name, category)  backs up first
--   storage:list_backups(name, category) / restore_backup(...)
--   storage:export_template(name, category)  JSON text
--   storage:import_template(text)            saves to "imported"
--   storage:rebuild_index()                  from the files, where the
--                                            backend can list folders
local TemplateStorage = {}
TemplateStorage.__index = TemplateStorage

local json = require("libs.dkjson.dkjson")
local FileBackends = require("src.storage.file_backends")
local UnitTemplate = require("src.data.unit_template")

TemplateStorage.FORMAT = "rpg-autobattler-template"
TemplateStorage.FORMAT_VERSION = 1
TemplateStorage.GAME_VERSION = "0.1.0"
TemplateStorage.CATEGORIES = {"user", "default", "imported"}
TemplateStorage.EXTENSION = ".template"
TemplateStorage.INDEX_FILE = "template_index.json"

-- {{{ local function is_category
local function is_category(category)
    for _, name in ipairs(TemplateStorage.CATEGORIES) do
        if name == category then
            return true
        end
    end
    return false
end
-- }}}

-- {{{ TemplateStorage.slug
-- A file-safe form of a template name: lower case letters, digits and
-- hyphens, at most 40 characters.
function TemplateStorage.slug(name)
    local slug = tostring(name or ""):lower():gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
    slug = slug:sub(1, 40):gsub("%-+$", "")
    if slug == "" then
        slug = "template"
    end
    return slug
end
-- }}}

-- {{{ TemplateStorage:new
function TemplateStorage:new(options)
    options = options or {}
    local storage = {
        backend = options.backend or FileBackends.default(),
        root = (options.root or "templates"):gsub("/*$", ""),
        clock = options.clock or os.time,
        max_backups = options.max_backups or 5,
        game_version = options.game_version or TemplateStorage.GAME_VERSION,
        index = nil,
        warnings = {}
    }
    setmetatable(storage, self)
    storage:ensure_directories()
    storage:load_index()
    return storage
end
-- }}}

-- {{{ TemplateStorage:path
function TemplateStorage:path(...)
    return table.concat({self.root, ...}, "/")
end
-- }}}

-- {{{ TemplateStorage:ensure_directories
function TemplateStorage:ensure_directories()
    self.backend.make_directory(self.root)
    for _, category in ipairs(TemplateStorage.CATEGORIES) do
        self.backend.make_directory(self:path(category))
        self.backend.make_directory(self:path("backups", category))
    end
end
-- }}}

-- {{{ TemplateStorage:empty_index
function TemplateStorage.empty_index()
    local index = {format_version = 1, entries = {}, backups = {}}
    for _, category in ipairs(TemplateStorage.CATEGORIES) do
        index.entries[category] = {}
        index.backups[category] = {}
    end
    return index
end
-- }}}

-- {{{ TemplateStorage:load_index
-- Reads the index. A missing one starts empty; a damaged one is rebuilt
-- from the files where the backend can list them, with a warning.
function TemplateStorage:load_index()
    local text = self.backend.read(self:path(TemplateStorage.INDEX_FILE))
    local index = text and json.decode(text)
    if type(index) ~= "table" or type(index.entries) ~= "table" then
        self.index = TemplateStorage.empty_index()
        if text then
            table.insert(self.warnings, "The template index was damaged and has been rebuilt")
            self:rebuild_index()
        end
        return self.index
    end
    local fresh = TemplateStorage.empty_index()
    for _, category in ipairs(TemplateStorage.CATEGORIES) do
        fresh.entries[category] = index.entries[category] or {}
        fresh.backups[category] = (index.backups or {})[category] or {}
    end
    self.index = fresh
    return fresh
end
-- }}}

-- {{{ TemplateStorage:save_index
function TemplateStorage:save_index()
    return self.backend.write(self:path(TemplateStorage.INDEX_FILE), json.encode(self.index, {indent = true}))
end
-- }}}

-- {{{ TemplateStorage:envelope
function TemplateStorage:envelope(template, metadata)
    metadata = metadata or {}
    return {
        format = TemplateStorage.FORMAT,
        format_version = TemplateStorage.FORMAT_VERSION,
        game_version = self.game_version,
        saved_at = self.clock(),
        template = template:to_save_data(),
        metadata = {
            author = metadata.author or template.created_by,
            description = metadata.description or template.description,
            tags = metadata.tags or template.tags or {}
        }
    }
end
-- }}}

-- Steps that move an older envelope forward one format version each.
-- Version 0 is anything from before the envelope existed: a bare
-- UnitTemplate:to_save_data() table, or the shape issue 060's sketch
-- wrote ({template_version, template_data, metadata}).
TemplateStorage.MIGRATIONS = {
    [0] = function(data)
        local template = data.template_data or data
        return {
            format = TemplateStorage.FORMAT,
            format_version = 1,
            game_version = data.game_version,
            saved_at = data.timestamp or data.saved_at,
            template = template,
            metadata = data.metadata or {author = template.created_by, description = template.description, tags = {}}
        }
    end
}

-- {{{ TemplateStorage.decode
-- Turns file text into a current envelope. Returns envelope, warnings
-- or nil and why.
function TemplateStorage.decode(text)
    if type(text) ~= "string" then
        return nil, "No file text"
    end
    local data, _, problem = json.decode(text)
    if type(data) ~= "table" then
        return nil, "Not a template file (" .. tostring(problem or "not JSON") .. ")"
    end
    local warnings = {}
    local version
    if data.format == TemplateStorage.FORMAT then
        version = tonumber(data.format_version) or 1
    elseif data.template_data or (data.name and data.abilities) then
        version = 0
    else
        return nil, "Not a template file (no template in it)"
    end
    if version > TemplateStorage.FORMAT_VERSION then
        table.insert(warnings, string.format("Saved in a newer format (%d, this game reads %d); unknown fields were ignored",
            version, TemplateStorage.FORMAT_VERSION))
    end
    while version < TemplateStorage.FORMAT_VERSION do
        local step = TemplateStorage.MIGRATIONS[version]
        if not step then
            return nil, "No way to read format version " .. version
        end
        data = step(data)
        version = data.format_version
    end
    if type(data.template) ~= "table" then
        return nil, "Not a template file (no template in it)"
    end
    data.metadata = type(data.metadata) == "table" and data.metadata or {}
    return data, warnings
end
-- }}}

-- {{{ TemplateStorage:entry
function TemplateStorage:entry(name, category)
    local entries = self.index.entries[category]
    return entries and entries[name]
end
-- }}}

-- {{{ TemplateStorage:file_for
-- The file a template of this name goes in: its own if it has one, else
-- a fresh slug, numbered if another name already took it.
function TemplateStorage:file_for(name, category)
    local existing = self:entry(name, category)
    if existing then
        return existing.file
    end
    local taken = {}
    for _, entry in pairs(self.index.entries[category]) do
        taken[entry.file] = true
    end
    local base = TemplateStorage.slug(name)
    local file = base .. TemplateStorage.EXTENSION
    local number = 2
    while taken[file] or self.backend.exists(self:path(category, file)) do
        file = base .. "-" .. number .. TemplateStorage.EXTENSION
        number = number + 1
    end
    return file
end
-- }}}

-- {{{ TemplateStorage:backup
-- Copies a template's current file into backups/, keeping the newest
-- max_backups copies. Returns the backup's path, or nil if there was
-- nothing to copy.
function TemplateStorage:backup(name, category)
    local entry = self:entry(name, category)
    if not entry then
        return nil
    end
    local text = self.backend.read(self:path(category, entry.file))
    if not text then
        return nil
    end
    local list = self.index.backups[category][name] or {}
    self.index.backups[category][name] = list
    local serial = (list[#list] and list[#list].serial or 0) + 1
    local file = entry.file:gsub("%" .. TemplateStorage.EXTENSION .. "$", "") .. "." .. serial .. TemplateStorage.EXTENSION
    local path = self:path("backups", category, file)
    if not self.backend.write(path, text) then
        return nil
    end
    table.insert(list, {serial = serial, file = file, saved_at = self.clock()})
    while #list > self.max_backups do
        local oldest = table.remove(list, 1)
        self.backend.remove(self:path("backups", category, oldest.file))
    end
    return path
end
-- }}}

-- {{{ TemplateStorage:save_template
-- Saves a valid template; an earlier save of the same name is backed up
-- first. Returns true and the file's path, or false and why.
function TemplateStorage:save_template(template, category, metadata)
    category = category or "user"
    if not is_category(category) then
        return false, "Unknown category \"" .. tostring(category) .. "\"; use user, default or imported"
    end
    if not UnitTemplate.is_template(template) then
        template = UnitTemplate.new(template)
    end
    local ok, errors = template:validate()
    if not ok then
        return false, "Template isn't valid: " .. table.concat(errors, "; ")
    end
    local file = self:file_for(template.name, category)
    self:backup(template.name, category)
    local envelope = self:envelope(template, metadata)
    local path = self:path(category, file)
    local written, message = self.backend.write(path, json.encode(envelope, {indent = true}))
    if not written then
        return false, "Couldn't write " .. path .. ": " .. tostring(message)
    end
    self.index.entries[category][template.name] = self:index_entry(template, file, envelope)
    self:save_index()
    return true, path
end
-- }}}

-- {{{ TemplateStorage:index_entry
-- What the index remembers of a template, enough to search without
-- opening its file.
function TemplateStorage:index_entry(template, file, envelope)
    local ability_names = {}
    for index = 1, #template.abilities do
        local config = template:ability_config(index)
        table.insert(ability_names, config and config.name or "?")
    end
    return {
        name = template.name,
        file = file,
        saved_at = envelope.saved_at,
        unit_type = template.unit_type,
        points_used = template.points_used,
        description = envelope.metadata.description or "",
        tags = envelope.metadata.tags or {},
        abilities = ability_names
    }
end
-- }}}

-- {{{ TemplateStorage:read_file
-- Loads a template from a path. Returns template, info {metadata,
-- warnings, saved_at, game_version} or nil and why.
function TemplateStorage:read_file(path)
    local text = self.backend.read(path)
    if not text then
        return nil, "Couldn't read " .. path
    end
    local envelope, warnings = TemplateStorage.decode(text)
    if not envelope then
        return nil, warnings
    end
    local template = UnitTemplate.from_save_data(envelope.template)
    for _, warning in ipairs(template.validation_errors) do
        table.insert(warnings, "No longer valid: " .. warning)
    end
    return template, {
        metadata = envelope.metadata,
        warnings = warnings,
        saved_at = envelope.saved_at,
        game_version = envelope.game_version
    }
end
-- }}}

-- {{{ TemplateStorage:load_template
function TemplateStorage:load_template(name, category)
    category = category or "user"
    local entry = self:entry(name, category)
    if not entry then
        return nil, "No template named \"" .. tostring(name) .. "\" in " .. tostring(category)
    end
    return self:read_file(self:path(category, entry.file))
end
-- }}}

-- {{{ TemplateStorage:list_templates
-- Index entries, by name. With no category, every category's, each
-- entry carrying its category.
function TemplateStorage:list_templates(category)
    local list = {}
    for _, name in ipairs(TemplateStorage.CATEGORIES) do
        if category == nil or category == name then
            for _, entry in pairs(self.index.entries[name]) do
                local copy = {category = name}
                for key, value in pairs(entry) do
                    copy[key] = value
                end
                table.insert(list, copy)
            end
        end
    end
    table.sort(list, function(a, b)
        if a.name ~= b.name then
            return a.name < b.name
        end
        return a.category < b.category
    end)
    return list
end
-- }}}

-- {{{ TemplateStorage:delete_template
-- Backs the template up, then removes it. Returns true, or false and why.
function TemplateStorage:delete_template(name, category)
    category = category or "user"
    local entry = self:entry(name, category)
    if not entry then
        return false, "No template named \"" .. tostring(name) .. "\" in " .. tostring(category)
    end
    self:backup(name, category)
    self.backend.remove(self:path(category, entry.file))
    self.index.entries[category][name] = nil
    self:save_index()
    return true
end
-- }}}

-- {{{ TemplateStorage:list_backups
-- Oldest first: {serial, file, saved_at}.
function TemplateStorage:list_backups(name, category)
    return self.index.backups[category or "user"][name] or {}
end
-- }}}

-- {{{ TemplateStorage:restore_backup
-- Saves a backup (the newest unless serial is given) as the template
-- again; the copy it replaces is backed up in turn. Returns true and the
-- template, or false and why.
function TemplateStorage:restore_backup(name, category, serial)
    category = category or "user"
    local list = self:list_backups(name, category)
    local chosen = list[#list]
    if serial then
        chosen = nil
        for _, backup in ipairs(list) do
            if backup.serial == serial then
                chosen = backup
            end
        end
    end
    if not chosen then
        return false, "No backup of \"" .. tostring(name) .. "\" to restore"
    end
    local template, info = self:read_file(self:path("backups", category, chosen.file))
    if not template then
        return false, info
    end
    local ok, message = self:save_template(template, category, info.metadata)
    if not ok then
        return false, message
    end
    return true, template
end
-- }}}

-- {{{ TemplateStorage:export_template
-- The template's file text, to hand to another player. Returns text or
-- nil and why.
function TemplateStorage:export_template(name, category)
    category = category or "user"
    local entry = self:entry(name, category)
    if not entry then
        return nil, "No template named \"" .. tostring(name) .. "\" in " .. tostring(category)
    end
    return self.backend.read(self:path(category, entry.file))
end
-- }}}

-- {{{ TemplateStorage:import_template
-- Reads exported text and saves it to "imported". A name already used
-- there gets " 2", " 3"... so nothing is overwritten. Returns true,
-- the template and warnings, or false and why.
function TemplateStorage:import_template(text)
    local envelope, warnings = TemplateStorage.decode(text)
    if not envelope then
        return false, warnings
    end
    local data = envelope.template
    local base = tostring(data.name or "Imported")
    local name, number = base, 2
    while self:entry(name, "imported") do
        -- A plain number, since names allow no brackets; the base is
        -- shortened if the name would grow past the length limit.
        local suffix = " " .. number
        name = base:sub(1, 30 - #suffix):gsub("%s+$", "") .. suffix
        number = number + 1
    end
    data.name = name
    local template = UnitTemplate.from_save_data(data)
    local ok, message = self:save_template(template, "imported", envelope.metadata)
    if not ok then
        return false, message
    end
    return true, template, warnings
end
-- }}}

-- {{{ TemplateStorage:rebuild_index
-- Builds the index again from the template files, where the backend can
-- list folders. Backups listed in the old index are kept. Returns how
-- many templates were found, or nil when the backend can't list.
function TemplateStorage:rebuild_index()
    if not self.backend.list then
        return nil
    end
    local old_backups = self.index and self.index.backups
    local index = TemplateStorage.empty_index()
    if old_backups then
        index.backups = old_backups
    end
    local found = 0
    for _, category in ipairs(TemplateStorage.CATEGORIES) do
        for _, file in ipairs(self.backend.list(self:path(category)) or {}) do
            if file:sub(-#TemplateStorage.EXTENSION) == TemplateStorage.EXTENSION then
                local text = self.backend.read(self:path(category, file))
                local envelope = TemplateStorage.decode(text)
                if envelope then
                    local template = UnitTemplate.from_save_data(envelope.template)
                    index.entries[category][template.name] = self:index_entry(template, file, envelope)
                    found = found + 1
                end
            end
        end
    end
    self.index = index
    self:save_index()
    return found
end
-- }}}

return TemplateStorage
-- }}}
