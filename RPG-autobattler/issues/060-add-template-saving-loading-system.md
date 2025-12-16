# Issue #504: Add Template Saving/Loading System

## Current Behavior
Unit templates exist only in memory and are lost when the game closes.

## Intended Behavior
Implement persistent storage system for unit templates with version management, import/export capabilities, and user-friendly organization.

## Implementation Details

### Template Storage Manager (src/storage/template_storage.lua)
```lua
-- {{{ TemplateStorage
local TemplateStorage = {}
TemplateStorage.__index = TemplateStorage

function TemplateStorage:new(storage_path)
    local storage = {
        storage_path = storage_path or "templates/",
        file_extension = ".template",
        index_file = "template_index.json",
        templates_cache = {},
        metadata_cache = {},
        last_scan_time = 0
    }
    
    storage:ensure_directories_exist()
    setmetatable(storage, self)
    return storage
end
-- }}}

-- {{{ function TemplateStorage:ensure_directories_exist
function TemplateStorage:ensure_directories_exist()
    local success, error_msg = love.filesystem.createDirectory(self.storage_path)
    if not success then
        print("Warning: Could not create template directory:", error_msg)
    end
    
    -- Create subdirectories for organization
    love.filesystem.createDirectory(self.storage_path .. "user/")
    love.filesystem.createDirectory(self.storage_path .. "default/")
    love.filesystem.createDirectory(self.storage_path .. "imported/")
    love.filesystem.createDirectory(self.storage_path .. "backups/")
end
-- }}}

-- {{{ function TemplateStorage:save_template
function TemplateStorage:save_template(template, category)
    category = category or "user"
    
    -- Validate template before saving
    local UnitTemplate = require("src.data.unit_template")
    if not template.is_valid then
        return false, "Template failed validation"
    end
    
    -- Generate filename
    local filename = self:generate_filename(template.name, category)
    local full_path = self.storage_path .. category .. "/" .. filename
    
    -- Create save data
    local save_data = {
        template_version = 1,
        game_version = "0.1.0", -- TODO: Get from config
        timestamp = os.time(),
        template_data = template:to_save_data(),
        metadata = {
            author = template.created_by,
            description = template.description,
            tags = template.tags or {},
            favorite = false,
            usage_count = 0
        }
    }
    
    -- Save to file
    local json_data = self:encode_json(save_data)
    local success = love.filesystem.write(full_path, json_data)
    
    if success then
        self:update_index(template.name, category, filename)
        self.templates_cache[template.name] = template
        return true, full_path
    else
        return false, "Failed to write template file"
    end
end
-- }}}

-- {{{ function TemplateStorage:load_template
function TemplateStorage:load_template(template_name, category)
    category = category or "user"
    
    -- Check cache first
    local cache_key = category .. "/" .. template_name
    if self.templates_cache[cache_key] then
        return self.templates_cache[cache_key], nil
    end
    
    -- Find template file
    local filename = self:find_template_file(template_name, category)
    if not filename then
        return nil, "Template not found: " .. template_name
    end
    
    local full_path = self.storage_path .. category .. "/" .. filename
    
    -- Read and parse file
    local file_data = love.filesystem.read(full_path)
    if not file_data then
        return nil, "Could not read template file"
    end
    
    local save_data = self:decode_json(file_data)
    if not save_data or not save_data.template_data then
        return nil, "Invalid template file format"
    end
    
    -- Create template object
    local UnitTemplate = require("src.data.unit_template")
    local template = UnitTemplate.from_save_data(save_data.template_data)
    
    if not template then
        return nil, "Failed to create template from save data"
    end
    
    -- Update metadata
    if save_data.metadata then
        template.metadata = save_data.metadata
        template.metadata.usage_count = (template.metadata.usage_count or 0) + 1
        
        -- Save updated usage count
        save_data.metadata = template.metadata
        local updated_json = self:encode_json(save_data)
        love.filesystem.write(full_path, updated_json)
    end
    
    -- Cache template
    self.templates_cache[cache_key] = template
    
    return template, nil
end
-- }}}

-- {{{ function TemplateStorage:get_all_templates
function TemplateStorage:get_all_templates(category)
    local templates = {}
    local search_categories = category and {category} or {"user", "default", "imported"}
    
    for _, cat in ipairs(search_categories) do
        local category_path = self.storage_path .. cat .. "/"
        local files = love.filesystem.getDirectoryItems(category_path)
        
        for _, file in ipairs(files) do
            if string.match(file, self.file_extension .. "$") then
                local template_name = self:extract_template_name(file)
                local template, error_msg = self:load_template(template_name, cat)
                
                if template then
                    table.insert(templates, {
                        template = template,
                        category = cat,
                        filename = file
                    })
                else
                    print("Warning: Could not load template", file, error_msg)
                end
            end
        end
    end
    
    return templates
end
-- }}}

-- {{{ function TemplateStorage:delete_template
function TemplateStorage:delete_template(template_name, category)
    category = category or "user"
    
    -- Don't allow deletion of default templates
    if category == "default" then
        return false, "Cannot delete default templates"
    end
    
    local filename = self:find_template_file(template_name, category)
    if not filename then
        return false, "Template not found"
    end
    
    local full_path = self.storage_path .. category .. "/" .. filename
    
    -- Create backup before deletion
    self:backup_template(template_name, category)
    
    -- Delete file
    local success = love.filesystem.remove(full_path)
    
    if success then
        self:remove_from_index(template_name, category)
        local cache_key = category .. "/" .. template_name
        self.templates_cache[cache_key] = nil
        return true
    else
        return false, "Failed to delete template file"
    end
end
-- }}}

-- {{{ function TemplateStorage:backup_template
function TemplateStorage:backup_template(template_name, category)
    local filename = self:find_template_file(template_name, category)
    if not filename then return false end
    
    local source_path = self.storage_path .. category .. "/" .. filename
    local backup_filename = string.format("%s_%s_%d.backup", 
                                         template_name, category, os.time())
    local backup_path = self.storage_path .. "backups/" .. backup_filename
    
    local data = love.filesystem.read(source_path)
    if data then
        return love.filesystem.write(backup_path, data)
    end
    
    return false
end
-- }}}

-- {{{ function TemplateStorage:export_template
function TemplateStorage:export_template(template_name, category, export_path)
    local template, error_msg = self:load_template(template_name, category)
    if not template then
        return false, error_msg
    end
    
    -- Create export data with additional metadata
    local export_data = {
        export_version = 1,
        export_timestamp = os.time(),
        game_version = "0.1.0",
        template = template:to_save_data(),
        metadata = template.metadata or {}
    }
    
    local json_data = self:encode_json(export_data)
    local success = love.filesystem.write(export_path, json_data)
    
    return success, success and export_path or "Failed to export template"
end
-- }}}

-- {{{ function TemplateStorage:import_template
function TemplateStorage:import_template(import_path, target_category)
    target_category = target_category or "imported"
    
    -- Read import file
    local file_data = love.filesystem.read(import_path)
    if not file_data then
        return false, "Could not read import file"
    end
    
    local import_data = self:decode_json(file_data)
    if not import_data or not import_data.template then
        return false, "Invalid import file format"
    end
    
    -- Create template object
    local UnitTemplate = require("src.data.unit_template")
    local template = UnitTemplate.from_save_data(import_data.template)
    
    if not template then
        return false, "Failed to create template from import data"
    end
    
    -- Check for conflicts
    local existing_template, _ = self:load_template(template.name, target_category)
    if existing_template then
        template.name = template.name .. "_imported"
    end
    
    -- Import metadata
    if import_data.metadata then
        template.metadata = import_data.metadata
        template.metadata.imported_from = import_path
        template.metadata.import_timestamp = os.time()
    end
    
    -- Save imported template
    local success, save_path = self:save_template(template, target_category)
    
    return success, success and template.name or save_path
end
-- }}}

-- {{{ function TemplateStorage:generate_filename
function TemplateStorage:generate_filename(template_name, category)
    -- Sanitize name for filesystem
    local safe_name = string.gsub(template_name, "[^%w%-_]", "_")
    safe_name = string.lower(safe_name)
    
    local filename = safe_name .. self.file_extension
    
    -- Ensure uniqueness
    local counter = 1
    local full_path = self.storage_path .. category .. "/" .. filename
    
    while love.filesystem.getInfo(full_path) do
        filename = string.format("%s_%d%s", safe_name, counter, self.file_extension)
        full_path = self.storage_path .. category .. "/" .. filename
        counter = counter + 1
    end
    
    return filename
end
-- }}}

-- {{{ function TemplateStorage:find_template_file
function TemplateStorage:find_template_file(template_name, category)
    local category_path = self.storage_path .. category .. "/"
    local files = love.filesystem.getDirectoryItems(category_path)
    
    for _, file in ipairs(files) do
        if string.match(file, self.file_extension .. "$") then
            local file_template_name = self:extract_template_name_from_file(category_path .. file)
            if file_template_name == template_name then
                return file
            end
        end
    end
    
    return nil
end
-- }}}

-- {{{ function TemplateStorage:extract_template_name_from_file
function TemplateStorage:extract_template_name_from_file(file_path)
    local file_data = love.filesystem.read(file_path)
    if not file_data then return nil end
    
    local save_data = self:decode_json(file_data)
    if save_data and save_data.template_data and save_data.template_data.name then
        return save_data.template_data.name
    end
    
    return nil
end
-- }}}

-- {{{ function TemplateStorage:extract_template_name
function TemplateStorage:extract_template_name(filename)
    return string.gsub(filename, self.file_extension .. "$", "")
end
-- }}}

-- {{{ function TemplateStorage:update_index
function TemplateStorage:update_index(template_name, category, filename)
    local index = self:load_index()
    
    if not index[category] then
        index[category] = {}
    end
    
    index[category][template_name] = {
        filename = filename,
        last_modified = os.time()
    }
    
    self:save_index(index)
end
-- }}}

-- {{{ function TemplateStorage:remove_from_index
function TemplateStorage:remove_from_index(template_name, category)
    local index = self:load_index()
    
    if index[category] then
        index[category][template_name] = nil
    end
    
    self:save_index(index)
end
-- }}}

-- {{{ function TemplateStorage:load_index
function TemplateStorage:load_index()
    local index_path = self.storage_path .. self.index_file
    local file_data = love.filesystem.read(index_path)
    
    if file_data then
        local index = self:decode_json(file_data)
        return index or {}
    end
    
    return {}
end
-- }}}

-- {{{ function TemplateStorage:save_index
function TemplateStorage:save_index(index)
    local index_path = self.storage_path .. self.index_file
    local json_data = self:encode_json(index)
    love.filesystem.write(index_path, json_data)
end
-- }}}

-- {{{ function TemplateStorage:encode_json
function TemplateStorage:encode_json(data)
    -- Simple JSON encoder - in production would use proper JSON library
    local json = require("lib.json") -- Assuming json library exists
    return json.encode(data)
end
-- }}}

-- {{{ function TemplateStorage:decode_json
function TemplateStorage:decode_json(json_string)
    -- Simple JSON decoder - in production would use proper JSON library
    local json = require("lib.json") -- Assuming json library exists
    local success, result = pcall(json.decode, json_string)
    return success and result or nil
end
-- }}}

return TemplateStorage
```

