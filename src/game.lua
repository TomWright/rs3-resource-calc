-- game.lua
-- The only module that talks to the RuneScape client API. It reads the
-- player's skills, equipment, backpack, bank and surroundings, and packs them
-- into plain Lua tables for the rest of the plugin (see effects.lua for the
-- "context" format). Every lookup is defensive: if something isn't available
-- (e.g. the bank hasn't been opened yet) we return empty data, never error.

local game = {}

-- Inventory config names. config.Inv.INV, BANK and METAL_BANK appear in the
-- docs; worn equipment doesn't, so we try likely names. Run `pan Inv` in the
-- client console to see every inventory name if equipment isn't detected.
local BACKPACK_INV = "INV"
local WORN_INV_CANDIDATES = { "WORN", "WORN_ITEMS", "EQUIPMENT" }

-- How far (in tiles) to look for scenery such as altars or workbenches.
local NEARBY_RANGE = 8

-- Reads `tbl[key]` without raising an error if the key is unknown to the
-- client (some API tables error on unknown names instead of returning nil).
local function safeIndex(tbl, key)
    local ok, value = pcall(function() return tbl[key] end)
    if ok then
        return value
    end
    return nil
end

-- Finds a loaded, valid inventory by config name, or nil.
local function findInventory(configName)
    local invConfig = safeIndex(config.Inv, configName)
    if invConfig == nil then
        return nil
    end
    local ok, inv = pcall(Inventory.Find, invConfig)
    if ok and inv ~= nil and inv.isValid then
        return inv
    end
    return nil
end

-- Returns { ["Item name"] = total count } for an inventory (empty if missing).
local function countItems(inv)
    local counts = {}
    if inv == nil then
        return counts
    end
    for index = 1, inv.slotCount do
        local slot = inv:GetSlot(index)
        if slot ~= nil and slot.obj ~= nil and slot.count > 0 then
            local name = slot.obj.name
            counts[name] = (counts[name] or 0) + slot.count
        end
    end
    return counts
end

--- True once a character is logged in and in the game world.
function game.isReady()
    return Player.IsAvailable()
end

--- Current total XP in a skill, e.g. game.skillXp("SMITHING").
function game.skillXp(skillKey)
    return Player.GetXPUncapped(SkillType[skillKey])
end

--- Current level (from XP, ignoring boosts/drains) in a skill.
function game.skillLevel(skillKey)
    return Player.GetLevelUncapped(SkillType[skillKey])
end

-- In-game skill targets (right-click a skill > set a level or XP target).
-- Each skill's target is held in a VarPlayer (listed by the `pan VarPlayer`
-- console command) named STATS_TARG_01 ... STATS_TARG_29, numbered by
-- SkillType + 1: Attack is 01, Smithing 14, Necromancy 29. It's 0 when no
-- target is set. A target is either a level (up to 120) or an XP amount (up
-- to 200M), so a small value is a level and anything bigger is XP.
local TARGET_VAR_FORMAT = "STATS_TARG_%02d"
local SKILL_COUNT = 29
local MAX_TARGET_LEVEL = 150

-- Reads a VarPlayer's value by name, or nil if the client doesn't have it.
local function varPlayerValue(name)
    local variable = safeIndex(var.VarPlayer, name)
    if variable == nil then
        return nil
    end
    local ok, value = pcall(function() return variable.value end)
    if ok and type(value) == "number" then
        return value
    end
    return nil
end

--- The in-game target set for a skill, as { level = n } or { xp = n }, or
--- nil if there's none (or it can't be read).
function game.skillTarget(skillKey)
    local ok, varName = pcall(string.format, TARGET_VAR_FORMAT, SkillType[skillKey] + 1)
    local value = ok and varPlayerValue(varName) or nil
    if value == nil or value <= 0 then
        return nil
    elseif value <= MAX_TARGET_LEVEL then
        return { level = value }
    end
    return { xp = value }
end

--- Development aid: every skill target set in-game, with the raw values, e.g.
--- "STATS_TARG_14 (SMITHING) = 70". Used to check the numbering above.
function game.describeSkillTargets()
    local parts = {}
    for number = 1, SKILL_COUNT do
        local value = varPlayerValue(string.format(TARGET_VAR_FORMAT, number))
        if value ~= nil and value ~= 0 then
            local start = varPlayerValue(string.format("STATS_TARG_START_%02d", number))
            table.insert(parts, string.format("STATS_TARG_%02d (%s) = %s, start %s",
                number, tostring(game.skillKeyFromId(number - 1)), tostring(value), tostring(start)))
        end
    end
    table.insert(parts, "STATS_TARG_TYPE = " .. tostring(varPlayerValue("STATS_TARG_TYPE")))
    return table.concat(parts, "; ")
end

--- Converts a SkillType number (from SkillTransmit events) to its key, e.g. 13 -> "SMITHING".
function game.skillKeyFromId(skillId)
    -- The events docs use SkillType.FromID() to get a skill's name.
    local ok, name = pcall(SkillType.FromID, skillId)
    if ok and type(name) == "string" then
        return name
    end
    return nil
end

--- { ["Item name"] = count } for the backpack.
function game.backpackCounts()
    return countItems(findInventory(BACKPACK_INV))
end

--- { ["Item name"] = count } for a storage inventory such as "BANK" or
--- "METAL_BANK", or nil if the server hasn't sent it to the client yet
--- (it is sent when the player opens it).
function game.storedCounts(configName)
    local inv = findInventory(configName)
    if inv == nil then
        return nil
    end
    return countItems(inv)
end

-- Remembers which config name worked for worn equipment.
local wornInvName = nil
local warnedNoWornInv = false

--- { ["Item name"] = true } for worn equipment.
function game.wornItems()
    local inv = nil
    if wornInvName ~= nil then
        inv = findInventory(wornInvName)
    else
        for _, name in ipairs(WORN_INV_CANDIDATES) do
            inv = findInventory(name)
            if inv ~= nil then
                wornInvName = name
                break
            end
        end
    end

    if inv == nil then
        if not warnedNoWornInv then
            log("Could not read worn equipment; gear bonuses will not be detected. "
                .. "Run 'pan Inv' in the console and add the equipment inventory name to src/game.lua.")
            warnedNoWornInv = true
        end
        return {}
    end

    local worn = {}
    for name in pairs(countItems(inv)) do
        worn[name] = true
    end
    return worn
end

--- The player's current tile as { x = , z = , level = }, or nil.
function game.playerCoord()
    local entity = Player.GetEntity()
    if entity == nil or not entity.isValid then
        return nil
    end
    local coord = entity.coordGrid
    return { x = coord.x, z = coord.z, level = coord.level }
end

--- Returns { ["Scenery name"] = true } for each of `names` that has a matching
--- scenery object (loc) within NEARBY_RANGE tiles of the player.
function game.nearbyScenery(names)
    local found = {}
    local me = game.playerCoord()
    if me == nil then
        return found
    end
    for _, name in ipairs(names) do
        for _, loc in ipairs(LocList.ByName(name)) do
            if loc.isValid then
                local coord = loc.coordGrid
                local distance = math.max(math.abs(coord.x - me.x), math.abs(coord.z - me.z))
                if coord.level == me.level and distance <= NEARBY_RANGE then
                    found[name] = true
                    break
                end
            end
        end
    end
    return found
end

return game
