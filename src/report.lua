-- report.lua
-- Turns a calculator result into human-readable lines: what you need, and
-- why (which bonuses were applied). Used by the UI and the console output.
-- Pure Lua: no game API calls.

local format = require("src/format")

local report = {}

-- What each kind of effect does, in words. %s is the formatted value.
local KIND_TEXT = {
    multiplyBase = "base XP x%s",
    basePercent = "%s base XP",
    addBase = "+%s base XP",
    percent = "%s",
    multiplier = "x%s XP",
    globalPercent = "%s on all XP",
    doubleXp = "%s base XP",
    urnPercent = "%s base XP, paid when the urn is teleported",
    saveChance = "%s chance to keep your %s",
    inputScale = "uses x%s %s",
}

-- Describes one active effect, e.g. "Blacksmith's outfit (5/5 pieces worn): +6%".
local function describeEffect(active)
    local effect, value = active.effect, active.value
    local label = string.format("%s (%s): ", effect.name, active.detail)
    -- Resource effects name the items they touch, if they're limited to some
    -- (or use a short `inputsLabel` such as "leather" for a long list).
    local items = effect.inputsLabel or (effect.onlyInputs and table.concat(effect.onlyInputs, ", ")) or "resources"
    local line
    if effect.kind == "extraChance" then
        line = label .. string.format("%g%% chance of a free extra action's XP", value * 100)
    elseif effect.kind == "saveChance" and effect.saveQty ~= nil then
        line = label .. string.format("%g%% chance to save %d %s per action", value * 100, effect.saveQty, items)
    elseif effect.kind == "saveChance" then
        line = label .. string.format(KIND_TEXT.saveChance, math.floor(value * 100 + 0.5) .. "%", items)
    elseif effect.kind == "inputScale" and value == 0 then
        line = label .. string.format("no %s needed", items)
    elseif effect.kind == "inputScale" then
        line = label .. string.format(KIND_TEXT.inputScale, format.xp(value), items)
    elseif effect.kind == "multiplyBase" or effect.kind == "multiplier" or effect.kind == "addBase" then
        line = label .. string.format(KIND_TEXT[effect.kind], format.xp(value))
    else
        line = label .. string.format(KIND_TEXT[effect.kind], format.percent(value))
    end
    if effect.note ~= nil then
        line = line .. " - " .. effect.note
    end
    return line
end

--- Builds the full report. `info` fields:
---   skillName, startLevel, targetLabel   e.g. "Smithing", 60, "level 70"
--- Returns { headline = string, needs = {string}, reasons = {string} }
function report.build(result, info)
    local activity = result.activity
    local lines = { needs = {}, reasons = {} }

    if result.xpNeeded <= 0 then
        lines.headline = string.format("%s: you've already reached %s.", info.skillName, info.targetLabel)
        return lines
    end

    lines.headline = string.format("%s %d -> %s: %s XP to go",
        info.skillName, info.startLevel, info.targetLabel, format.number(result.xpNeeded))

    if info.startLevel < activity.level then
        table.insert(lines.needs, string.format("Note: needs level %d %s - you start at %d",
            activity.level, info.skillName, info.startLevel))
    end
    table.insert(lines.needs, string.format("%s x %s (%s XP each)",
        activity.name, format.number(result.actions), format.xp(result.xpPerAction)))
    for _, input in ipairs(result.inputs) do
        local line = string.format("%s %s - you have %s", format.number(input.needed), input.item, format.number(input.have))
        if input.short > 0 then
            line = line .. string.format(" (gather %s more)", format.number(input.short))
        end
        table.insert(lines.needs, line)
    end

    -- Why: list the effects in the order they were applied.
    table.insert(lines.reasons, string.format("Base XP: %s per action", format.xp(activity.xp)))
    for _, active in ipairs(result.activeEffects) do
        table.insert(lines.reasons, describeEffect(active))
    end
    if #result.activeEffects == 0 then
        table.insert(lines.reasons, "No bonuses detected.")
    end
    table.insert(lines.reasons, string.format("Total: %s XP per action (%s overall)",
        format.xp(result.xpPerAction), format.percent(math.floor(result.boostPercent * 10 + 0.5) / 10)))

    return lines
end

--- One short line for the on-screen overlay.
function report.overlayLine(result, info)
    if result.xpNeeded <= 0 then
        return string.format("%s: %s reached", info.skillName, info.targetLabel)
    end
    local input = result.inputs[1]
    if input == nil then
        return string.format("%s -> %s: %s x %s", info.skillName, info.targetLabel,
            format.number(result.actions), result.activity.name)
    end
    return string.format("%s -> %s: %s %s (have %s)", info.skillName, info.targetLabel,
        format.number(input.needed), input.item, format.number(input.have))
end

return report
