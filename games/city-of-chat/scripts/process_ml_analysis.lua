#!/usr/bin/env lua

-- {{{ process_ml_analysis
-- Lua script for processing ML vision analysis and generating project documentation

-- {{{ string utilities
local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function split(str, delimiter)
    local result = {}
    local pattern = "([^" .. delimiter .. "]+)"
    for match in str:gmatch(pattern) do
        table.insert(result, trim(match))
    end
    return result
end
-- }}}

-- {{{ file utilities
local function read_file(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local content = file:read("*all")
    file:close()
    return content
end

local function write_file(path, content)
    -- Ensure directory exists
    local dir = path:match("(.*)/[^/]*$")
    if dir then
        os.execute("mkdir -p " .. dir)
    end
    
    local file = io.open(path, "w")
    if not file then 
        print("Error: Could not write to " .. path)
        return false 
    end
    file:write(content)
    file:close()
    return true
end

local function file_exists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end
-- }}}

-- {{{ parse_ml_analysis
local function parse_ml_analysis(analysis_text)
    local analysis = {
        scene_contents = {},
        actions_attributes = {},
        scene_description = "",
        game_design_purpose = "",
        technical_details = {},
        raw_text = analysis_text
    }
    
    local current_section = nil
    local lines = split(analysis_text, "\n")
    
    for _, line in ipairs(lines) do
        line = trim(line)
        if line ~= "" then
            if line:match("^SCENE CONTENTS:") then
                current_section = "scene_contents"
            elseif line:match("^ACTIONS & ATTRIBUTES:") then
                current_section = "actions_attributes"
            elseif line:match("^SCENE DESCRIPTION:") then
                current_section = "scene_description"
            elseif line:match("^GAME DESIGN PURPOSE:") then
                current_section = "game_design_purpose"
            elseif line:match("^TECHNICAL DETAILS:") then
                current_section = "technical_details"
            elseif current_section then
                if current_section == "scene_contents" or 
                   current_section == "actions_attributes" or
                   current_section == "technical_details" then
                    table.insert(analysis[current_section], line)
                elseif current_section == "scene_description" or
                       current_section == "game_design_purpose" then
                    if analysis[current_section] == "" then
                        analysis[current_section] = line
                    else
                        analysis[current_section] = analysis[current_section] .. " " .. line
                    end
                end
            end
        end
    end
    
    return analysis
end
-- }}}

-- {{{ generate_feature_ideas
local function generate_feature_ideas(analysis, image_filename)
    local ideas = {}
    local base_name = image_filename:match("([^/]+)%.%w+$") or image_filename
    
    -- Extract potential features from filename and analysis
    if base_name:match("coh") then
        table.insert(ideas, {
            type = "gameplay_mechanic",
            title = "City of Heroes Enhancement: " .. base_name:gsub("-", " "),
            description = "Implement feature based on design concept: " .. (analysis.game_design_purpose or "game enhancement")
        })
    end
    
    if base_name:match("ui") or base_name:match("UI") then
        table.insert(ideas, {
            type = "user_interface",
            title = "UI Component: " .. base_name:gsub("-", " "),
            description = "Create user interface element described in design document"
        })
    end
    
    if base_name:match("legion") then
        table.insert(ideas, {
            type = "game_mode",
            title = "Legion TD Inspired Feature: " .. base_name:gsub("-", " "),
            description = "Adapt Legion TD mechanics for City of Heroes private server"
        })
    end
    
    -- Generic feature extraction
    for _, content in ipairs(analysis.scene_contents) do
        if content:match("interface") or content:match("menu") or content:match("button") then
            table.insert(ideas, {
                type = "interface_enhancement",
                title = "Interface Enhancement from " .. base_name,
                description = "Implement interface improvements based on visual analysis"
            })
            break
        end
    end
    
    return ideas
end
-- }}}

-- {{{ generate_issue_document
local function generate_issue_document(analysis, image_filename, feature_idea, issue_id)
    local base_name = image_filename:match("([^/]+)%.%w+$") or image_filename
    local clean_name = base_name:gsub("[^%w%-]", "-"):lower()
    
    local template = string.format([[# Issue %03d: %s

## Current Behavior
No implementation exists for the feature concept described in %s.

## Intended Behavior
Implement the game feature or enhancement as conceptualized in the design document.

### Feature Analysis
**Design Purpose**: %s

**Visual Elements Identified**:
%s

**Technical Considerations**:
%s

## Suggested Implementation Steps
1. Analyze the design concept in detail
2. Identify required server-side modifications
3. Design database schema changes (if needed)
4. Implement core functionality in C++
5. Create or modify client interface elements
6. Test feature integration with existing systems
7. Document configuration options and usage

## Metadata
- **Priority**: Medium
- **Estimated Effort**: 8-16 hours
- **Dependencies**: Phase 1 completion (server setup)
- **Tags**: feature-implementation, design-driven, %s
- **Source Image**: %s

## Related Documents
- docs/design-analysis/%s-analysis.md
- pics/%s
- pics/%s-notes.txt

## Implementation Notes
This feature is derived from visual design analysis. Implementation should maintain
the spirit and intent of the original design while adapting to the City of Heroes
server architecture and existing gameplay systems.

## Tools
- C++ compiler and development environment
- Database administration tools
- Game client modification tools
- Image analysis and design tools]], 
    issue_id,
    feature_idea.title,
    image_filename,
    analysis.game_design_purpose or "Game enhancement concept",
    table.concat(analysis.scene_contents, "\n"),
    table.concat(analysis.technical_details, "\n"),
    feature_idea.type,
    image_filename,
    clean_name,
    base_name,
    base_name
    )
    
    return template
end
-- }}}

-- {{{ generate_design_analysis_doc
local function generate_design_analysis_doc(analysis, image_filename)
    local base_name = image_filename:match("([^/]+)%.%w+$") or image_filename
    local clean_name = base_name:gsub("[^%w%-]", "-"):lower()
    
    local template = string.format([[# Design Analysis: %s

## Image Information
- **Filename**: %s
- **Analysis Date**: %s
- **Analysis Method**: ML Vision Processing

## Visual Analysis Results

### Scene Contents
%s

### Actions and Attributes
%s

### Scene Description
%s

### Game Design Purpose
%s

### Technical Details
%s

## Implementation Recommendations

### Priority Assessment
Based on the visual analysis, this design concept should be prioritized according to:
- **Complexity**: Determined by technical elements identified
- **Impact**: Based on game design purpose and scope
- **Feasibility**: Considering City of Heroes server architecture

### Development Approach
1. **Research Phase**: Study existing City of Heroes systems that relate to this concept
2. **Design Phase**: Create detailed technical specifications
3. **Implementation Phase**: Develop according to server modification best practices
4. **Testing Phase**: Validate against design intent and server stability

### Integration Considerations
- Server performance impact assessment
- Client compatibility requirements
- Database schema modifications
- Configuration and administration needs

## Related Concepts
This design analysis may inform development of related features and systems.
Consider cross-referencing with other design documents for synergistic opportunities.

## Future Enhancements
Document potential extensions or variations of this concept for future development phases.

---
*Generated by ML vision analysis system*]], 
    base_name,
    image_filename,
    os.date("%Y-%m-%d %H:%M:%S"),
    table.concat(analysis.scene_contents, "\n- "),
    table.concat(analysis.actions_attributes, "\n- "),
    analysis.scene_description,
    analysis.game_design_purpose,
    table.concat(analysis.technical_details, "\n- ")
    )
    
    return template
end
-- }}}

-- {{{ get_next_issue_id
local function get_next_issue_id(base_dir)
    local max_id = 0
    local handle = io.popen("find " .. base_dir .. "/issues -name '[0-9]*-*' 2>/dev/null | head -20")
    
    if handle then
        for line in handle:lines() do
            local id = line:match("/(%d+)%-")
            if id then
                local num = tonumber(id)
                if num and num > max_id then
                    max_id = num
                end
            end
        end
        handle:close()
    end
    
    return max_id + 1
end
-- }}}

-- {{{ process_image_analysis
local function process_image_analysis(image_path, analysis_text, base_dir)
    if not analysis_text or analysis_text == "" then
        print("Error: No analysis text provided")
        return false
    end
    
    local analysis = parse_ml_analysis(analysis_text)
    local image_filename = image_path:match("([^/]+)$")
    local base_name = image_filename:match("([^%.]+)") or image_filename
    local clean_name = base_name:gsub("[^%w%-]", "-"):lower()
    
    print("Processing analysis for: " .. image_filename)
    
    -- Generate design analysis document
    local design_doc = generate_design_analysis_doc(analysis, image_filename)
    local design_doc_path = base_dir .. "/docs/design-analysis/" .. clean_name .. "-analysis.md"
    
    if write_file(design_doc_path, design_doc) then
        print("Created design analysis: " .. design_doc_path)
    end
    
    -- Generate feature ideas and issues
    local feature_ideas = generate_feature_ideas(analysis, image_filename)
    
    for _, idea in ipairs(feature_ideas) do
        local issue_id = get_next_issue_id(base_dir)
        local issue_doc = generate_issue_document(analysis, image_filename, idea, issue_id)
        local issue_path = string.format("%s/issues/design-driven/%03d-%s", 
                                       base_dir, issue_id, clean_name)
        
        if write_file(issue_path, issue_doc) then
            print(string.format("Created issue %03d: %s", issue_id, issue_path))
        end
    end
    
    return true
end
-- }}}

-- {{{ main
local function main(args)
    if #args < 3 then
        print("Usage: lua process_ml_analysis.lua <image_path> <analysis_text_file> <base_dir>")
        print("  or: lua process_ml_analysis.lua -I")
        os.exit(1)
    end
    
    if args[1] == "-I" then
        -- Interactive mode
        print("=== ML Analysis Processing Tool ===")
        print("Enter image path:")
        local image_path = io.read()
        print("Enter analysis text file path:")
        local analysis_file = io.read()
        print("Enter base directory (default: current):")
        local base_dir = io.read()
        if base_dir == "" then base_dir = "." end
        
        local analysis_text = read_file(analysis_file)
        if analysis_text then
            process_image_analysis(image_path, analysis_text, base_dir)
        else
            print("Error: Could not read analysis file")
        end
    else
        local image_path = args[1]
        local analysis_file = args[2]
        local base_dir = args[3]
        
        local analysis_text = read_file(analysis_file)
        if analysis_text then
            process_image_analysis(image_path, analysis_text, base_dir)
        else
            print("Error: Could not read analysis file: " .. analysis_file)
            os.exit(1)
        end
    end
end

-- Execute main function
main(arg)
-- }}}