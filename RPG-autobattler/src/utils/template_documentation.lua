-- {{{ Template documentation
-- Writes the guide to the default unit templates (docs/default-
-- templates.md) from src/data/default_templates.lua, so the guide can
-- never drift from the data: tests/test_default_templates.lua checks the
-- file matches, and `./run <dir> template-docs` rewrites it.
--
--   TemplateDocumentation.generate_guide()        the whole guide
--   TemplateDocumentation.document(template, data) one template's part
local TemplateDocumentation = {}

local DefaultTemplates = require("src.data.default_templates")
local UnitTemplate = require("src.data.unit_template")
local Ability = require("src.components.ability")

-- {{{ local function number
-- Whole numbers without a decimal point, others to one place.
local function number(value)
    if value == math.floor(value) then
        return string.format("%d", value)
    end
    return string.format("%.1f", value)
end
-- }}}

-- {{{ TemplateDocumentation.ability_line
-- One ability in a line: name, kind, what it does, reach and charge time.
function TemplateDocumentation.ability_line(index, ability, cost)
    local parts = {}
    if ability.type == "buff" or ability.type == "debuff" then
        table.insert(parts, string.format("%s for %s s", ability.type, number(ability.duration)))
    elseif ability.type == "area" then
        table.insert(parts, string.format("%s %s in a %s radius", number(ability.power),
            ability.area_effect == "heal" and "healing" or "damage", number(ability.area_radius)))
        if (ability.zone_duration or 0) > 0 then
            table.insert(parts, string.format("leaves a zone for %s s", number(ability.zone_duration)))
        end
    else
        table.insert(parts, string.format("%s %s", number(ability.power), ability.type == "heal" and "healing" or "damage"))
    end
    if (ability.cleave_targets or 0) > 0 then
        table.insert(parts, string.format("cleaves %d more", ability.cleave_targets))
    end
    if ability.pierce > 1 then
        table.insert(parts, string.format("pierces %d", ability.pierce))
    end
    if ability.delivery == "projectile" then
        table.insert(parts, "projectile")
    end
    local charge = ability.max_mana / ability.mana_rate
    return string.format("%d. **%s** (%s): %s; reach %s; charges in %s s; %d points%s", index, ability.name,
        index == 1 and "primary" or ability.type, table.concat(parts, ", "), number(ability.range), number(charge), cost,
        ability.cooldown > 0 and string.format("; cooldown %s s", number(ability.cooldown)) or "")
end
-- }}}

-- {{{ TemplateDocumentation.document
function TemplateDocumentation.document(template, data)
    local lines = {}
    table.insert(lines, "### " .. template.name)
    table.insert(lines, "")
    table.insert(lines, template.description)
    table.insert(lines, "")
    local archetype = (data.archetype or "?"):gsub("_", " ")
    table.insert(lines, string.format("- **Body:** %s; **archetype:** %s", template.unit_type, archetype))
    table.insert(lines, string.format("- **Points:** %d of %d", template.points_used, template.point_budget))
    local stats = template.stats
    table.insert(lines, string.format("- **Stats:** health %s, speed %s, armor %s, magic resist %s, sight %s",
        number(stats.health), number(stats.speed), number(stats.armor), number(stats.magic_resist),
        number(stats.detection_range)))
    if data.strategy then
        table.insert(lines, "- **How to use it:** " .. data.strategy)
    end
    table.insert(lines, "")
    table.insert(lines, "Abilities:")
    table.insert(lines, "")
    for index = 1, #template.abilities do
        local ability = Ability.new(template:ability_config(index))
        table.insert(lines, TemplateDocumentation.ability_line(index, ability, template.breakdown.abilities[index]))
    end
    if #template.validation_warnings > 0 then
        table.insert(lines, "")
        table.insert(lines, "Warnings (on purpose): " .. table.concat(template.validation_warnings, "; ") .. ".")
    end
    table.insert(lines, "")
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ TemplateDocumentation.generate_guide
function TemplateDocumentation.generate_guide()
    local out = {
        "# Default Unit Templates",
        "",
        "Generated from `src/data/default_templates.lua` by `src/utils/template_documentation.lua`;",
        "rewrite it with `./run <dir> template-docs` rather than editing it by hand.",
        "",
        "Every template has a budget of 100 points. Point costs are first guesses (issue 058);",
        "tuning waits until ability sets play in real matches (issue 067).",
        ""
    }
    local data_by_set = {}
    for _, data in ipairs(DefaultTemplates.data()) do
        data_by_set[data.set] = data_by_set[data.set] or {}
        table.insert(data_by_set[data.set], data)
    end
    for _, set_name in ipairs(DefaultTemplates.SET_ORDER) do
        table.insert(out, "## " .. set_name:sub(1, 1):upper() .. set_name:sub(2))
        table.insert(out, "")
        table.insert(out, DefaultTemplates.SET_DESCRIPTIONS[set_name])
        table.insert(out, "")
        for _, data in ipairs(data_by_set[set_name] or {}) do
            table.insert(out, TemplateDocumentation.document(UnitTemplate.new(data), data))
        end
    end
    return table.concat(out, "\n")
end
-- }}}

return TemplateDocumentation
-- }}}
