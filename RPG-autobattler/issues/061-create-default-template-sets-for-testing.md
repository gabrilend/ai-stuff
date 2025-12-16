# Issue #505: Create Default Template Sets for Testing

## Current Behavior
No default unit templates exist for testing and demonstration purposes.

## Intended Behavior
Provide a comprehensive set of well-balanced default templates that showcase different strategies, serve as examples for players, and enable immediate gameplay testing.

## Implementation Details

### Default Template Factory (src/factories/default_template_factory.lua)
```lua
-- {{{ DefaultTemplateFactory
local DefaultTemplateFactory = {}
DefaultTemplateFactory.__index = DefaultTemplateFactory

function DefaultTemplateFactory:new()
    local factory = {
        UnitTemplate = require("src.data.unit_template"),
        template_sets = {},
        current_version = 1
    }
    setmetatable(factory, self)
    return factory
end
-- }}}

-- {{{ function DefaultTemplateFactory:create_all_default_templates
function DefaultTemplateFactory:create_all_default_templates()
    local templates = {}
    
    -- Create basic template sets
    local basic_templates = self:create_basic_template_set()
    local advanced_templates = self:create_advanced_template_set()
    local specialist_templates = self:create_specialist_template_set()
    local experimental_templates = self:create_experimental_template_set()
    
    -- Combine all sets
    for _, template in ipairs(basic_templates) do
        table.insert(templates, template)
    end
    for _, template in ipairs(advanced_templates) do
        table.insert(templates, template)
    end
    for _, template in ipairs(specialist_templates) do
        table.insert(templates, template)
    end
    for _, template in ipairs(experimental_templates) do
        table.insert(templates, template)
    end
    
    return templates
end
-- }}}

-- {{{ function DefaultTemplateFactory:create_basic_template_set
function DefaultTemplateFactory:create_basic_template_set()
    local templates = {}
    
    -- Basic Warrior
    table.insert(templates, self.UnitTemplate:new({
        name = "Basic Warrior",
        description = "A straightforward melee fighter with balanced stats and a simple attack.",
        created_by = "Default",
        point_budget = 100,
        stats = {
            health = 150,
            speed = 40,
            armor = 2,
            detection_range = 50,
            unit_type = "melee"
        },
        abilities = {
            {
                name = "Sword Strike",
                effect_type = "damage",
                target_type = "enemy",
                base_value = 35,
                range = 25,
                max_mana = 100,
                mana_rate = 10
            }
        },
        appearance = {
            primary_color = {0.8, 0.2, 0.2},
            secondary_color = {0.6, 0.1, 0.1},
            shape = "square",
            size_modifier = 1.0
        }
    }))
    
    -- Basic Archer
    table.insert(templates, self.UnitTemplate:new({
        name = "Basic Archer",
        description = "A ranged unit that deals damage from a safe distance.",
        created_by = "Default",
        point_budget = 100,
        stats = {
            health = 80,
            speed = 60,
            armor = 0,
            detection_range = 100,
            unit_type = "ranged"
        },
        abilities = {
            {
                name = "Bow Shot",
                effect_type = "damage",
                target_type = "enemy",
                base_value = 30,
                range = 80,
                max_mana = 100,
                mana_rate = 10
            }
        },
        appearance = {
            primary_color = {0.2, 0.8, 0.2},
            secondary_color = {0.1, 0.6, 0.1},
            shape = "triangle",
            size_modifier = 0.9
        }
    }))
    
    -- Basic Guardian
    table.insert(templates, self.UnitTemplate:new({
        name = "Basic Guardian",
        description = "A tanky unit focused on absorbing damage and protecting allies.",
        created_by = "Default",
        point_budget = 100,
        stats = {
            health = 200,
            speed = 30,
            armor = 5,
            detection_range = 40,
            unit_type = "melee"
        },
        abilities = {
            {
                name = "Shield Bash",
                effect_type = "damage",
                target_type = "enemy",
                base_value = 20,
                range = 25,
                max_mana = 100,
                mana_rate = 8
            }
        },
        appearance = {
            primary_color = {0.2, 0.2, 0.8},
            secondary_color = {0.1, 0.1, 0.6},
            shape = "hexagon",
            size_modifier = 1.2
        }
    }))
    
    -- Basic Support
    table.insert(templates, self.UnitTemplate:new({
        name = "Basic Healer",
        description = "A support unit that heals damaged allies.",
        created_by = "Default",
        point_budget = 100,
        stats = {
            health = 70,
            speed = 50,
            armor = 1,
            detection_range = 70,
            unit_type = "ranged"
        },
        abilities = {
            {
                name = "Minor Heal",
                effect_type = "heal",
                target_type = "ally",
                base_value = 40,
                range = 60,
                max_mana = 100,
                mana_rate = 8
            }
        },
        appearance = {
            primary_color = {0.8, 0.8, 0.2},
            secondary_color = {0.6, 0.6, 0.1},
            shape = "circle",
            size_modifier = 0.8
        }
    }))
    
    return templates
end
-- }}}

-- {{{ function DefaultTemplateFactory:create_advanced_template_set
function DefaultTemplateFactory:create_advanced_template_set()
    local templates = {}
    
    -- Heavy Knight
    table.insert(templates, self.UnitTemplate:new({
        name = "Heavy Knight",
        description = "An armored warrior with high survivability and dual abilities.",
        created_by = "Default",
        point_budget = 100,
        stats = {
            health = 180,
            speed = 35,
            armor = 8,
            detection_range = 45,
            unit_type = "melee"
        },
        abilities = {
            {
                name = "Heavy Strike",
                effect_type = "damage",
                target_type = "enemy",
                base_value = 40,
                range = 25,
                max_mana = 100,
                mana_rate = 10
            },
            {
                name = "Armor Break",
                effect_type = "debuff",
                target_type = "enemy",
                base_value = 3,
                range = 25,
                max_mana = 150,
                mana_rate = 5,
                duration = 10
            }
        },
        appearance = {
            primary_color = {0.7, 0.3, 0.7},
            secondary_color = {0.5, 0.2, 0.5},
            shape = "square",
            size_modifier = 1.1
        }
    }))
    
    -- Sniper
    table.insert(templates, self.UnitTemplate:new({
        name = "Sniper",
        description = "Long-range specialist with piercing shots and high damage.",
        created_by = "Default",
        point_budget = 100,
        stats = {
            health = 60,
            speed = 45,
            armor = 0,
            detection_range = 120,
            unit_type = "ranged"
        },
        abilities = {
            {
                name = "Piercing Shot",
                effect_type = "damage",
                target_type = "enemy",
                base_value = 50,
                range = 120,
                max_mana = 100,
                mana_rate = 10,
                piercing = true
            }
        },
        appearance = {
            primary_color = {0.3, 0.7, 0.3},
            secondary_color = {0.2, 0.5, 0.2},
            shape = "triangle",
            size_modifier = 0.7
        }
    }))
    
    -- Battle Cleric
    table.insert(templates, self.UnitTemplate:new({
        name = "Battle Cleric",
        description = "Hybrid unit capable of both healing allies and fighting enemies.",
        created_by = "Default",
        point_budget = 100,
        stats = {
            health = 120,
            speed = 45,
            armor = 3,
            detection_range = 60,
            unit_type = "melee"
        },
        abilities = {
            {
                name = "Holy Strike",
                effect_type = "damage",
                target_type = "enemy",
                base_value = 28,
                range = 25,
                max_mana = 100,
                mana_rate = 10
            },
            {
                name = "Healing Light",
                effect_type = "heal",
                target_type = "ally",
                base_value = 35,
                range = 50,
                max_mana = 120,
                mana_rate = 6
            }
        },
        appearance = {
            primary_color = {0.9, 0.7, 0.2},
            secondary_color = {0.7, 0.5, 0.1},
            shape = "octagon",
            size_modifier = 1.0
        }
    }))
    
    return templates
end
-- }}}

-- {{{ function DefaultTemplateFactory:create_specialist_template_set
function DefaultTemplateFactory:create_specialist_template_set()
    local templates = {}
    
    -- Berserker
    table.insert(templates, self.UnitTemplate:new({
        name = "Berserker",
        description = "High-damage, low-defense unit with rage abilities.",
        created_by = "Default",
        point_budget = 100,
        stats = {
            health = 90,
            speed = 65,
            armor = 0,
            detection_range = 55,
            unit_type = "melee"
        },
        abilities = {
            {
                name = "Rage Strike",
                effect_type = "damage",
                target_type = "enemy",
                base_value = 55,
                range = 25,
                max_mana = 100,
                mana_rate = 12
            },
            {
                name = "Berserk",
                effect_type = "buff",
                target_type = "self",
                base_value = 25,
                range = 0,
                max_mana = 200,
                mana_rate = 4,
                duration = 8
            }
        },
        appearance = {
            primary_color = {1.0, 0.1, 0.1},
            secondary_color = {0.8, 0.0, 0.0},
            shape = "diamond",
            size_modifier = 0.9
        }
    }))
    
    -- Assassin
    table.insert(templates, self.UnitTemplate:new({
        name = "Assassin",
        description = "Fast, fragile unit with high burst damage potential.",
        created_by = "Default",
        point_budget = 100,
        stats = {
            health = 65,
            speed = 85,
            armor = 0,
            detection_range = 45,
            unit_type = "melee"
        },
        abilities = {
            {
                name = "Backstab",
                effect_type = "damage",
                target_type = "enemy",
                base_value = 65,
                range = 20,
                max_mana = 100,
                mana_rate = 8,
                conditional_bonus = "rear_attack"
            }
        },
        appearance = {
            primary_color = {0.2, 0.2, 0.2},
            secondary_color = {0.4, 0.4, 0.4},
            shape = "triangle",
            size_modifier = 0.7
        }
    }))
    
    -- Crowd Controller
    table.insert(templates, self.UnitTemplate:new({
        name = "Frost Mage",
        description = "Area effect specialist that slows and damages multiple enemies.",
        created_by = "Default",
        point_budget = 100,
        stats = {
            health = 75,
            speed = 40,
            armor = 1,
            detection_range = 90,
            unit_type = "ranged"
        },
        abilities = {
            {
                name = "Ice Bolt",
                effect_type = "damage",
                target_type = "enemy",
                base_value = 25,
                range = 70,
                max_mana = 100,
                mana_rate = 10
            },
            {
                name = "Frost Nova",
                effect_type = "damage",
                target_type = "enemy",
                base_value = 15,
                range = 60,
                max_mana = 180,
                mana_rate = 4,
                area_radius = 25,
                status_effect = "slow"
            }
        },
        appearance = {
            primary_color = {0.2, 0.6, 0.9},
            secondary_color = {0.1, 0.4, 0.7},
            shape = "star",
            size_modifier = 0.9
        }
    }))
    
    return templates
end
-- }}}

-- {{{ function DefaultTemplateFactory:create_experimental_template_set
function DefaultTemplateFactory:create_experimental_template_set()
    local templates = {}
    
    -- Glass Cannon
    table.insert(templates, self.UnitTemplate:new({
        name = "Glass Cannon",
        description = "Extreme damage output but extremely fragile.",
        created_by = "Default",
        point_budget = 100,
        stats = {
            health = 45,
            speed = 55,
            armor = 0,
            detection_range = 85,
            unit_type = "ranged"
        },
        abilities = {
            {
                name = "Devastation",
                effect_type = "damage",
                target_type = "enemy",
                base_value = 80,
                range = 90,
                max_mana = 100,
                mana_rate = 10
            }
        },
        appearance = {
            primary_color = {1.0, 0.3, 0.0},
            secondary_color = {0.8, 0.2, 0.0},
            shape = "triangle",
            size_modifier = 0.6
        }
    }))
    
    -- Turtle Tank
    table.insert(templates, self.UnitTemplate:new({
        name = "Fortress",
        description = "Maximum defense and health, minimal offense.",
        created_by = "Default",
        point_budget = 100,
        stats = {
            health = 280,
            speed = 20,
            armor = 12,
            detection_range = 35,
            unit_type = "melee"
        },
        abilities = {
            {
                name = "Taunt",
                effect_type = "debuff",
                target_type = "enemy",
                base_value = 0,
                range = 40,
                max_mana = 100,
                mana_rate = 8,
                duration = 5
            }
        },
        appearance = {
            primary_color = {0.4, 0.4, 0.4},
            secondary_color = {0.6, 0.6, 0.6},
            shape = "hexagon",
            size_modifier = 1.4
        }
    }))
    
    -- Speed Demon
    table.insert(templates, self.UnitTemplate:new({
        name = "Scout",
        description = "Maximum mobility and detection range.",
        created_by = "Default",
        point_budget = 100,
        stats = {
            health = 55,
            speed = 120,
            armor = 0,
            detection_range = 150,
            unit_type = "ranged"
        },
        abilities = {
            {
                name = "Quick Shot",
                effect_type = "damage",
                target_type = "enemy",
                base_value = 18,
                range = 65,
                max_mana = 80,
                mana_rate = 15
            }
        },
        appearance = {
            primary_color = {0.0, 1.0, 1.0},
            secondary_color = {0.0, 0.8, 0.8},
            shape = "circle",
            size_modifier = 0.6
        }
    }))
    
    return templates
end
-- }}}

-- {{{ function DefaultTemplateFactory:create_template_showcase_set
function DefaultTemplateFactory:create_template_showcase_set()
    -- This creates templates specifically to demonstrate different mechanics
    local templates = {}
    
    -- Multi-ability Demonstration
    table.insert(templates, self.UnitTemplate:new({
        name = "Versatile Fighter",
        description = "Demonstrates multiple abilities working together.",
        created_by = "Default",
        point_budget = 100,
        stats = {
            health = 110,
            speed = 50,
            armor = 2,
            detection_range = 60,
            unit_type = "melee"
        },
        abilities = {
            {
                name = "Basic Attack",
                effect_type = "damage",
                target_type = "enemy",
                base_value = 25,
                range = 25,
                max_mana = 80,
                mana_rate = 12
            },
            {
                name = "Power Strike",
                effect_type = "damage",
                target_type = "enemy",
                base_value = 45,
                range = 25,
                max_mana = 150,
                mana_rate = 6
            },
            {
                name = "Battle Roar",
                effect_type = "buff",
                target_type = "ally",
                base_value = 15,
                range = 50,
                max_mana = 200,
                mana_rate = 4,
                duration = 10,
                area_radius = 30
            }
        },
        appearance = {
            primary_color = {0.6, 0.2, 0.8},
            secondary_color = {0.4, 0.1, 0.6},
            shape = "octagon",
            size_modifier = 1.0
        }
    }))
    
    return templates
end
-- }}}

-- {{{ function DefaultTemplateFactory:validate_all_templates
function DefaultTemplateFactory:validate_all_templates(templates)
    local TemplateValidator = require("src.validators.template_validator")
    local validator = TemplateValidator:new()
    
    local validation_results = {}
    
    for _, template in ipairs(templates) do
        local is_valid, errors, warnings = validator:validate_template(template)
        
        table.insert(validation_results, {
            template_name = template.name,
            is_valid = is_valid,
            errors = errors,
            warnings = warnings
        })
        
        if not is_valid then
            print("ERROR: Default template '" .. template.name .. "' failed validation:")
            for _, error in ipairs(errors) do
                print("  - " .. error)
            end
        elseif #warnings > 0 then
            print("WARNING: Default template '" .. template.name .. "' has warnings:")
            for _, warning in ipairs(warnings) do
                print("  - " .. warning)
            end
        end
    end
    
    return validation_results
end
-- }}}

-- {{{ function DefaultTemplateFactory:get_template_by_archetype
function DefaultTemplateFactory:get_template_by_archetype(archetype)
    local archetypes = {
        tank = "Basic Guardian",
        damage = "Basic Warrior", 
        ranged_damage = "Basic Archer",
        support = "Basic Healer",
        glass_cannon = "Glass Cannon",
        crowd_control = "Frost Mage",
        hybrid = "Battle Cleric",
        speed = "Scout"
    }
    
    if archetypes[archetype] then
        local all_templates = self:create_all_default_templates()
        for _, template in ipairs(all_templates) do
            if template.name == archetypes[archetype] then
                return template
            end
        end
    end
    
    return nil
end
-- }}}

return DefaultTemplateFactory
```

