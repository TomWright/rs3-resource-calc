-- effects.lua
-- Works out which XP effects (gear sets, items, altars, areas, urns...) are
-- in use for an activity.
--
-- Every bonus has a setting the player can change in the panel:
--   Auto     use what the plugin can see right now (gear worn, altar nearby)
--   Off      not used
--   option   used, in a particular way (e.g. "3/5 pieces", "2 burners lit")
-- Settings are stored as numbers: nil = Auto, 0 = Off, n = the n-th entry of
-- effects.options(effect). Bonuses the plugin can't see (urns, Double XP...)
-- have no Auto; they are Off until chosen.
--
-- Pure Lua: everything it needs about the game is passed in as a "context"
-- table (built by main.lua from src/game.lua, or by hand in tests):
--   context.worn      = { ["Item name"] = true, ... }    worn equipment
--   context.backpack  = { ["Item name"] = count, ... }   backpack contents
--   context.nearby    = { ["Scenery name"] = true, ... } nearby scenery
--   context.areas     = { ["area_id"] = true, ... }      areas the player is in
--   context.bonuses   = { ["setting key"] = number }     the player's settings
--
-- See data/effects.lua for the fields an effect definition can have, and
-- src/calculator.lua for how each effect "kind" changes the XP.

local effects = {}

effects.OFF = 0

-- The order effects are listed in reports: the order the calculator uses them.
effects.KIND_ORDER = {
    "multiplyBase", "basePercent", "addBase", "percent", "multiplier",
    "globalPercent", "doubleXp", "urnPercent", "extraChance", "saveChance", "inputScale",
}

-- Returns true if `effect` is relevant to `activity`. An effect lists the
-- skills and/or activity tags it applies to; matching any one is enough.
function effects.appliesTo(effect, activity)
    local rule = effect.appliesTo or {}
    if rule.allSkills then
        return true
    end
    for _, skill in ipairs(rule.skills or {}) do
        if skill == activity.skill then
            return true
        end
    end
    for _, tag in ipairs(rule.tags or {}) do
        if activity.tags ~= nil and activity.tags[tag] then
            return true
        end
    end
    return false
end

--- The key a bonus's setting is stored under. Effects can share one setting
--- by naming another effect's id in `toggleId`.
function effects.settingKey(effect)
    return effect.toggleId or effect.id
end

--- True if the plugin can detect this bonus by itself (so it offers Auto).
function effects.canDetect(effect)
    return effect.detect.type ~= "toggle"
end

--- The ways a bonus can be used, as a list of { label =, value = }:
---   gear sets   one entry per number of pieces ("3/5 pieces", "Full set")
---   choices     the effect's own choices (e.g. how many burners are lit)
---   otherwise   a single "On"
function effects.options(effect)
    local detect = effect.detect
    if detect.type == "set" then
        local total, list = #detect.pieces, {}
        for pieces = detect.minPieces or 1, total do
            -- Sets that only work as a whole (minPieces) can leave out
            -- perPiece and take their value from `value` or the activity.
            local value = effect.value
            if detect.perPiece ~= nil then
                value = pieces * detect.perPiece + (pieces == total and (detect.fullSetBonus or 0) or 0)
            end
            local label = pieces == total and string.format("Full set (%d/%d)", total, total)
                or string.format("%d/%d pieces", pieces, total)
            table.insert(list, { label = label, value = value })
        end
        return list
    elseif effect.choices ~= nil then
        return effect.choices
    end
    return { { label = "On", value = effect.value } }
end

-- Counts how many of a gear set's pieces are worn. Each piece is either one
-- item name or a list of names that all count as that piece.
local function countWornPieces(pieces, worn)
    local count = 0
    for _, piece in ipairs(pieces) do
        local names = type(piece) == "table" and piece or { piece }
        for _, name in ipairs(names) do
            if worn[name] then
                count = count + 1
                break
            end
        end
    end
    return count
end

-- Returns true if any of `names` is a key in `set`.
local function anyPresent(names, set)
    for _, name in ipairs(names) do
        if set[name] then
            return true
        end
    end
    return false
end

