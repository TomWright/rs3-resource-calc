-- run_tests.lua
-- Unit tests for the pure-Lua parts of the plugin (no game client needed),
-- run against the real data files so they also check the bonus data.
-- Run from the plugin folder with any Lua 5.4 interpreter:
--     lua tests/run_tests.lua
-- This folder is for development only; leave it out of the uploaded zip.

package.path = "./?.lua;" .. package.path

local passed, failed = 0, 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL " .. name .. "\n     " .. tostring(err))
    end
end

local function eq(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", label or "value", tostring(expected), tostring(actual)), 2)
    end
end

local function near(actual, expected, label)
    if math.abs(actual - expected) > 1e-6 then
        error(string.format("%s: expected %s, got %s", label or "value", tostring(expected), tostring(actual)), 2)
    end
end

local xp = require("src/xp")
local effects = require("src/effects")
local calculator = require("src/calculator")
local report = require("src/report")
local format = require("src/format")

local skills = require("data/skills")
local activities = require("data/activities")
local allEffects = require("data/effects")
local areas = require("data/areas")

xp.setEliteTable(skills.eliteXp)

-- Finds an activity by skill and name.
local function activity(skill, name)
    for _, a in ipairs(activities[skill]) do
        if a.name == name then return a end
    end
    error("no activity " .. name)
end

-- XP per action for an activity in a given context.
local function xpFor(act, context)
    local active = effects.activeFor(act, allEffects, context)
    return calculator.xpPerAction(act, active), active
end

-- Settings that switch bonuses on with their default option, e.g.
-- on("double_xp", "clan_avatar"). (Settings: nil = Auto, 0 = Off, n = option n.)
local function on(...)
    local bonuses = {}
    for _, id in ipairs({ ... }) do
        for _, e in ipairs(allEffects) do
            if e.id == id or effects.settingKey(e) == id then
                bonuses[effects.settingKey(e)] = e.defaultChoice or 1
            end
        end
    end
    return bonuses
end

local function activeIds(active)
    local ids = {}
    for _, result in ipairs(active) do ids[result.effect.id] = true end
    return ids
end

local BLACKSMITH = {
    ["Blacksmith's helmet"] = true, ["Blacksmith's top"] = true, ["Blacksmith's apron"] = true,
    ["Blacksmith's gloves"] = true, ["Blacksmith's boots"] = true,
}
local FIRST_AGE = {
    ["First age tiara"] = true, ["First age amulet"] = true, ["First age cape"] = true,
    ["First age ring"] = true, ["First age bracelet"] = true,
}
local function with(set, extra)
    local copy = {}
    for k, v in pairs(set) do copy[k] = v end
    for k, v in pairs(extra or {}) do copy[k] = v end
    return copy
end

local goldBar = activity("SMITHING", "Gold bar")
local ironBar = activity("SMITHING", "Iron bar")
local corrupted = activity("SMITHING", "Corrupted ore (Prifddinas)")
local dragonBones = activity("PRAYER", "Dragon bones")
local infernal = activity("PRAYER", "Infernal ashes")

-- XP curve ---------------------------------------------------------------

test("standard curve matches known values", function()
    eq(xp.forLevel(1), 0, "level 1")
    eq(xp.forLevel(2), 83, "level 2")
    eq(xp.forLevel(50), 101333, "level 50")
    eq(xp.forLevel(99), 13034431, "level 99")
    eq(xp.forLevel(110), 38737661, "level 110")
    eq(xp.forLevel(120), 104273167, "level 120")
end)

test("elite curve matches known values", function()
    eq(xp.forLevel(2, "elite"), 830, "level 2")
    eq(xp.forLevel(99, "elite"), 36073511, "level 99")
    eq(xp.forLevel(120, "elite"), 80618654, "level 120")
    eq(xp.levelFor(80618654, "elite"), 120, "levelFor 120")
end)

test("levelFor inverts forLevel", function()
    eq(xp.levelFor(0), 1, "0 xp")
    eq(xp.levelFor(82), 1, "82 xp")
    eq(xp.levelFor(83), 2, "83 xp")
    eq(xp.levelFor(13034430), 98, "just under 99")
    eq(xp.levelFor(13034431), 99, "99 exact")
end)

test("XP is capped at 200M", function()
    eq(xp.forLevel(127), xp.MAX_XP, "past the table")
end)

-- Data checks --------------------------------------------------------------

test("every effect is well formed", function()
    local kinds, ids = {}, {}
    for _, kind in ipairs(effects.KIND_ORDER) do kinds[kind] = true end
    local detectTypes = { set = true, worn = true, backpack = true, carried = true, nearby = true, area = true, toggle = true }
    for _, e in ipairs(allEffects) do
        local label = tostring(e.id)
        assert(not ids[e.id], "duplicate id " .. label)
        ids[e.id] = true
        assert(type(e.name) == "string", label .. " has no name")
        assert(kinds[e.kind], label .. " has unknown kind " .. tostring(e.kind))
        assert(detectTypes[e.detect.type], label .. " has unknown detect type")
        assert(e.value ~= nil or e.choices ~= nil or e.detect.type == "set", label .. " has no value")
        if e.choices then
            assert(e.choices[e.defaultChoice or 1] ~= nil, label .. " has a bad defaultChoice")
        end
    end
    for _, e in ipairs(allEffects) do
        for _, other in ipairs(e.cancels or {}) do
            assert(ids[other], e.id .. " cancels unknown effect " .. other)
        end
    end
end)

test("skill-specific bonuses never apply to other skills", function()
    -- Tags are shared between skills, so a reused tag name could leak a
    -- bonus across skills. Effects named after a skill must stay in it.
    local prefixes = {
        cooking = "COOKING", firemaking = "FIREMAKING", herblore = "HERBLORE",
        crafting = "CRAFTING", fletching = "FLETCHING", smithing = "SMITHING", prayer = "PRAYER",
    }
    for _, e in ipairs(allEffects) do
        local prefix = e.id:match("^(%a+)_") or ""
        local own = prefixes[prefix] or prefixes[e.id:match("^brawling_(%a+)$") or ""]
        if own ~= nil then
            for skill, list in pairs(activities) do
                if skill ~= own then
                    for _, a in ipairs(list) do
                        assert(not effects.appliesTo(e, a), e.id .. " applies to " .. skill .. " activity " .. a.name)
                    end
                end
            end
        end
    end
end)

test("every bonus has options to choose from", function()
    for _, e in ipairs(allEffects) do
        local options = effects.options(e)
        assert(#options > 0, e.id .. " has no options")
        for _, option in ipairs(options) do
            assert(type(option.label) == "string", e.id .. " has an option without a label")
        end
    end
end)

test("every activity is well formed", function()
    for skill, list in pairs(activities) do
        assert(skills.byKey[skill], "unknown skill " .. skill)
        for _, a in ipairs(list) do
            assert(a.skill == skill, a.name .. " is filed under the wrong skill")
            assert(type(a.xp) == "number" and a.xp > 0, a.name .. " has no XP")
            -- Inputs may be empty (e.g. playing a harp uses nothing up).
            assert(type(a.inputs) == "table", a.name .. " has no inputs list")
            for _, input in ipairs(a.inputs) do
                assert(type(input.item) == "string" and input.qty > 0, a.name .. " has a bad input")
            end
        end
    end
end)

-- Bonus settings: Auto / Off / a chosen option -------------------------------

test("Auto uses what's worn; Off overrides it", function()
    near(xpFor(goldBar, { worn = BLACKSMITH }).xpPerAction, 7 * 1.06, "auto, full set worn")
    near(xpFor(goldBar, { worn = BLACKSMITH, bonuses = { blacksmiths_outfit = effects.OFF } }).xpPerAction,
        7, "turned off")
end)

test("a chosen number of outfit pieces counts without wearing them", function()
    -- options: 1/5 .. 4/5 pieces, then the full set
    near(xpFor(goldBar, { bonuses = { blacksmiths_outfit = 3 } }).xpPerAction, 7 * 1.03, "3 pieces")
    near(xpFor(goldBar, { bonuses = { blacksmiths_outfit = 5 } }).xpPerAction, 7 * 1.06, "full set")
end)

test("set options and detection line up", function()
    local outfit
    for _, e in ipairs(allEffects) do
        if e.id == "blacksmiths_outfit" then outfit = e end
    end
    local options = effects.options(outfit)
    eq(#options, 5, "one option per piece count")
    eq(options[5].label, "Full set (5/5)", "full set label")
    local index, detail = effects.detect(outfit, { worn = { ["Blacksmith's top"] = true, ["Blacksmith's boots"] = true } })
    eq(index, 2, "2 pieces worn = option 2")
    eq(detail, "2/5 pieces worn", "detail")
end)

test("a chosen altar counts without standing next to it", function()
    near(xpFor(dragonBones, { bonuses = { gilded_altar = 3 } }).xpPerAction, 72 * 3.5, "planned gilded altar")
    near(xpFor(dragonBones, { bonuses = { chaos_altar = 5 } }).xpPerAction, 72 * 3.5, "planned chaos altar")
end)

test("bonuses the plugin can't see are off until chosen", function()
    near(xpFor(corrupted, {}).xpPerAction, 160, "no urn or Voice of Seren")
    near(xpFor(corrupted, { bonuses = { smithing_urn = 3 } }).xpPerAction, 160 * 1.25, "exquisite urn")
end)

-- Smithing bonuses ---------------------------------------------------------

test("full Blacksmith's outfit gives +6%", function()
    local rates = xpFor(goldBar, { worn = BLACKSMITH })
    near(rates.xpPerAction, 7 * 1.06, "gold bar")
end)

test("partial outfit gives 1% per piece, no set bonus", function()
    local rates = xpFor(goldBar, { worn = { ["Blacksmith's top"] = true, ["Smelting gauntlets"] = true } })
    near(rates.xpPerAction, 7 * 1.02, "2 pieces")
end)

test("outfit, avatar and Double XP stack in stages", function()
    local rates = xpFor(goldBar, { worn = BLACKSMITH, bonuses = on("clan_avatar", "double_xp") })
    -- (7 x 1.06) x 1.06 avatar (default 6%) + 7 Double XP
    near(rates.xpPerAction, 7 * 1.06 * 1.06 + 7, "staged")
end)

test("brawling gloves multiply, but not during Double XP", function()
    local worn = with(BLACKSMITH, { ["Brawling gloves (Smithing)"] = true, ["Blacksmith's gloves"] = false })
    -- 4 outfit pieces (gloves slot taken) = +4%, then x1.5
    near(xpFor(goldBar, { worn = worn }).xpPerAction, 7 * 1.04 * 1.5, "gloves")
    local _, active = xpFor(goldBar, { worn = worn, bonuses = on("double_xp") })
    eq(activeIds(active).brawling_smithing, nil, "cancelled by Double XP")
end)

test("Voice of Seren and urn on corrupted ore", function()
    local rates = xpFor(corrupted, { bonuses = on("vos_trahaearn", "smithing_urn") })
    -- base 160 x 1.2 = 192, plus 20% of that from the urn
    near(rates.baseXp, 192, "boosted base")
    near(rates.xpPerAction, 192 + 192 * 0.2, "with urn")
end)

test("Voice of Seren only applies to corrupted ore", function()
    near(xpFor(goldBar, { bonuses = on("vos_trahaearn") }).xpPerAction, 7, "gold bar unaffected")
end)

test("Ring of forging halves iron ore", function()
    local active = effects.activeFor(ironBar, allEffects, { worn = { ["Ring of forging"] = true } })
    local result = calculator.calculate({ activity = ironBar, currentXp = 0, targetXp = 200, activeEffects = active })
    eq(result.actions, 100, "100 bars")
    eq(result.inputs[1].needed, 100, "100 iron ore, not 200")
end)

-- Prayer bonuses -----------------------------------------------------------

test("gilded altar with 2 burners is 3.5x, plus outfit", function()
    local rates = xpFor(dragonBones, { worn = FIRST_AGE, nearby = { ["Gilded altar"] = true } })
    near(rates.xpPerAction, 72 * 3.5 * 1.06, "altar")
end)

test("burner choice changes the altar multiplier", function()
    local rates = xpFor(dragonBones, { nearby = { ["Gilded altar"] = true }, bonuses = { gilded_altar = 1 } })
    near(rates.xpPerAction, 72 * 2.5, "no burners")
end)

test("altars switch off Double XP and the Dragon Rider amulet", function()
    local _, active = xpFor(dragonBones, {
        worn = { ["Dragon Rider amulet"] = true }, nearby = { ["Gilded altar"] = true }, bonuses = on("double_xp"),
    })
    local ids = activeIds(active)
    eq(ids.gilded_altar, true, "altar active")
    eq(ids.double_xp, nil, "no Double XP")
    eq(ids.dragon_rider_amulet, nil, "no amulet")
end)

test("Ectofuntus blocks every other bonus and needs slime and pots", function()
    local _, active = xpFor(dragonBones, {
        worn = FIRST_AGE, nearby = { Ectofuntus = true }, bonuses = on("clan_avatar"),
    })
    eq(#active, 1, "only the Ectofuntus")
    local result = calculator.calculate({ activity = dragonBones, currentXp = 0, targetXp = 2880, activeEffects = active })
    eq(result.actions, 10, "288 XP each")
    eq(#result.inputs, 3, "bones, pot, slime")
    eq(result.inputs[3].item, "Bucket of slime", "slime")
end)

test("Ectofuntus for ashes needs no pot", function()
    local _, active = xpFor(infernal, { nearby = { Ectofuntus = true } })
    local result = calculator.calculate({ activity = infernal, currentXp = 0, targetXp = 250, activeEffects = active })
    eq(#result.inputs, 2, "ashes and slime")
end)

test("Dragon Rider amulet replaces powder of burials", function()
    local rates = xpFor(dragonBones, { worn = { ["Dragon Rider amulet"] = true }, bonuses = on("powder_of_burials") })
    near(rates.xpPerAction, 144, "2x, not 3.5x")
end)

test("powder of burials doesn't work on ashes", function()
    near(xpFor(infernal, { bonuses = on("powder_of_burials") }).xpPerAction, 62.5, "unchanged")
end)

test("chaos altar needs the Wilderness and is cancelled by brawling gloves", function()
    local nearby = { ["Chaos altar"] = true }
    near(xpFor(dragonBones, { nearby = nearby }).xpPerAction, 72, "not in the Wilderness")
    local wild = { [areas.WILDERNESS.id] = true }
    near(xpFor(dragonBones, { nearby = nearby, areas = wild, bonuses = { chaos_altar = 5 } }).xpPerAction,
        72 * 3.5, "elite achievements")
    near(xpFor(dragonBones, { nearby = nearby, areas = wild, worn = { ["Brawling gloves (Prayer)"] = true } }).xpPerAction,
        72 * 1.5, "gloves win")
end)

test("modified first age tiara saves 2% of bones", function()
    local worn = with(FIRST_AGE, { ["First age tiara"] = false, ["Modified first age tiara"] = true })
    local active = effects.activeFor(dragonBones, allEffects, { worn = worn })
    local result = calculator.calculate({ activity = dragonBones, currentXp = 0, targetXp = 72 * 1.06 * 1000, activeEffects = active })
    eq(result.actions, 1000, "actions")
    eq(result.inputs[1].needed, 980, "bones")
end)

-- Cooking bonuses ----------------------------------------------------------

local SOUS_CHEF = {
    ["Sous chef's toque"] = true, ["Sous chef's jacket"] = true, ["Sous chef's trousers"] = true,
    ["Sous chef's mitts"] = true, ["Sous chef's shoes"] = true,
}

test("lobster on a bonfire with the army axe and full outfit", function()
    local lobster = activity("COOKING", "Lobster")
    local rates = xpFor(lobster, {
        worn = SOUS_CHEF, backpack = { ["Dwarven army axe"] = 1 }, bonuses = on("cooking_bonfire"),
    })
    -- (120 x 1.1 bonfire + 3 axe) x 1.06 outfit
    near(rates.xpPerAction, (120 * 1.1 + 3) * 1.06, "lobster")
end)

test("kitchen and port workshop add together on soup (wiki: 600 -> 750)", function()
    local soup = activity("COOKING", "Sailfish soup")
    local rates = xpFor(soup, {
        areas = { [areas.FORT_KITCHEN.id] = true },
        bonuses = on("cooking_fort_kitchen", "cooking_port_workshop"),
    })
    near(rates.xpPerAction, 750, "soup")
end)

test("a chosen kitchen bonus counts when planning from anywhere", function()
    local soup = activity("COOKING", "Sailfish soup")
    near(xpFor(soup, { bonuses = on("cooking_fort_kitchen") }).xpPerAction, 630, "planned")
end)

test("wine doesn't fill cooking urns or get the army axe", function()
    local wine = activity("COOKING", "Jug of wine")
    local rates = xpFor(wine, { worn = { ["Dwarven army axe"] = true }, bonuses = on("cooking_urn") })
    near(rates.xpPerAction, 201, "wine")
end)

-- Firemaking bonuses -------------------------------------------------------

test("magic logs on a busy bonfire with the Fired up set (wiki: 338)", function()
    local magic = activity("FIREMAKING", "Magic logs (bonfire)")
    local rates = xpFor(magic, {
        worn = { ["Ring of fire"] = true, ["Flame gloves"] = true }, bonuses = on("firemaking_bonfire"),
    })
    near(rates.xpPerAction, 309.5 * 1.04 * 1.05, "magic")
end)

test("one Fired up piece gives 2%, no set bonus", function()
    local magic = activity("FIREMAKING", "Magic logs (lighting)")
    near(xpFor(magic, { worn = { ["Ring of fire"] = true } }).xpPerAction, 303.8 * 1.02, "ring only")
end)

test("flat XP from a familiar and the army axe", function()
    local logs = activity("FIREMAKING", "Logs (lighting)")
    local rates = xpFor(logs, { worn = { ["Dwarven army axe"] = true }, bonuses = on("firemaking_pyrelord") })
    near(rates.xpPerAction, 40 + 10 + 3, "logs")
end)

test("The Book of Char blocks every other bonus", function()
    local magic = activity("FIREMAKING", "Magic logs (lighting)")
    local rates = xpFor(magic, {
        worn = { ["Ring of fire"] = true, ["Flame gloves"] = true },
        bonuses = on("firemaking_book_of_char", "double_xp"),
    })
    near(rates.xpPerAction, 303.8 * 2, "char")
end)

test("Double XP switches off cooking and firemaking brawling gloves", function()
    for _, case in ipairs({ { "COOKING", "Shark", "Brawling gloves (Cooking)" },
                            { "FIREMAKING", "Elder logs (lighting)", "Brawling gloves (Firemaking)" } }) do
        local act = activity(case[1], case[2])
        local _, active = xpFor(act, { worn = { [case[3]] = true }, bonuses = on("double_xp") })
        local ids = activeIds(active)
        eq(ids.double_xp, true, case[2] .. " double xp")
        for id in pairs(ids) do
            assert(not id:match("^brawling_"), case[2] .. " still has " .. id)
        end
    end
end)

-- Fletching bonuses --------------------------------------------------------

local FLETCHER = {
    ["Fletcher's headwear"] = true, ["Fletcher's chestpiece"] = true, ["Fletcher's legwear"] = true,
    ["Fletcher's gloves"] = true, ["Fletcher's boots"] = true,
}
local IN_WORKROOM = { [areas.RANGERS_WORKROOM.id] = true }

test("strung-bow chances add up and scale the whole action", function()
    local bow = activity("FLETCHING", "Magic shortbow (unstrung)")
    local rates = xpFor(bow, {
        worn = with(FLETCHER, { ["Crystal knife"] = true }),
        areas = IN_WORKROOM, bonuses = on("fletching_rangers_workroom_bundle"),
    })
    -- outfit +6%, then 5% (knife) + 2% (workroom tier 2) extra actions
    near(rates.xpPerAction, 83.3 * 1.06 * 1.07, "bow")
end)

test("workroom tier 2 tick box covers both of its bonuses", function()
    local arrowsAct = activity("FLETCHING", "Rune arrow x15")
    local rates = xpFor(arrowsAct, { areas = IN_WORKROOM, bonuses = on("fletching_rangers_workroom_bundle") })
    near(rates.xpPerAction, 187.5 * 1.01, "extra bundle chance")
end)

test("workroom tier 3 adds 5% of raw XP and its workbench saves 2% of materials", function()
    local bow = activity("FLETCHING", "Yew longbow (unstrung)")
    local active = effects.activeFor(bow, allEffects, {
        areas = IN_WORKROOM, nearby = { ["Fletching workbench"] = true }, bonuses = on("fletching_rangers_workroom"),
    })
    local result = calculator.calculate({ activity = bow, currentXp = 0, targetXp = 84 * 100, activeEffects = active })
    near(result.xpPerAction, 84, "80 + 5%")
    eq(result.actions, 100, "actions")
    eq(result.inputs[1].needed, 98, "yew logs")
end)

test("the workroom's save chance is only automatic inside the workroom", function()
    local bow = activity("FLETCHING", "Yew longbow (unstrung)")
    local _, outside = xpFor(bow, { nearby = { ["Fletching workbench"] = true } })
    eq(activeIds(outside).fletching_rangers_workroom_save, nil, "outside")
    local _, chosen = xpFor(bow, { bonuses = on("fletching_rangers_workroom_save") })
    eq(activeIds(chosen).fletching_rangers_workroom_save, true, "chosen for planning")
end)

test("Amulet of Fletcher's Offerings needs moonstone dust", function()
    local arrowsAct = activity("FLETCHING", "Rune arrow x15")
    local active = effects.activeFor(arrowsAct, allEffects, { worn = { ["Amulet of Fletcher's Offerings"] = true } })
    local result = calculator.calculate({ activity = arrowsAct, currentXp = 0, targetXp = 187.5 * 1.1 * 50, activeEffects = active })
    eq(result.actions, 50, "actions")
    eq(result.inputs[3].item, "Moonstone dust", "dust listed")
    eq(result.inputs[3].needed, 5, "1 dust per 10 actions")
end)

-- Crafting bonuses ---------------------------------------------------------

local ARTISAN = {
    ["Artisan's bandana"] = true, ["Artisan's top"] = true, ["Artisan's legs"] = true,
    ["Artisan's gloves"] = true, ["Artisan's boots"] = true,
}

test("dragonhide body: bandana and scroll each save one leather, cape removes thread", function()
    local body = activity("CRAFTING", "Green dragonhide body")
    local worn = with(ARTISAN, { ["Artisan's bandana"] = false, ["Modified artisan's bandana"] = true, ["Crafting cape"] = true })
    local active = effects.activeFor(body, allEffects, { worn = worn, bonuses = on("crafting_dexterity") })
    local result = calculator.calculate({ activity = body, currentXp = 0, targetXp = 186 * 1.06 * 100, activeEffects = active })
    eq(result.actions, 100, "bodies")
    eq(#result.inputs, 1, "no thread")
    -- 3 leather - 0.05 (bandana) - 0.25 (scroll, green) = 2.7 per body
    eq(result.inputs[1].needed, 270, "green dragon leather")
end)

test("without the cape, thread is 1 spool per 5 items", function()
    local body = activity("CRAFTING", "Blue dragonhide body")
    local result = calculator.calculate({ activity = body, currentXp = 0, targetXp = 210 * 10, activeEffects = {} })
    eq(result.actions, 10, "bodies")
    eq(result.inputs[2].item, "Thread", "thread")
    eq(result.inputs[2].needed, 2, "2 spools")
end)

test("harp: Voice of Seren and the artificer's measure don't stack", function()
    local harp = activity("CRAFTING", "Harp (per successful note)")
    local rates = xpFor(harp, { worn = { ["Artificer's measure"] = true }, bonuses = on("crafting_vos_ithell") })
    near(rates.xpPerAction, 96, "80 + 20%")
end)

test("army axe adds 3 XP to leather items", function()
    local gloves = activity("CRAFTING", "Leather gloves")
    local rates, active = xpFor(gloves, { backpack = { ["Dwarven army axe"] = 1 } })
    near(rates.xpPerAction, 16.8, "13.8 + 3")
    local result = calculator.calculate({ activity = gloves, currentXp = 0, targetXp = 100, activeEffects = active })
    local lines = report.build(result, { skillName = "Crafting", startLevel = 1, targetLabel = "level 2" })
    eq(lines.reasons[2], "Dwarven army axe (in backpack): +3 base XP", "flat XP line")
end)

-- Herblore bonuses ---------------------------------------------------------

local FACTORY = {
    ["Factory mask"] = true, ["Factory top"] = true, ["Factory trousers"] = true,
    ["Factory gloves"] = true, ["Factory boots"] = true,
}

test("full Factory outfit adds the herb's cleaning XP to unfinished potions", function()
    local unf = activity("HERBLORE", "Ranarr potion (unfinished)")
    near(xpFor(unf, { worn = FACTORY }).xpPerAction, 1 + 7.5, "5 pieces")
    near(xpFor(unf, { worn = with(FACTORY, { ["Factory boots"] = false }) }).xpPerAction, 1, "4 pieces")
end)

test("Scroll of cleansing saves the herb, never the vial", function()
    local unf = activity("HERBLORE", "Ranarr potion (unfinished)")
    local active = effects.activeFor(unf, allEffects, { bonuses = on("herblore_scroll_of_cleansing") })
    local result = calculator.calculate({ activity = unf, currentXp = 0, targetXp = 100, activeEffects = active })
    eq(result.actions, 100, "actions")
    eq(result.inputs[1].needed, 90, "clean ranarr")
    eq(result.inputs[2].needed, 100, "vials")
end)

test("Scroll of cleansing splits its chance across an overload's ingredients", function()
    local overload = activity("HERBLORE", "Overload")
    local active = effects.activeFor(overload, allEffects, { bonuses = on("herblore_scroll_of_cleansing") })
    local result = calculator.calculate({ activity = overload, currentXp = 0, targetXp = 100000, activeEffects = active })
    eq(result.actions, 100, "overloads")
    eq(result.inputs[1].needed, 100, "extreme attack (the base) is never saved")
    -- six saveable ingredients, each saved 10% / 6 of the time
    eq(result.inputs[2].needed, 99, "extreme strength")
end)

test("combination potions: Voice of Seren and perfect juju", function()
    local holy = activity("HERBLORE", "Holy overload potion")
    local rates = xpFor(holy, { bonuses = on("herblore_vos_meilyr", "herblore_perfect_juju") })
    near(rates.xpPerAction, 350 * 1.2 * 1.05, "holy overload")
end)

-- Calculator -------------------------------------------------------------

test("no bonuses: actions = ceil(xp needed / base xp)", function()
    local result = calculator.calculate({ activity = goldBar, currentXp = 0, targetXp = 1000, activeEffects = {} })
    eq(result.actions, 143, "1000 / 7 = 142.9 -> 143")
    eq(result.inputs[1].needed, 143, "gold ore")
end)

test("exact multiples don't round up an extra action", function()
    local result = calculator.calculate({ activity = goldBar, currentXp = 0, targetXp = 700, activeEffects = {} })
    eq(result.actions, 100, "700 / 7")
end)

test("already at target needs nothing", function()
    local result = calculator.calculate({ activity = goldBar, currentXp = 5000, targetXp = 1000, activeEffects = {} })
    eq(result.actions, 0, "actions")
    eq(result.inputs[1].needed, 0, "inputs")
end)

test("onlyInputs savings touch just those items", function()
    local leatherItem = {
        id = "test_body", skill = "CRAFTING", name = "Test body", level = 1, xp = 100,
        inputs = { { item = "Leather", qty = 3 }, { item = "Thread", qty = 1 } }, tags = {},
    }
    local bandana = { effect = { id = "b", name = "Bandana", kind = "saveChance", onlyInputs = { "Leather" } },
        value = 0.5, detail = "worn" }
    local cape = { effect = { id = "c", name = "Cape", kind = "inputScale", onlyInputs = { "Thread" } },
        value = 0, detail = "worn" }
    local result = calculator.calculate({ activity = leatherItem, currentXp = 0, targetXp = 1000,
        activeEffects = { bandana, cape } })
    eq(result.actions, 10, "actions")
    eq(#result.inputs, 1, "thread not listed")
    eq(result.inputs[1].needed, 15, "half the leather")
    local lines = report.build(result, { skillName = "Crafting", startLevel = 1, targetLabel = "level 9" })
    eq(lines.reasons[2], "Bandana (worn): 50% chance to keep your Leather", "save line")
    eq(lines.reasons[3], "Cape (worn): no Thread needed", "scale line")
end)

test("area effects need the player in the area", function()
    local room = { id = "room", name = "the room" }
    local bonus = { id = "room_bonus", name = "Room", kind = "basePercent", value = 5,
        appliesTo = { allSkills = true }, detect = { type = "area", area = room } }
    eq(effects.evaluate(bonus, { areas = {} }), nil, "outside")
    eq(effects.evaluate(bonus, { areas = { room = true } }).detail, "in the room", "inside")
end)

test("have counts show shortfall", function()
    local result = calculator.calculate({ activity = goldBar, currentXp = 0, targetXp = 700,
        activeEffects = {}, have = { ["Gold ore"] = 30 } })
    eq(result.inputs[1].have, 30, "have")
    eq(result.inputs[1].short, 70, "short")
end)

-- Formatting and report --------------------------------------------------

test("number formatting", function()
    eq(format.number(1234567), "1,234,567", "grouping")
    eq(format.number(999), "999", "small")
    eq(format.xp(56.2), "56.2", "decimal")
    eq(format.xp(1250), "1,250", "whole")
    eq(format.percent(6), "+6%", "percent")
    eq(format.percent(2.5), "+2.5%", "fractional percent")
end)

test("report explains each bonus", function()
    local active = effects.activeFor(dragonBones, allEffects, { worn = FIRST_AGE, nearby = { ["Gilded altar"] = true } })
    local result = calculator.calculate({ activity = dragonBones, currentXp = 0, targetXp = 10000,
        activeEffects = active, have = { ["Dragon bones"] = 5 } })
    local lines = report.build(result, { skillName = "Prayer", startLevel = 1, targetLabel = "level 22" })
    eq(lines.headline, "Prayer 1 -> level 22: 10,000 XP to go", "headline")
    eq(lines.needs[1], "Dragon bones x 38 (267.1 XP each)", "actions")
    eq(lines.needs[2], "38 Dragon bones - you have 5 (gather 33 more)", "needs")
    eq(lines.reasons[2], "Gilded altar (nearby, 2 burners lit (or Prayer cape)): base XP x3.5", "altar line")
    eq(lines.reasons[3], "First age outfit (5/5 pieces worn): +6%", "outfit line")
    eq(lines.reasons[4], "Total: 267.1 XP per action (+271% overall)", "total")
end)

test("plan from 60 to 70 smithing gold bars", function()
    local result = calculator.calculate({ activity = goldBar,
        currentXp = xp.forLevel(60), targetXp = xp.forLevel(70), activeEffects = {} })
    -- 737,627 - 273,742 = 463,885 XP at 7 XP per bar
    eq(result.xpNeeded, 463885, "xp needed")
    eq(result.actions, 66270, "bars")
    eq(result.inputs[1].needed, 66270, "gold ore")
end)

-- Smithing items, checked against the wiki's item pages and burial set table.
test("smithing items: bars and XP at each tier", function()
    local body = activity("SMITHING", "Bronze platebody or chainbody")
    eq(body.inputs[1].qty, 5, "bronze platebody bars")
    eq(body.xp, 75, "bronze platebody XP")
    eq(body.tier, "Base item", "tier")
    -- Rune platebody: 5 + 5 + 10 + 20 bars; 1,200 + 1,200 + 2,400 + 4,800 XP.
    local rune3 = activity("SMITHING", "Rune platebody or chainbody +3")
    eq(rune3.inputs[1].qty, 40, "rune platebody +3 bars")
    eq(rune3.xp, 9600, "rune platebody +3 XP")
    -- Burying it gives its last upgrade's 4,800 XP again, using no bars.
    local buried = activity("SMITHING", "Rune burial platebody or chainbody")
    eq(buried.inputs[1].qty, 40, "rune burial platebody bars")
    near(buried.xp, 14400, "rune burial platebody XP")
    eq(buried.item, rune3.item, "tiers share one item entry")
end)

test("only the metal's upgrades and burial are offered", function()
    local tiers = {}
    for _, a in ipairs(activities.SMITHING) do
        if a.item == "Platebody or chainbody (5 bars)" then
            tiers[a.group] = (tiers[a.group] or "") .. a.tier .. ";"
        end
    end
    eq(tiers["Bronze items"], "Base item;", "bronze")
    eq(tiers["Iron items"], "Base item;+1;", "iron")
    eq(tiers["Adamant items"], "Base item;+1;+2;Burial;", "adamant")
    eq(tiers["Primal items"], "Base item;+1;+2;+3;+4;+5;Burial;", "primal")
end)

test("burial sets: make, upgrade, then bury as a set (+5%)", function()
    -- Adamant: 48 bars x 170 = 8,160 XP making and upgrading, then the
    -- wiki's 4,284 XP for the set.
    local adamant = activity("SMITHING", "Adamant burial set")
    eq(adamant.inputs[1].qty, 48, "adamant set bars")
    near(adamant.xp, 8160 + 4284, "adamant set XP")
    local elder = activity("SMITHING", "Elder rune burial set")
    eq(elder.inputs[1].qty, 384, "elder rune set bars")
    near(elder.xp, 384000 + 201600, "elder rune set XP")
end)

test("Solemn Smith adds to the burial step of sets only", function()
    local adamant = activity("SMITHING", "Adamant burial set")
    -- Solemn Smith V: the wiki's 4,488 XP for the set instead of 4,284.
    near(xpFor(adamant, { bonuses = { solemn_smith = 5 } }).xpPerAction, 8160 + 4488, "Solemn Smith V")
    local buried = activity("SMITHING", "Adamant burial platebody or chainbody")
    near(xpFor(buried, { bonuses = { solemn_smith = 5 } }).xpPerAction, buried.xp, "single burial items unchanged")
end)

test("report warns when the activity needs a higher level", function()
    local rune = activity("SMITHING", "Rune bar")
    local result = calculator.calculate({ activity = rune, currentXp = xp.forLevel(40), targetXp = xp.forLevel(60), activeEffects = {} })
    local lines = report.build(result, { skillName = "Smithing", startLevel = 40, targetLabel = "level 60" })
    eq(lines.needs[1], "Note: needs level 50 Smithing - you start at 40", "warning")
end)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