### Template Documentation Generator (src/utils/template_documentation.lua)
```lua
-- {{{ TemplateDocumentationGenerator
local TemplateDocumentationGenerator = {}

function TemplateDocumentationGenerator.generate_template_guide(templates)
    local guide = "# Default Unit Template Guide\n\n"
    
    guide = guide .. "## Template Categories\n\n"
    
    local categories = {
        basic = {},
        advanced = {},
        specialist = {},
        experimental = {}
    }
    
    -- Categorize templates
    for _, template in ipairs(templates) do
        local category = TemplateDocumentationGenerator.determine_category(template)
        table.insert(categories[category], template)
    end
    
    -- Generate documentation for each category
    for category_name, category_templates in pairs(categories) do
        if #category_templates > 0 then
            guide = guide .. "### " .. string.upper(string.sub(category_name, 1, 1)) .. string.sub(category_name, 2) .. " Templates\n\n"
            
            for _, template in ipairs(category_templates) do
                guide = guide .. TemplateDocumentationGenerator.generate_template_documentation(template)
            end
        end
    end
    
    return guide
end

function TemplateDocumentationGenerator.determine_category(template)
    if #template.abilities == 1 and template.points_used <= 100 then
        return "basic"
    elseif #template.abilities > 2 then
        return "advanced"
    elseif template.stats.health < 70 or template.stats.health > 250 then
        return "experimental"
    else
        return "specialist"
    end
end

function TemplateDocumentationGenerator.generate_template_documentation(template)
    local doc = string.format("#### %s\n", template.name)
    doc = doc .. string.format("**Description:** %s\n\n", template.description or "No description")
    doc = doc .. string.format("**Point Cost:** %d/%d\n", template.points_used, template.point_budget)
    doc = doc .. string.format("**Unit Type:** %s\n\n", template.stats.unit_type)
    
    doc = doc .. "**Stats:**\n"
    doc = doc .. string.format("- Health: %d\n", template.stats.health)
    doc = doc .. string.format("- Speed: %d\n", template.stats.speed)
    doc = doc .. string.format("- Armor: %d\n", template.stats.armor)
    doc = doc .. string.format("- Detection Range: %d\n\n", template.stats.detection_range)
    
    doc = doc .. "**Abilities:**\n"
    for i, ability in ipairs(template.abilities) do
        doc = doc .. string.format("%d. **%s** (%s)\n", i, ability.name, ability.effect_type)
        doc = doc .. string.format("   - Effect: %d %s\n", ability.base_value or 0, ability.effect_type)
        doc = doc .. string.format("   - Range: %d\n", ability.range or 0)
        if ability.area_radius then
            doc = doc .. string.format("   - Area: %d radius\n", ability.area_radius)
        end
        if ability.duration then
            doc = doc .. string.format("   - Duration: %d seconds\n", ability.duration)
        end
    end
    
    doc = doc .. "\n---\n\n"
    
    return doc
end

return TemplateDocumentationGenerator
```

### Acceptance Criteria
- [ ] Comprehensive set of balanced default templates covering all major archetypes
- [ ] Templates demonstrate different strategies and gameplay styles
- [ ] All default templates pass validation without errors
- [ ] Templates serve as good examples for new players
- [ ] Default set enables immediate meaningful gameplay testing
- [ ] Templates showcase the full range of the template system's capabilities