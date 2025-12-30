#!/usr/bin/env luajit
--[[
Guild CLI

Command-line interface for the guild/hero/shop system.
Allows creating heroes, completing quests, buying items, and more.

Usage:
  luajit guild-cli.lua create <name>
  luajit guild-cli.lua status [name]
  luajit guild-cli.lua quest <quest_id>
  luajit guild-cli.lua bounty <bounty_id>
  luajit guild-cli.lua shop [shop_id]
  luajit guild-cli.lua buy <item_id>
  luajit guild-cli.lua sell <slot>
  luajit guild-cli.lua equip <slot>
  luajit guild-cli.lua inventory
  luajit guild-cli.lua list
]]

-- Ensure we can find modules from project root
-- This script should be run from the project root directory
package.path = "./?.lua;./?/init.lua;" .. package.path

local guild = require("src.guild")
local Hero = guild.Hero
local ItemRegistry = guild.ItemRegistry
local ShopRegistry = guild.ShopRegistry

-- {{{ State
local current_hero = nil
local current_hero_name = nil
-- }}}

-- {{{ load_current_hero
local function load_current_hero()
    -- Try to load from .guild/current file
    local f = io.open(".guild/current", "r")
    if f then
        local name = f:read("*l")
        f:close()
        if name and name ~= "" then
            local hero, err = guild.load_hero(name)
            if hero then
                current_hero = hero
                current_hero_name = name
                return true
            end
        end
    end
    return false
end
-- }}}

-- {{{ save_current_hero
local function save_current_hero()
    if current_hero then
        current_hero.last_active = os.time()
        guild.save_hero(current_hero)

        -- Also save current name
        os.execute("mkdir -p .guild")
        local f = io.open(".guild/current", "w")
        if f then
            f:write(current_hero.name)
            f:close()
        end
    end
end
-- }}}

-- {{{ set_current_hero
local function set_current_hero(hero)
    current_hero = hero
    current_hero_name = hero.name
    save_current_hero()
end
-- }}}

