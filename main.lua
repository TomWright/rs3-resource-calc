-- Resource Calculator
-- A planner: pick a skill, an activity, a starting level and a goal, and it
-- tells you how many resources to gather to get there. It takes into account
-- the XP bonuses you'll use (outfits, urns, altars, Double XP...), which you
-- can set yourself or leave on "Auto" to use what you're wearing now.
--
-- Open it with "Calculate" on a skill's right-click menu, or from the
-- plugin's icon in the Plugins window.
--
-- File layout:
--   main.lua             wiring: game events, settings, refreshing the UI
--   src/game.lua         reads game state through the client API
--   src/effects.lua      decides which bonuses are in use
--   src/calculator.lua   the maths
--   src/report.lua       turns results into readable lines
--   src/view.lua         builds the panel, window and overlay
--   data/*.lua           skills, activities, bonuses and areas

local xp = require("src/xp")
local effects = require("src/effects")
local calculator = require("src/calculator")
local report = require("src/report")
local format = require("src/format")
local game = require("src/game")
local view = require("src/view")

local skills = require("data/skills")
local activities = require("data/activities")
local allEffects = require("data/effects")
local areas = require("data/areas")

xp.setEliteTable(skills.eliteXp)

-- How often (in server ticks, 0.6s each) to re-read equipment/surroundings.
local REFRESH_TICKS = 5

-- A "To" value up to this is a level; anything bigger is an XP amount.
local MAX_LEVEL_TARGET = 150

-- Bonus dropdown entries: "Auto", "Off", then the bonus's own options.
local STATE_AUTO, STATE_OFF, FIRST_OPTION = 1, 2, 3

---------------------------------------------------------------------------
-- Settings (saved between sessions with PersistentDB)
---------------------------------------------------------------------------

local SETTINGS_KEY = "settings"

local settings = PersistentDB:GetStructuredData(SETTINGS_KEY) or {}
settings.skill = settings.skill or "SMITHING"
settings.activity = settings.activity or 1
-- settings.fromLevel: level to plan from (nil = the player's current XP)
-- settings.toValue: the goal, a level or XP (nil = in-game target or next level)
settings.bonuses = settings.bonuses or {}   -- see src/effects.lua
settings.overlay = settings.overlay == true
-- Only list activities the start level allows (the "Hide items above my
-- level" tick box); on unless the player turned it off.
settings.hideLocked = settings.hideLocked ~= false
-- settings.windowPosition: where the window was last closed, { x =, y = }
-- (nil = centred)

local function saveSettings()
    PersistentDB:SetStructuredData(SETTINGS_KEY, settings)
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local panels = {}          -- open calculator panels (Plugins window, our window)
local window = nil         -- the plugin's own window, while open
local overlay = nil        -- on-screen line, created on first use
local context = {}         -- latest snapshot of game state (see effects.lua)
local ticksUntilRefresh = 0

-- Last known bank and metal bank contents. The server only sends these to
-- the client once they've been opened, so we remember them.
local storedCounts = { BANK = {}, METAL_BANK = {} }

local function currentSkill()
    return skills.byKey[settings.skill] or skills.list[1]
end

-- The plugin's window is titled with the skill it's planning.
local function windowTitle()
    return "Resource Calculator: " .. currentSkill().label
end

local function currentActivities()
    return activities[currentSkill().key] or {}
end

local function currentActivity()
    local list = currentActivities()
    return list[settings.activity] or list[1]
end

---------------------------------------------------------------------------
-- Reading the game
---------------------------------------------------------------------------

-- Which areas (data/areas.lua) contain the player's tile.
local function areasAt(coord)
    local inside = {}
    if coord == nil then
        return inside
    end
    for _, area in ipairs(areas.list) do
        if coord.x >= area.minX and coord.x <= area.maxX
            and coord.z >= area.minZ and coord.z <= area.maxZ
            and (area.level == nil or area.level == coord.level) then
            inside[area.id] = true
        end
    end
    return inside
end

-- Scenery names to look for, for the current activity only.
local function sceneryToFind(activity)
    local names, seen = {}, {}
    for _, effect in ipairs(allEffects) do
        if effect.detect.type == "nearby" and effects.appliesTo(effect, activity) then
            for _, name in ipairs(effect.detect.names) do
                if not seen[name] then
                    seen[name] = true
                    table.insert(names, name)
                end
            end
        end
    end
    return names
end

local function refreshContext()
    local activity = currentActivity()
    context = {
        worn = game.wornItems(),
        backpack = game.backpackCounts(),
        nearby = activity and game.nearbyScenery(sceneryToFind(activity)) or {},
        areas = areasAt(game.playerCoord()),
        bonuses = settings.bonuses,
    }
end

-- Resources owned: backpack plus the last known bank and metal bank contents.
local function ownedCounts()
    local owned = {}
    for _, counts in ipairs({ context.backpack or {}, storedCounts.BANK, storedCounts.METAL_BANK }) do
        for name, count in pairs(counts) do
            owned[name] = (owned[name] or 0) + count
        end
    end
    return owned
end

---------------------------------------------------------------------------
-- Start, goal and available activities
---------------------------------------------------------------------------

-- Where the plan starts: the "From" level if set, otherwise the player's
-- current XP. Returns start XP and start level, or nil if neither is known.
local function startFor(skill)
    if settings.fromLevel ~= nil then
        return xp.forLevel(settings.fromLevel, skill.curve), settings.fromLevel
    end
    if not game.isReady() then
        return nil
    end
    local currentXp = game.skillXp(skill.key)
    return currentXp, xp.levelFor(currentXp, skill.curve)
end

-- The goal, in order of preference: the "To" box, the target set in-game,
-- then the next level. Returns target XP and a label like "level 70".
local function targetFor(skill, startLevel)
    local value, source = settings.toValue, ""
    local isXp = value ~= nil and value > MAX_LEVEL_TARGET
    if value == nil then
        local gameTarget = game.skillTarget(skill.key)
        if gameTarget ~= nil then
            value, isXp, source = gameTarget.xp or gameTarget.level, gameTarget.xp ~= nil, " (game target)"
        end
    end
    if isXp then
        local target = math.min(value, xp.MAX_XP)
        return target, format.number(target) .. " XP" .. source
    end
    local level = value or (startLevel + 1)
    local label = "level " .. level .. source
    if level > skill.maxLevel then
        label = label .. " (virtual)"
    end
    return xp.forLevel(level, skill.curve), label
end

-- What an empty "To" box means right now, shown inside it.
local function toHint(skill)
    local gameTarget = game.isReady() and game.skillTarget(skill.key) or nil
    if gameTarget == nil then
        return "To: next level"
    elseif gameTarget.xp ~= nil then
        return "To: target " .. format.number(gameTarget.xp) .. " XP"
    end
    return "To: target level " .. gameTarget.level
end

-- The highest level listed activities can need: the start level, if known.
-- nil means no limit (unknown, or "Hide items above my level" is off).
local function levelLimit()
    if not settings.hideLocked then
        return nil
    end
    local _, startLevel = startFor(currentSkill())
    return startLevel
end

-- If the selected activity needs a higher level than the start level, picks
-- the highest-level activity that's available instead.
local function ensureAvailableActivity()
    local limit = levelLimit()
    local list = currentActivities()
    local selected = list[settings.activity]
    if limit == nil or (selected ~= nil and selected.level <= limit) then
        return
    end
    local best = nil
    for index, activity in ipairs(list) do
        if activity.level <= limit and (best == nil or activity.level > list[best].level) then
            best = index
        end
    end
    settings.activity = best or 1
end

---------------------------------------------------------------------------
-- Calculating and showing results
---------------------------------------------------------------------------

-- Runs the calculation and returns report lines and the overlay line (or nil
-- if there's nothing to plan from yet).
local function buildReport()
    local skill, activity = currentSkill(), currentActivity()
    if activity == nil then
        return nil
    end
    local startXp, startLevel = startFor(skill)
    if startXp == nil then
        return nil
    end
    local targetXp, targetLabel = targetFor(skill, startLevel)

    local result = calculator.calculate({
        activity = activity,
        currentXp = startXp,
        targetXp = targetXp,
        activeEffects = effects.activeFor(activity, allEffects, context),
        have = ownedCounts(),
    })
    local info = { skillName = skill.label, startLevel = startLevel, targetLabel = targetLabel }
    return report.build(result, info), report.overlayLine(result, info)
end

-- The Bonuses tab's entries for the current activity: each bonus with its
-- choices ("Auto (what's detected)", "Off", then its options).
local function bonusEntries()
    local entries = {}
    for _, effect in ipairs(effects.relevantTo(currentActivity(), allEffects)) do
        local key = effects.settingKey(effect)
        local options = effects.options(effect)
        local states = {}
        if effects.canDetect(effect) then
            local index, detail = effects.detect(effect, context)
            local seen = "not detected"
            if index ~= nil then
                seen = detail .. (effect.choices ~= nil and (", " .. options[index].label) or "")
            end
            table.insert(states, { label = "Auto: " .. seen, id = STATE_AUTO })
        end
        table.insert(states, { label = "Off", id = STATE_OFF })
        for index, option in ipairs(options) do
            table.insert(states, { label = option.label, id = FIRST_OPTION + index - 1 })
        end

        local setting = settings.bonuses[key]
        local current = STATE_OFF
        if setting == nil and effects.canDetect(effect) then
            current = STATE_AUTO
        elseif setting ~= nil and setting ~= effects.OFF then
            current = FIRST_OPTION + setting - 1
        end
        table.insert(entries, { key = key, name = effect.name, hint = effect.hint, states = states, current = current })
    end
    return entries
end

-- A short fingerprint of the Bonuses tab, so it's only rebuilt (and an open
-- dropdown reset) when something in it actually changed.
local function bonusSignature(entries)
    local parts = {}
    for _, entry in ipairs(entries) do
        table.insert(parts, entry.key .. "=" .. entry.current .. ":" .. entry.states[1].label)
    end
    return table.concat(parts, "|")
end

-- Updates every open panel and the overlay. Panels that fail to update are
-- dropped: usually they've been closed (their components destroyed), but the
-- reason is logged in case it's a real error.
local function refreshDisplay()
    local lines, overlayLine = buildReport()
    local entries = bonusEntries()
    local signature = bonusSignature(entries)
    local hint = toHint(currentSkill())
    for i = #panels, 1, -1 do
        local panel = panels[i]
        local ok, err = pcall(function()
            if lines ~= nil then
                view.showReport(panel, lines)
            end
            if panel.bonusSignature ~= signature then
                view.setBonuses(panel, entries)
                panel.bonusSignature = signature
            end
            view.setToHint(panel, hint)
        end)
        if not ok then
            log("Stopped updating a calculator panel: " .. tostring(err))
            table.remove(panels, i)
        end
    end
    if settings.overlay and lines ~= nil then
        overlay = overlay or view.buildOverlay()
        view.setOverlay(overlay, true, overlayLine)
    elseif overlay ~= nil then
        view.setOverlay(overlay, false)
    end
end

-- Refills every panel's group/activity dropdowns (after the skill or the
-- start level changes).
local function refreshActivityLists()
    ensureAvailableActivity()
    for _, panel in ipairs(panels) do
        pcall(view.setActivities, panel, currentActivities(), settings.activity, levelLimit())
    end
end

-- Prints the full report to the console (ALT + ` to open it).
local function logReport()
    local lines = buildReport()
    if lines == nil then
        return
    end
    log(lines.headline)
    for _, line in ipairs(lines.needs) do log("  " .. line) end
    for _, line in ipairs(lines.reasons) do log("  - " .. line) end
end

---------------------------------------------------------------------------
-- The calculator panel
---------------------------------------------------------------------------

local callbacks = {}

function callbacks.onActivity(index)
    settings.activity = index
    saveSettings()
    refreshContext()
    refreshDisplay()
end

function callbacks.onFrom(level)
    if level ~= nil and level < 1 then
        level = nil
    end
    settings.fromLevel = level
    saveSettings()
    refreshActivityLists()
    refreshDisplay()
end

function callbacks.onTo(value)
    if value ~= nil and value < 1 then
        value = nil
    end
    settings.toValue = value
    saveSettings()
    refreshDisplay()
end

function callbacks.onHideLocked(hide)
    settings.hideLocked = hide
    saveSettings()
    refreshActivityLists()
    refreshDisplay()
end

function callbacks.onBonus(key, stateId)
    if stateId == STATE_AUTO then
        settings.bonuses[key] = nil
    elseif stateId == STATE_OFF then
        settings.bonuses[key] = effects.OFF
    else
        settings.bonuses[key] = stateId - FIRST_OPTION + 1
    end
    saveSettings()
    refreshDisplay()
end

function callbacks.onOverlay(enabled)
    settings.overlay = enabled
    saveSettings()
    refreshDisplay()
end

-- Builds the calculator in `window` and fills it with the current settings.
local function addPanel(window)
    local panel = view.buildPanel(window, callbacks)
    table.insert(panels, panel)
    ensureAvailableActivity()
    view.setActivities(panel, currentActivities(), settings.activity, levelLimit())
    view.setInputs(panel, settings.fromLevel, settings.toValue, toHint(currentSkill()))
    view.setOverlayButton(panel, settings.overlay)
    view.setHideLocked(panel, settings.hideLocked)
    refreshContext()
    refreshDisplay()
    return panel
end

-- Forgets the window once it has closed (its X, or closeWindow below), so its
-- panel stops being updated, and remembers where it was.
local function onWindowClosed(position)
    if window == nil then
        return
    end
    for i, panel in ipairs(panels) do
        if panel == window.panel then
            table.remove(panels, i)
            break
        end
    end
    window = nil
    if position ~= nil then
        settings.windowPosition = position
        saveSettings()
    end
end

local function closeWindow()
    if window ~= nil then
        pcall(view.closeWindow, window)
        onWindowClosed(nil) -- in case closing failed part way
    end
end

-- The calculator window, opened for a skill (from "Calculate" on its
-- right-click menu, or the Plugins window's button).
local function openWindow(skillKey)
    closeWindow()
    if skillKey ~= settings.skill then
        settings.skill = skillKey
        settings.activity = 1
        saveSettings()
    end
    window = view.buildWindow({
        title = windowTitle(),
        position = settings.windowPosition,
        onClose = onWindowClosed,
    })
    if window ~= nil then
        window.panel = addPanel(window)
    end
end

-- The Plugins window (ribbon icon): how to open the calculator, and a button
-- to open it for the last skill used. The full plan is also printed to the
-- console.
Event.ContentLayerReady.Subscribe("resourceCalcPanel", function(event)
    view.buildLauncher(event.component, currentSkill().label, function()
        openWindow(settings.skill)
    end)
    logReport()
end)

---------------------------------------------------------------------------
-- "Calculate" on a skill's right-click menu
---------------------------------------------------------------------------

-- The Skills tab's right-click entries ("View Skillguide", "Set Level Target"
-- ...) don't name the skill, so each skill is recognised by the entries'
-- subjectHash instead, which is the same for every entry on one skill's
-- button. The values were found by logging entry.subjectHash in
-- Event.MiniMenuOpened while right-clicking each skill.
local SKILLS_TAB_HASHES = {
    [96075808] = "SMITHING",
    [96075818] = "HERBLORE",
    [96075838] = "COOKING",
    [96075843] = "PRAYER",
    [96075848] = "CRAFTING",
    [96075853] = "FIREMAKING",
    [96075863] = "FLETCHING",
}

-- The skill a menu entry is about, if it's on a skill's button in the Skills
-- tab and the plugin has activities for that skill.
local function skillForEntry(entry)
    if entry.actionEntryType ~= MiniMenuEntryType.INTERFACE then
        return nil
    end
    local key = SKILLS_TAB_HASHES[entry.subjectHash]
    if key == nil or activities[key] == nil then
        return nil
    end
    return skills.byKey[key]
end

-- Adds "Calculate" once per menu. It only opens this plugin's window;
-- nothing is sent to the game server. menu.entries runs from the bottom of
-- the menu to the top, and Add puts the new entry at the very bottom
-- (entries[1], below "Cancel"). It's moved up one place at a time, so the
-- other entries keep their order, until it's second from the top: just
-- below the skill's normal left-click action, which stays the same.
Event.MiniMenuReady.Subscribe("resourceCalcMenu", function(event)
    local menu = event.miniMenu
    for _, entry in ipairs(menu.entries) do
        local skill = skillForEntry(entry)
        if skill ~= nil then
            menu:Add("Calculate <col=ff9040>" .. skill.label .. "</col>", openWindow, skill.key)
            for index = 1, menu.entryCount - 2 do
                menu:Swap(index, index + 1)
            end
            return
        end
    end
end)

---------------------------------------------------------------------------
-- Game events
---------------------------------------------------------------------------

-- True while a panel or the overlay is on screen; no point working otherwise.
local function isShowing()
    return #panels > 0 or settings.overlay
end

-- Every few server ticks: re-read gear and surroundings (you may have put on
-- an outfit or walked up to an altar) and update what's shown.
Event.ServerLogic.Subscribe("resourceCalcTick", function()
    ticksUntilRefresh = ticksUntilRefresh - 1
    if ticksUntilRefresh <= 0 and isShowing() and game.isReady() then
        ticksUntilRefresh = REFRESH_TICKS
        refreshContext()
        refreshDisplay()
    end
end)

-- XP changed: when planning from the current XP, keep "XP to go" up to date
-- (and a level-up may unlock new activities).
Event.SkillTransmit.Subscribe("resourceCalcXp", function(event)
    if settings.fromLevel == nil and isShowing() and game.skillKeyFromId(event.skill) == currentSkill().key then
        if event.newGameplayLevel ~= event.oldGameplayLevel then
            refreshActivityLists()
        end
        refreshDisplay()
    end
end)

-- Returns true if an inventory event is about the named inventory.
local function isInventory(eventInv, configName)
    local ok, same = pcall(function() return eventInv.id == config.Inv[configName].id end)
    return ok and same
end

-- Backpack, bank or metal bank changed: update the "you have" counts. The bank
-- and metal bank are remembered, since they're only sent once opened.
local function onInventoryChanged(event)
    if isInventory(event.inv, "INV") then
        context.backpack = game.backpackCounts()
        if isShowing() then
            refreshDisplay()
        end
        return
    end
    for invName in pairs(storedCounts) do
        if isInventory(event.inv, invName) then
            storedCounts[invName] = game.storedCounts(invName) or storedCounts[invName]
            refreshDisplay()
            return
        end
    end
end
Event.InventoryAdded.Subscribe("resourceCalcInvAdded", onInventoryChanged)
Event.InventoryUpdated.Subscribe("resourceCalcInvUpdated", onInventoryChanged)

-- Called by the client when the plugin is turned off or the game closes.
function PluginShutdown()
    saveSettings()
    closeWindow()
end

-- On load, show the overlay if it was left on, and print the current plan.
if game.isReady() then
    refreshContext()
    ensureAvailableActivity()
    refreshDisplay()
    logReport()
    -- Development aid: checks game.lua reads skill targets correctly.
    log("In-game skill targets: " .. game.describeSkillTargets())
end
log("Resource Calculator loaded. Right-click a skill and choose Calculate.")
