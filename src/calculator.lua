-- calculator.lua
-- Turns "I have X XP and want Y XP doing this activity, with these effects"
-- into "you need N actions, using these resources".
-- Pure Lua: no game API calls.
--
-- How boosts combine follows the RuneScape Wiki's experience calculator
-- (https://runescape.wiki/w/Calculator:Experience_Buffs). The wiki notes the
-- exact rounding order is still being researched, so treat results as very
-- close estimates rather than exact to the last XP:
--
--   base     = activity XP x every "multiplyBase" (altars...)
--                          x (1 + each "basePercent")   (Voice of Seren, bonfires...)
--                            (or + activity XP x percent, for the few marked
--                             ofRawXp, e.g. Fort Forinthry rooms)
--                          + each "addBase"             (flat XP, e.g. Dwarven army axe)
--   boosted  = (base + base x sum of "percent")         (outfits: they add together)
--              x every "multiplier"                     (brawling gloves)
--   global   = boosted x (1 + sum of "globalPercent")   (clan avatar)
--   total    = (global
--               + base x sum of "doubleXp"              (Double XP: +100% of base)
--               + base x sum of "urnPercent")           (urns, paid out on teleport)
--              x (1 + sum of "extraChance")             (chances of a free extra
--                                                         action with full XP, as
--                                                         an average)

local calculator = {}

-- Small tolerance so floating point noise (e.g. 29.999999) doesn't round up
-- to an extra action.
local EPSILON = 1e-9

local function ceil(value)
    return math.ceil(value - EPSILON)
end

-- Effect kinds that change resources used rather than XP.
local RESOURCE_KINDS = { saveChance = true, inputScale = true }

--- Works out the XP gained per action once all `activeEffects` are applied.
--- Returns { baseXp, xpPerAction, boostPercent }.
function calculator.xpPerAction(activity, activeEffects)
    local base = activity.xp
    local percent, multiplier, globalPercent, doubleXp, urnPercent, extraChance = 0, 1, 0, 0, 0, 0

    for _, active in ipairs(activeEffects) do
        local kind, value = active.effect.kind, active.value
        if kind == "multiplyBase" then
            base = base * value
        elseif kind == "basePercent" and active.effect.ofRawXp then
            base = base + activity.xp * value / 100
        elseif kind == "basePercent" then
            base = base * (1 + value / 100)
        elseif kind == "addBase" then
            base = base + value
        elseif kind == "percent" then
            percent = percent + value
        elseif kind == "multiplier" then
            multiplier = multiplier * value
        elseif kind == "globalPercent" then
            globalPercent = globalPercent + value
        elseif kind == "doubleXp" then
            doubleXp = doubleXp + value
        elseif kind == "urnPercent" then
            urnPercent = urnPercent + value
        elseif kind == "extraChance" then
            extraChance = extraChance + value
        elseif not RESOURCE_KINDS[kind] then
            error("Unknown effect kind '" .. tostring(kind) .. "' on " .. active.effect.id)
        end
    end

    local boosted = base * (1 + percent / 100) * multiplier
    local global = boosted * (1 + globalPercent / 100)
    local total = (global + base * doubleXp / 100 + base * urnPercent / 100) * (1 + extraChance)

    return {
        baseXp = base,
        xpPerAction = total,
        boostPercent = (total / activity.xp - 1) * 100,
    }
end

--- How much of an input each action really uses, on average.
---   "inputScale" changes the amount (0.5 = half, 0 = not needed).
---   "saveChance" is a chance not to use it up at all, or, with `saveQty`,
---   a chance to save just that many pieces (e.g. one leather of three);
---   those piece savings add up rather than multiply.
--- An effect with `onlyInputs = { "Item name", ... }` affects only those items.
--- An effect with `onlySaveable = true` affects only inputs marked
--- `saveable`, and when an activity has several, picks one of them at
--- random each time (so each is saved chance / count of the time).
function calculator.inputQty(input, activeEffects, activity)
    local saveableCount = 0
    for _, other in ipairs(activity.inputs or {}) do
        if other.saveable then
            saveableCount = saveableCount + 1
        end
    end

    local qty, piecesSaved = input.qty, 0
    for _, active in ipairs(activeEffects) do
        local effect, value = active.effect, active.value
        local applies = effect.onlyInputs == nil
        for _, name in ipairs(effect.onlyInputs or {}) do
            if name == input.item then
                applies = true
            end
        end
        if effect.onlySaveable then
            applies = input.saveable == true
            value = value / math.max(1, saveableCount)
        end
        if applies and effect.kind == "saveChance" and effect.saveQty ~= nil then
            piecesSaved = piecesSaved + value * effect.saveQty
        elseif applies and effect.kind == "saveChance" then
            qty = qty * (1 - value)
        elseif applies and effect.kind == "inputScale" then
            qty = qty * value
        end
    end
    return math.max(0, qty - piecesSaved)
end

--- Main entry point. `request` fields:
---   activity             activity definition (see data/activities)
---   currentXp            the player's current XP in the activity's skill
---   targetXp             the XP the player wants to reach
---   activeEffects        list from effects.activeFor()
---   have                 optional: { ["Item name"] = count } owned resources
function calculator.calculate(request)
    local activity = request.activity
    local activeEffects = request.activeEffects or {}
    local rates = calculator.xpPerAction(activity, activeEffects)

    local xpNeeded = math.max(0, request.targetXp - request.currentXp)
    local actions = 0
    if xpNeeded > 0 then
        actions = ceil(xpNeeded / rates.xpPerAction)
    end

    -- Resources: the activity's own inputs (less anything effects save), plus
    -- any extra an effect needs (e.g. a bucket of slime at the Ectofuntus).
    local allInputs = {}
    for _, input in ipairs(activity.inputs or {}) do
        table.insert(allInputs, { item = input.item, qty = calculator.inputQty(input, activeEffects, activity) })
    end
    for _, active in ipairs(activeEffects) do
        for _, input in ipairs(active.effect.extraInputs or {}) do
            table.insert(allInputs, { item = input.item, qty = input.qty })
        end
    end

    local inputs = {}
    local have = request.have or {}
    for _, input in ipairs(allInputs) do
        -- Inputs an effect makes unnecessary (e.g. thread with a Crafting
        -- cape) aren't listed at all.
        if input.qty > 0 then
            local needed = ceil(actions * input.qty)
            local owned = have[input.item] or 0
            table.insert(inputs, {
                item = input.item,
                needed = needed,
                have = owned,
                short = math.max(0, needed - owned),
            })
        end
    end

    return {
        activity = activity,
        xpNeeded = xpNeeded,
        actions = actions,
        inputs = inputs,
        baseXp = rates.baseXp,
        boostPercent = rates.boostPercent,
        xpPerAction = rates.xpPerAction,
        activeEffects = activeEffects,
    }
end

return calculator