-- {{{ Commands
local commands = {}

-- {{{ create
function commands.create(args)
    local name = args[1]
    if not name then
        print("Usage: guild-cli.lua create <name>")
        return
    end

    -- Check if already exists
    local existing = guild.load_hero(name)
    if existing then
        print("Hero '" .. name .. "' already exists!")
        print("Use 'guild-cli.lua switch " .. name .. "' to switch to them.")
        return
    end

    local hero = Hero.new(name)
    set_current_hero(hero)

    print("Created new hero: " .. name)
    print("")
    print(hero:format())
end
-- }}}

-- {{{ status
function commands.status(args)
    local name = args[1]

    local hero
    if name then
        hero = guild.load_hero(name)
        if not hero then
            print("Hero not found: " .. name)
            return
        end
    else
        if not current_hero then
            print("No current hero. Create one with: guild-cli.lua create <name>")
            return
        end
        hero = current_hero
    end

    print(hero:format())
end
-- }}}

-- {{{ switch
function commands.switch(args)
    local name = args[1]
    if not name then
        print("Usage: guild-cli.lua switch <name>")
        return
    end

    local hero = guild.load_hero(name)
    if not hero then
        print("Hero not found: " .. name)
        return
    end

    set_current_hero(hero)
    print("Switched to: " .. name)
end
-- }}}

-- {{{ list
function commands.list(args)
    local heroes = guild.list_saved_heroes()

    if #heroes == 0 then
        print("No heroes found. Create one with: guild-cli.lua create <name>")
        return
    end

    print("Saved Heroes:")
    for _, name in ipairs(heroes) do
        local hero = guild.load_hero(name)
        if hero then
            local marker = (current_hero and current_hero.name == name) and " *" or ""
            print(string.format("  [Lv.%d] %s%s", hero.level, name, marker))
        end
    end
end
-- }}}

-- {{{ quest
function commands.quest(args)
    local quest_id = args[1]
    if not quest_id then
        print("Usage: guild-cli.lua quest <quest_id>")
        print("")
        print("Available quests:")
        for id, data in pairs(guild.QUEST_DATA) do
            print(string.format("  %s - %d XP, %d gold", id, data.xp, data.gold))
        end
        return
    end

    if not current_hero then
        print("No current hero. Create one first.")
        return
    end

    local quest_data = guild.get_quest_data(quest_id:upper())
    if not quest_data then
        print("Unknown quest: " .. quest_id)
        return
    end

    if current_hero.completed_quests[quest_id:upper()] then
        print("Quest already completed!")
        return
    end

    local ok, err = current_hero:complete_quest(quest_id:upper(), quest_data)
    if not ok then
        print("Error: " .. err)
        return
    end

    save_current_hero()

    print("Quest Complete: " .. quest_id:upper())
    print(string.format("  +%d XP", quest_data.xp))
    print(string.format("  +%d gold", quest_data.gold))
    if quest_data.capability then
        print(string.format("  Unlocked: %s", quest_data.capability))
    end
    print("")
    print(string.format("Level: %d | XP: %d | Gold: %d",
        current_hero.level, current_hero.xp, current_hero.gold))
end
-- }}}

-- {{{ bounty
function commands.bounty(args)
    local bounty_id = args[1]
    if not bounty_id then
        print("Usage: guild-cli.lua bounty <bounty_id>")
        print("")
        print("Available bounties:")
        for id, data in pairs(guild.BOUNTY_DATA) do
            print(string.format("  %s - %d XP, %d gold", id, data.xp, data.gold))
        end
        return
    end

    if not current_hero then
        print("No current hero. Create one first.")
        return
    end

    local bounty_data = guild.get_bounty_data(bounty_id:upper())
    if not bounty_data then
        print("Unknown bounty: " .. bounty_id)
        return
    end

    if current_hero.completed_bounties[bounty_id:upper()] then
        print("Bounty already claimed!")
        return
    end

    local ok, err = current_hero:complete_bounty(bounty_id:upper(), bounty_data)
    if not ok then
        print("Error: " .. err)
        return
    end

    save_current_hero()

    print("BOUNTY CLAIMED: " .. bounty_id:upper())
    print(string.format("  +%d XP", bounty_data.xp))
    print(string.format("  +%d gold", bounty_data.gold))
    if bounty_data.capability then
        print(string.format("  Unlocked: %s", bounty_data.capability))
    end
    print("")
    print(string.format("Level: %d | XP: %d | Gold: %d",
        current_hero.level, current_hero.xp, current_hero.gold))
end
-- }}}

-- {{{ shop
function commands.shop(args)
    local shop_id = args[1]

    if not current_hero then
        print("No current hero. Create one first.")
        return
    end

    if not shop_id then
        -- List all shops
        print("Available Shops:")
        local shops = ShopRegistry.list()
        for _, shop in ipairs(shops) do
            local can, err = shop:can_access(current_hero)
            local status = can and "" or " [LOCKED: " .. err .. "]"
            print(string.format("  %s - %s%s", shop.id, shop.name, status))
        end
        return
    end

    local shop = ShopRegistry.get(shop_id)
    if not shop then
        print("Unknown shop: " .. shop_id)
        return
    end

    local can, err = shop:can_access(current_hero)
    if not can then
        print("Cannot access shop: " .. err)
        return
    end

    print(shop:format(current_hero))
end
-- }}}

-- {{{ buy
function commands.buy(args)
    local item_id = args[1]
    local quantity = tonumber(args[2]) or 1
    local shop_id = args[3] or "guild_merchant"

    if not item_id then
        print("Usage: guild-cli.lua buy <item_id> [quantity] [shop_id]")
        return
    end

    if not current_hero then
        print("No current hero. Create one first.")
        return
    end

    local shop = ShopRegistry.get(shop_id)
    if not shop then
        print("Unknown shop: " .. shop_id)
        return
    end

    local ok, result = shop:buy(current_hero, item_id, quantity)
    if not ok then
        print("Purchase failed: " .. result)
        return
    end

    save_current_hero()

    print(string.format("Purchased %dx %s for %d gold",
        result.quantity, item_id, result.total_cost))
    print(string.format("Gold remaining: %d", current_hero.gold))
end
-- }}}

-- {{{ sell
function commands.sell(args)
    local slot = tonumber(args[1])
    local shop_id = args[2] or "guild_merchant"

    if not slot then
        print("Usage: guild-cli.lua sell <slot> [shop_id]")
        return
    end

    if not current_hero then
        print("No current hero. Create one first.")
        return
    end

    local shop = ShopRegistry.get(shop_id)
    if not shop then
        print("Unknown shop: " .. shop_id)
        return
    end

    local ok, result = shop:sell(current_hero, slot)
    if not ok then
        print("Sale failed: " .. result)
        return
    end

    save_current_hero()

    print(string.format("Sold %s for %d gold",
        result.item_name, result.gold_earned))
    print(string.format("Gold: %d", current_hero.gold))
end
-- }}}

-- {{{ inventory
function commands.inventory(args)
    if not current_hero then
        print("No current hero. Create one first.")
        return
    end

    print("=== Inventory ===")
    print(string.format("Gold: %d", current_hero.gold))
    print("")

    print("Equipment:")
    for _, slot in ipairs(guild.EQUIPMENT_SLOTS) do
        local item = current_hero.equipment[slot]
        local name = item and item.name or "(empty)"
        print(string.format("  [%s] %s", slot, name))
    end
    print("")

    print("Inventory:")
    local empty = true
    for i = 1, guild.INVENTORY_SIZE do
        local item = current_hero.inventory[i]
        if item then
            empty = false
            local qty = item.quantity and item.quantity > 1
                and string.format(" x%d", item.quantity) or ""
            print(string.format("  [%d] %s%s", i, item.name, qty))
        end
    end
    if empty then
        print("  (empty)")
    end
end
-- }}}

-- {{{ equip
function commands.equip(args)
    local slot = tonumber(args[1])

    if not slot then
        print("Usage: guild-cli.lua equip <inventory_slot>")
        return
    end

    if not current_hero then
        print("No current hero. Create one first.")
        return
    end

    local item = current_hero.inventory[slot]
    if not item then
        print("No item in slot " .. slot)
        return
    end

    if not item:is_equipment() then
        print("Item is not equipment")
        return
    end

    local ok, err = current_hero:equip(item)
    if not ok then
        print("Cannot equip: " .. err)
        return
    end

    save_current_hero()

    print(string.format("Equipped %s in %s slot", item.name, item.slot))
end
-- }}}

-- {{{ unequip
function commands.unequip(args)
    local slot = args[1]

    if not slot then
        print("Usage: guild-cli.lua unequip <equipment_slot>")
        print("Slots: weapon, armor, accessory")
        return
    end

    if not current_hero then
        print("No current hero. Create one first.")
        return
    end

    local item, err = current_hero:unequip(slot)
    if not item then
        print("Cannot unequip: " .. err)
        return
    end

    save_current_hero()

    print(string.format("Unequipped %s", item.name))
end
-- }}}

-- {{{ use
function commands.use(args)
    local slot = tonumber(args[1])

    if not slot then
        print("Usage: guild-cli.lua use <inventory_slot>")
        return
    end

    if not current_hero then
        print("No current hero. Create one first.")
        return
    end

    local item = current_hero.inventory[slot]
    if not item then
        print("No item in slot " .. slot)
        return
    end

    local ok, results, consumed = item:use(current_hero)
    if not ok then
        print("Cannot use: " .. results)
        return
    end

    -- Remove if consumed
    if consumed then
        current_hero:remove_from_inventory(slot)
    end

    save_current_hero()

    print("Used: " .. item.name)
    for _, result in ipairs(results) do
        print("  " .. result.message)
    end
end
-- }}}

-- {{{ items
function commands.items(args)
    local filter_type = args[1]

    print("Available Items in Registry:")
    print("")

    local items = ItemRegistry.list({ type = filter_type })
    table.sort(items)

    for _, id in ipairs(items) do
        local item = ItemRegistry.get(id)
        if item then
            local rarity = item:get_rarity_info()
            print(string.format("  %s [%s] - %d gold",
                id, rarity.name, item.buy_price))
        end
    end
end
-- }}}

-- {{{ capabilities
function commands.capabilities(args)
    if not current_hero then
        print("No current hero. Create one first.")
        return
    end

    print("=== Capabilities ===")

    local count = 0
    for cap, _ in pairs(current_hero.capabilities) do
        count = count + 1
        print("  [x] " .. cap)
    end

    if count == 0 then
        print("  (none unlocked)")
        print("")
        print("Complete quests to unlock capabilities!")
    end
end
-- }}}

-- {{{ help
function commands.help(args)
    print([[
Guild CLI - Hero & Shop Management

Usage: luajit guild-cli.lua <command> [args...]

Hero Commands:
  create <name>     Create a new hero
  status [name]     Show hero status
  switch <name>     Switch to a different hero
  list              List all saved heroes
  capabilities      Show unlocked capabilities

Quest Commands:
  quest <id>        Complete a quest (S1, S2, A1, A2, J1, J2, J3, V1)
  bounty <id>       Claim a bounty (B01, B02, B03)

Shop Commands:
  shop [id]         Browse shops (list all if no id given)
  buy <item> [qty]  Buy an item from current shop
  sell <slot>       Sell item from inventory slot

Inventory Commands:
  inventory         Show inventory and equipment
  equip <slot>      Equip item from inventory slot
  unequip <slot>    Remove equipment (weapon/armor/accessory)
  use <slot>        Use consumable from inventory slot

Other:
  items [type]      List all registered items
  help              Show this help

Examples:
  luajit guild-cli.lua create "Claude"
  luajit guild-cli.lua quest S1
  luajit guild-cli.lua shop guild_merchant
  luajit guild-cli.lua buy coffee_potion 5
]])
end
-- }}}
-- }}}

-- {{{ Main
local function main()
    -- Load current hero if exists
    load_current_hero()

    local cmd = arg[1]
    if not cmd then
        cmd = "help"
    end

    -- Collect remaining args
    local cmd_args = {}
    for i = 2, #arg do
        table.insert(cmd_args, arg[i])
    end

    -- Dispatch
    local handler = commands[cmd]
    if handler then
        handler(cmd_args)
    else
        print("Unknown command: " .. cmd)
        print("Use 'guild-cli.lua help' for usage.")
    end
end

main()
-- }}}
