-- smoke_test.lua
-- Loads main.lua against the fake client in mock_client.lua and plays through
-- a session: right-click Smithing > Calculate, plan 60 -> 70 smelting gold,
-- choose a full outfit, plan smithing items, reopen the window for another
-- skill, use the Plugins window's button, show the overlay, close the window.
-- The interface is built with a fake PrettyUI (see mock_client.lua).
-- Catches wiring mistakes (typos, nil access) that unit tests can't.
-- Run from the plugin folder:  lua tests/smoke_test.lua

package.path = "./?.lua;" .. package.path

local mock = require("tests/mock_client")
mock.install()

local function check(condition, message)
    if not condition then
        error("FAIL: " .. message, 2)
    end
end

-- Returns the content of the first live Text component whose content matches.
local function findText(pattern)
    for _, text in ipairs(mock.find("Text")) do
        if mock.isLive(text) and type(text.content) == "string" and text.content:find(pattern) then
            return text.content
        end
    end
    return nil
end

local function findInput(emptyText)
    for _, input in ipairs(mock.find("InputField")) do
        if input.emptyText == emptyText then return input end
    end
end

-- 1. A level 1 character wearing two Blacksmith's outfit pieces.
mock.xp[13] = 0
mock.inventories.WORN = { ["Blacksmith's top"] = 1, ["Blacksmith's apron"] = 1 }
mock.inventories.INV = { ["Gold ore"] = 28 }
dofile("main.lua")
check(#mock.logs > 0, "plugin logged on load")

-- 2. Right-clicking something that isn't a skill adds nothing.
local menu = mock.rightClick({ { "Walk here", "", MiniMenuEntryType.NONE } })
check(#menu.added == 0, "no Calculate on a non-skill menu")

-- 3. Right-click Smithing in the Skills tab (entries as the real client
-- showed them): "Calculate" is added second, so the normal left-click
-- action stays on top.
local SMITHING_HASH = 96075808
menu = mock.rightClick({
    { "Cancel", "", MiniMenuEntryType.NONE },
    { "Set XP Target", "", MiniMenuEntryType.INTERFACE, SMITHING_HASH },
    { "Set Level Target", "", MiniMenuEntryType.INTERFACE, SMITHING_HASH },
    { "View Skillguide", "", MiniMenuEntryType.INTERFACE, SMITHING_HASH },
})
check(#menu.added == 1, "Calculate added once")
check(menu.added[1].label:find("Calculate") ~= nil, "labelled Calculate")
check(menu.entries[#menu.entries].verbText == "View Skillguide", "left-click action unchanged")
check(menu.entries[#menu.entries - 1].verbText:find("Calculate") ~= nil, "Calculate is second from the top")
check(menu.entries[1].verbText == "Cancel" and menu.entries[2].verbText == "Set XP Target",
    "other entries keep their order")

-- 3b. Another skill's button that isn't known yet adds nothing.
local otherMenu = mock.rightClick({ { "View Skillguide", "", MiniMenuEntryType.INTERFACE, 12345 } })
check(#otherMenu.added == 0, "no Calculate for an unknown hash")

-- 4. Choosing it opens the window with the calculator for Smithing.
menu.added[1].fn(table.unpack(menu.added[1].args))
local windows = mock.find("Window")
check(#windows == 1, "window opened")
check(windows[1].title == "Resource Calculator: Smithing", "window titled with the skill")
check(windows[1].options.xAnchor == 0.5, "opens in the middle of the screen the first time")
check(mock.findList("Prayer") == nil, "no skill dropdown in the window")
check(findText("Smithing 1 %-> level 2") ~= nil, "plans from the current level")
-- The dropdowns show the right selection (the client selects by position).
check(mock.shown(mock.findList("Smelting")) == "Smelting", "group dropdown shows Smelting")
check(mock.shown(mock.findList("Bronze bar")) == "Bronze bar", "activity dropdown shows Bronze bar")

-- 5. At level 1 only level-1 activities are offered.
local activityList = mock.findList("Bronze bar")
check(activityList ~= nil, "bronze bar offered")
check(mock.entryId(activityList, "Iron bar") == nil, "iron bar (level 10) hidden at level 1")
check(mock.findList("Bronze items") ~= nil, "group dropdown lists the metals")

-- 5b. "Hide items above my level" is ticked by default. Unticking it lists
-- everything, to plan ahead; the plan then notes the level needed.
local hideBox = mock.find("Checkbox")[1]
check(hideBox.label == "Hide items above my level" and hideBox.selected == true, "hide tick box on by default")
mock.tick(hideBox, false)
check(mock.db.settings.hideLocked == false, "setting saved")
check(mock.findList("Necronium items") ~= nil, "all metals listed")
check(mock.entryId(mock.findList("Bronze bar"), "Iron bar") ~= nil, "iron bar listed at level 1")
local everything = mock.findList("Necronium items")
mock.select(everything, mock.entryId(everything, "Necronium items"))
check(findText("needs level 70 Smithing") ~= nil, "plan notes the level needed")
mock.tick(hideBox, true)
check(mock.findList("Necronium items") == nil, "ticked again: hidden")
check(mock.shown(mock.findList("Bronze items")) ~= "Necronium items", "a hidden selection is replaced")

-- 6. Plan from 60 to 70: gold bars (level 40) become available.
mock.type(findInput("From: current"), 60)
local groupList = mock.findList("Smelting")
mock.select(groupList, mock.entryId(groupList, "Smelting"))
activityList = mock.findList("Gold bar")
check(activityList ~= nil, "gold bar offered at 60")
check(mock.entryId(activityList, "Necronium bar") == nil, "necronium bar (level 70) still hidden")
mock.select(activityList, mock.entryId(activityList, "Gold bar"))
local toInput = findInput("To: next level")
check(toInput ~= nil, "empty To box explains it means the next level")
mock.type(toInput, 70)
check(findText("Smithing 60 %-> level 70: 463,885 XP to go") ~= nil, "plans 60 -> 70")

-- 6b. A level 75 target set in-game (STATS_TARG_14 is Smithing's) is used
-- when the To box is empty, and the empty box says so.
mock.varps.STATS_TARG_14 = 75
mock.type(toInput, 0)
check(findText("Smithing 60 %-> level 75 %(game target%)") ~= nil, "plans to the in-game target")
check(toInput.emptyText == "To: target level 75", "empty To box names the game target")
mock.varps.STATS_TARG_14 = 0
mock.type(toInput, 70)
-- Auto: 2 outfit pieces worn = +2%: 7.14 XP per bar.
check(findText("64,970 Gold ore %- you have 28 %(gather 64,942 more%)") ~= nil, "resources with worn gear")
print(findText("Gold ore"))

-- 7. Bonuses tab: a row per bonus, each showing its setting. Plan with the
-- full outfit instead of what's worn.
check(findText("^Blacksmith's outfit$") ~= nil, "outfit has a row on the Bonuses tab")
local stateList = mock.findList("Full set (5/5)")
check(stateList ~= nil, "outfit options listed")
check(mock.shown(stateList) == "Auto: 2/5 pieces worn", "the row shows Auto and what's worn")
check(findText("^Double XP$") ~= nil, "Double XP has its own row")
local doubleXpRows = 0
for _, combo in ipairs(mock.find("List")) do
    if mock.entryId(combo, "On") ~= nil and mock.isLive(combo) and not combo.root.hidden then
        doubleXpRows = doubleXpRows + 1
        check(mock.shown(combo) == "Off" and combo.tooltip == "Double XP is live", "Double XP row: Off, with its hint")
    end
end
check(doubleXpRows == 1, "one Double XP setting")
mock.select(stateList, mock.entryId(stateList, "Full set (5/5)"))
check(findText("62,519 Gold ore") ~= nil, "full outfit: 7.42 XP per bar")
check(findText("Blacksmith's outfit %(Full set %(5/5%)%): %+6%%") ~= nil, "Why tab explains it")
print(findText("Base XP"))

-- 7b. Smithing items: pick the metal, the item, then how far to take it
-- ("Make"). Still 60 -> 70 (463,885 XP) with the full outfit (+6%).
local metalList = mock.findList("Adamant items")
mock.select(metalList, mock.entryId(metalList, "Adamant items"))
local itemList = mock.findList("Platebody or chainbody (5 bars)")
mock.select(itemList, mock.entryId(itemList, "Platebody or chainbody (5 bars)"))
local tierList = mock.findList("+2")
check(tierList ~= nil and tierList.root.hidden == false, "Make dropdown shown for adamant")
check(mock.entryId(tierList, "+3") == nil and mock.entryId(tierList, "Burial") ~= nil, "adamant goes to +2, then burial")
mock.select(tierList, mock.entryId(tierList, "+2"))
-- 20 bars and 3,400 XP each, x1.06 = 3,604: 129 platebodies.
check(findText("Adamant platebody or chainbody %+2 x 129 %(3,604 XP each%)") ~= nil, "plans platebodies +2")
check(findText("2,580 Adamant bar") ~= nil, "counted in bars")
mock.select(itemList, mock.entryId(itemList, "Platelegs or plateskirt (3 bars)"))
check(findText("Adamant platelegs or plateskirt %+2 x") ~= nil, "another item keeps the +2 tier")
-- A burial set has only one way to make it, so Make is hidden.
mock.select(itemList, mock.entryId(itemList, "Burial set (helm, body, legs, gauntlets, boots)"))
check(tierList.root.hidden == true, "Make hidden for burial sets")
-- 12,444 XP x1.06 = 13,190.6 per set: 36 sets, 1,728 bars.
check(findText("Adamant burial set x 36") ~= nil and findText("1,728 Adamant bar") ~= nil, "plans burial sets")
-- Solemn Smith V: 12,648 XP x1.06 = 13,406.9 per set: 35 sets.
local solemnStates = mock.findList("Solemn Smith V")
check(solemnStates ~= nil and not solemnStates.root.hidden, "Solemn Smith row shown for burial sets")
mock.select(solemnStates, mock.entryId(solemnStates, "Solemn Smith V"))
check(findText("Adamant burial set x 35") ~= nil, "Solemn Smith counted")
-- Back to platelegs: Solemn Smith doesn't apply, so its row is hidden.
mock.select(itemList, mock.entryId(itemList, "Platelegs or plateskirt (3 bars)"))
check(solemnStates.root.hidden == true, "rows for bonuses that don't apply are hidden")

-- 8. Calculate on another skill reopens the window for that skill, where
-- the player had moved it to.
windows[1].root.x, windows[1].root.y = 120, 80 -- dragged there
local craftingMenu = mock.rightClick({ { "View Skillguide", "", MiniMenuEntryType.INTERFACE, 96075848 } })
craftingMenu.added[1].fn(table.unpack(craftingMenu.added[1].args))
windows = mock.find("Window")
check(#windows == 2 and windows[1].destroyed, "old window closed")
check(windows[2].title == "Resource Calculator: Crafting", "window reopened for Crafting")
check(mock.db.settings.windowPosition.x == 120 and mock.db.settings.windowPosition.y == 80, "position saved")
check(windows[2].options.x == 120 and windows[2].options.xAnchor == 0, "reopened where it was")
check(mock.findList("Opal") ~= nil, "crafting activities")
check(mock.findList("Bronze bar") == nil, "smithing activities gone")

-- 8b. The Plugins window explains how to open the calculator, and its button
-- opens it for the last skill used.
mock.fire("ContentLayerReady", { component = mock.stub("pluginsWindow") })
check(findText("choose Calculate") ~= nil, "Plugins window explains how to open it")
local openButton
for _, button in ipairs(mock.find("Button")) do
    if button.label == "Open Crafting" then openButton = button end
end
mock.press(openButton)
windows = mock.find("Window")
check(#windows == 3 and windows[2].destroyed and not windows[3].destroyed, "button reopens the window")

-- 9. Show on screen.
local overlayButton
for _, button in ipairs(mock.find("Button")) do
    if button.label == "Show on screen" and mock.isLive(button) then overlayButton = button end
end
mock.press(overlayButton)
check(mock.db.settings.overlay == true, "overlay setting saved")

-- 10. Close the window, then shut down.
windows[3]:Close()
check(windows[3].destroyed, "window closed")
PluginShutdown()
check(mock.db.settings.skill == "CRAFTING", "settings saved on shutdown")
for _, line in ipairs(mock.logs) do
    check(not line:find("Stopped updating"), "no errors logged: " .. line)
end

print("smoke test passed")