--- What the plugin can see of a bonus right now. Returns the index into
--- effects.options() that matches and a description (e.g. "3/5 pieces worn"),
--- or nil if it isn't detected (or can't be).
function effects.detect(effect, context)
    local detect = effect.detect
    local index, detail = effect.defaultChoice or 1, nil

    if detect.type == "set" then
        local worn = countWornPieces(detect.pieces, context.worn or {})
        local fewest = detect.minPieces or 1
        if worn < fewest then
            return nil
        end
        index = worn - fewest + 1
        detail = string.format("%d/%d pieces worn", worn, #detect.pieces)
    elseif detect.type == "worn" then
        if not anyPresent(detect.names, context.worn or {}) then
            return nil
        end
        detail = "worn"
    elseif detect.type == "backpack" then
        if not anyPresent(detect.names, context.backpack or {}) then
            return nil
        end
        detail = "in backpack"
    elseif detect.type == "carried" then
        -- Works whether worn or in the backpack.
        if anyPresent(detect.names, context.worn or {}) then
            detail = "worn"
        elseif anyPresent(detect.names, context.backpack or {}) then
            detail = "in backpack"
        else
            return nil
        end
    elseif detect.type == "nearby" then
        if not anyPresent(detect.names, context.nearby or {}) then
            return nil
        end
        detail = "nearby"
    elseif detect.type == "area" then
        -- Anyone standing in the area gets it (e.g. a Fort Forinthry room).
        if not (context.areas or {})[detect.area.id] then
            return nil
        end
        detail = "in " .. detect.area.name
    elseif detect.type == "toggle" then
        return nil
    else
        error("Unknown detection type '" .. tostring(detect.type) .. "' on effect " .. effect.id)
    end

    -- Some bonuses only count in a certain area (e.g. the Wilderness).
    if effect.requiresArea ~= nil then
        if not (context.areas or {})[effect.requiresArea.id] then
            return nil
        end
        detail = detail .. ", in " .. effect.requiresArea.name
    end
    return index, detail
end

--- Checks whether one bonus is in use, from the player's setting for it.
--- Returns nil if not, otherwise a table describing it:
---   { effect = <definition>, value = <number>, detail = <string> }
function effects.evaluate(effect, context)
    local setting = (context.bonuses or {})[effects.settingKey(effect)]
    local options = effects.options(effect)
    local index, detail

    if setting == nil then
        -- Auto: use what's detected, with the default option.
        index, detail = effects.detect(effect, context)
        if index == nil then
            return nil
        end
        if effect.choices ~= nil then
            detail = detail .. ", " .. options[index].label
        end
    elseif setting == effects.OFF then
        return nil
    else
        -- Chosen by the player (for planning, so it doesn't need detecting).
        index = setting
        detail = options[index] and options[index].label or ""
        if detail == "On" then
            detail = "selected"
        end
    end

    local option = options[index]
    if option == nil then
        return nil
    end
    return { effect = effect, value = option.value, detail = detail }
end

-- Removes effects switched off by another active effect. An effect can list
-- `cancels = { "effect_id", ... }`, or set `cancelsAll = true` when nothing
-- else stacks with it (e.g. the Ectofuntus).
local function applyCancellations(active)
    local cancelled = {}
    for _, result in ipairs(active) do
        for _, otherId in ipairs(result.effect.cancels or {}) do
            cancelled[otherId] = true
        end
    end
    for _, result in ipairs(active) do
        if result.effect.cancelsAll then
            return { result }
        end
    end
    local kept = {}
    for _, result in ipairs(active) do
        if not cancelled[result.effect.id] then
            table.insert(kept, result)
        end
    end
    return kept
end

-- Keeps only the highest-value effect from each `exclusiveGroup` (e.g. you
-- can only offer bones at one altar at a time).
local function applyExclusiveGroups(active)
    local kept, bestInGroup = {}, {}
    for _, result in ipairs(active) do
        local group = result.effect.exclusiveGroup
        if group == nil then
            table.insert(kept, result)
        elseif bestInGroup[group] == nil or result.value > bestInGroup[group].value then
            bestInGroup[group] = result
        end
    end
    for _, result in pairs(bestInGroup) do
        table.insert(kept, result)
    end
    return kept
end

--- Every bonus that could apply to `activity`, one per setting key (bonuses
--- sharing a setting appear once), in data order.
function effects.relevantTo(activity, allEffects)
    local list, seen = {}, {}
    for _, effect in ipairs(allEffects) do
        local key = effects.settingKey(effect)
        if effects.appliesTo(effect, activity) and not seen[key] then
            seen[key] = true
            table.insert(list, effect)
        end
    end
    return list
end

--- Returns every bonus in use for `activity`, after removing cancelled ones
--- and keeping the best of each exclusive group, sorted in the order the
--- calculator applies them.
function effects.activeFor(activity, allEffects, context)
    local active = {}
    for _, effect in ipairs(allEffects) do
        if effects.appliesTo(effect, activity) then
            local result = effects.evaluate(effect, context)
            -- `valueFromActivity` names a field on the activity holding the
            -- value (e.g. each unfinished potion's herb-cleaning XP).
            if result ~= nil and effect.valueFromActivity ~= nil then
                result.value = activity[effect.valueFromActivity]
            end
            -- `scaleByActivity` multiplies the chosen value by a field on
            -- the activity (e.g. 1% of a burial set's burial XP).
            if result ~= nil and result.value ~= nil and effect.scaleByActivity ~= nil then
                result.value = result.value * (activity[effect.scaleByActivity] or 0)
            end
            if result ~= nil and result.value ~= nil then
                table.insert(active, result)
            end
        end
    end

    active = applyExclusiveGroups(applyCancellations(active))

    local kindRank = {}
    for rank, kind in ipairs(effects.KIND_ORDER) do
        kindRank[kind] = rank
    end
    table.sort(active, function(a, b)
        local ra, rb = kindRank[a.effect.kind], kindRank[b.effect.kind]
        if ra ~= rb then
            return ra < rb
        end
        return a.effect.name < b.effect.name
    end)
    return active
end

return effects