### Template Library System (src/systems/template_library.lua)
```lua
-- {{{ TemplateLibrary
local TemplateLibrary = {}
TemplateLibrary.__index = TemplateLibrary

function TemplateLibrary:new()
    local library = {
        storage = require("src.storage.template_storage"):new(),
        favorites = {},
        recent_templates = {},
        search_index = {},
        tags = {}
    }
    
    library:load_user_preferences()
    setmetatable(library, self)
    return library
end
-- }}}

-- {{{ function TemplateLibrary:search_templates
function TemplateLibrary:search_templates(query, filters)
    local all_templates = self.storage:get_all_templates()
    local results = {}
    
    query = string.lower(query or "")
    filters = filters or {}
    
    for _, template_info in ipairs(all_templates) do
        local template = template_info.template
        local matches = self:template_matches_search(template, query, filters)
        
        if matches then
            table.insert(results, {
                template = template,
                category = template_info.category,
                relevance = self:calculate_relevance(template, query)
            })
        end
    end
    
    -- Sort by relevance
    table.sort(results, function(a, b) return a.relevance > b.relevance end)
    
    return results
end
-- }}}

-- {{{ function TemplateLibrary:template_matches_search
function TemplateLibrary:template_matches_search(template, query, filters)
    -- Text search
    if query and query ~= "" then
        local searchable_text = string.lower(template.name .. " " .. (template.description or ""))
        if not string.find(searchable_text, query) then
            return false
        end
    end
    
    -- Filter by unit type
    if filters.unit_type and template.stats.unit_type ~= filters.unit_type then
        return false
    end
    
    -- Filter by point range
    if filters.min_points and template.points_used < filters.min_points then
        return false
    end
    if filters.max_points and template.points_used > filters.max_points then
        return false
    end
    
    -- Filter by ability count
    if filters.ability_count and #template.abilities ~= filters.ability_count then
        return false
    end
    
    -- Filter by tags
    if filters.tags and template.metadata and template.metadata.tags then
        for _, required_tag in ipairs(filters.tags) do
            local has_tag = false
            for _, template_tag in ipairs(template.metadata.tags) do
                if template_tag == required_tag then
                    has_tag = true
                    break
                end
            end
            if not has_tag then
                return false
            end
        end
    end
    
    return true
end
-- }}}

-- {{{ function TemplateLibrary:calculate_relevance
function TemplateLibrary:calculate_relevance(template, query)
    local relevance = 0
    
    if query and query ~= "" then
        -- Exact name match gets highest score
        if string.lower(template.name) == query then
            relevance = relevance + 100
        elseif string.find(string.lower(template.name), query, 1, true) then
            relevance = relevance + 50
        end
        
        -- Description matches
        if template.description and string.find(string.lower(template.description), query, 1, true) then
            relevance = relevance + 25
        end
    end
    
    -- Boost for favorites
    if self:is_favorite(template.name) then
        relevance = relevance + 20
    end
    
    -- Boost for recently used
    if self:is_recent(template.name) then
        relevance = relevance + 10
    end
    
    -- Boost for usage count
    if template.metadata and template.metadata.usage_count then
        relevance = relevance + math.min(template.metadata.usage_count, 10)
    end
    
    return relevance
end
-- }}}

-- {{{ function TemplateLibrary:add_to_favorites
function TemplateLibrary:add_to_favorites(template_name)
    if not self:is_favorite(template_name) then
        table.insert(self.favorites, template_name)
        self:save_user_preferences()
    end
end
-- }}}

-- {{{ function TemplateLibrary:remove_from_favorites
function TemplateLibrary:remove_from_favorites(template_name)
    for i, fav_name in ipairs(self.favorites) do
        if fav_name == template_name then
            table.remove(self.favorites, i)
            self:save_user_preferences()
            break
        end
    end
end
-- }}}

-- {{{ function TemplateLibrary:is_favorite
function TemplateLibrary:is_favorite(template_name)
    for _, fav_name in ipairs(self.favorites) do
        if fav_name == template_name then
            return true
        end
    end
    return false
end
-- }}}

-- {{{ function TemplateLibrary:add_to_recent
function TemplateLibrary:add_to_recent(template_name)
    -- Remove if already in recent list
    for i, recent_name in ipairs(self.recent_templates) do
        if recent_name == template_name then
            table.remove(self.recent_templates, i)
            break
        end
    end
    
    -- Add to front
    table.insert(self.recent_templates, 1, template_name)
    
    -- Limit to 10 recent templates
    while #self.recent_templates > 10 do
        table.remove(self.recent_templates)
    end
    
    self:save_user_preferences()
end
-- }}}

-- {{{ function TemplateLibrary:is_recent
function TemplateLibrary:is_recent(template_name)
    for _, recent_name in ipairs(self.recent_templates) do
        if recent_name == template_name then
            return true
        end
    end
    return false
end
-- }}}

-- {{{ function TemplateLibrary:load_user_preferences
function TemplateLibrary:load_user_preferences()
    local prefs_path = "user_preferences.json"
    local file_data = love.filesystem.read(prefs_path)
    
    if file_data then
        local prefs = self:decode_json(file_data)
        if prefs then
            self.favorites = prefs.favorites or {}
            self.recent_templates = prefs.recent_templates or {}
            self.tags = prefs.tags or {}
        end
    end
end
-- }}}

-- {{{ function TemplateLibrary:save_user_preferences
function TemplateLibrary:save_user_preferences()
    local prefs = {
        favorites = self.favorites,
        recent_templates = self.recent_templates,
        tags = self.tags
    }
    
    local json_data = self:encode_json(prefs)
    love.filesystem.write("user_preferences.json", json_data)
end
-- }}}

return TemplateLibrary
```

### Acceptance Criteria
- [ ] Templates can be saved and loaded reliably
- [ ] Template organization by categories (user/default/imported)
- [ ] Import/export functionality works correctly
- [ ] Search and filtering system finds relevant templates
- [ ] Favorites and recent templates tracked
- [ ] Automatic backups prevent data loss
- [ ] File format is forward/backward compatible