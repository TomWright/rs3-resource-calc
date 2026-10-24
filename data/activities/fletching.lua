-- fletching.lua
-- Fletching activities. One "action" is one batch the game makes per click:
--   * shafts: one log cut into shafts (15 to 60 shafts, depending on the log)
--   * unstrung bows: one log cut into one unstrung bow
--   * stringing: one unstrung bow + one bowstring
--   * headless shafts: 15 shafts + 15 feathers -> 15 headless shafts
--   * arrows: 15 arrowheads + 15 headless shafts -> 15 arrows. The wiki's
--     Fletching tables quote XP per arrow; the XP here is for the set of 15
--     (e.g. rune arrows: 12.5 per arrow = 187.5 per action).
--   * bolts and darts: 10 per action (10 unfinished bolts or dart tips + 10
--     feathers). XP is for the set of 10.
-- Values from each item's Infobox Recipe on https://runescape.wiki, after the
-- Mid-Game Rebalance of 20 July 2026 (which re-tiered bows and ammo, renamed
-- "Arrow shaft" to "Shaft", "Headless arrow" to "Headless shaft" and the
-- shieldbows back to longbows), checked October 2026. Coloured feathers and
-- fungal/chima bowstrings give the same XP as Feather and Bowstring.
-- Extra items from crystal knife / skillcape / workroom procs aren't counted
-- here; the XP they add is handled as bonuses in data/effects.lua.
--
-- Tags bonuses can target:
--   shafts, unstrung_bow, stringing, headless, arrows, bolts, darts,
--   ammo (= arrows, bolts and darts), auto_string (unstrung bows from normal
--   to elder logs: the bows the "chance to make a strung bow" effects are
--   known to work on, where stringing XP equals cutting XP),
--   eternal_upgrade (Mk. 1-5 upgrades), fenmoor_totem.

local activities = {}

local function item(name, qty)
    return { item = name, qty = qty or 1 }
end

local function add(group, name, level, xp, inputs, tagList)
    local tags = {}
    for _, tag in ipairs(tagList) do
        tags[tag] = true
    end
    table.insert(activities, {
        skill = "FLETCHING", group = group,
        name = name, level = level, xp = xp, inputs = inputs, tags = tags,
    })
end

-- "Logs" for regular logs, otherwise e.g. "Oak logs".
local function logsOf(wood)
    if wood == "" then
        return "Logs"
    end
    return wood .. " logs"
end

-- "Shortbow" for regular logs, otherwise e.g. "Oak shortbow".
local function bowName(wood, kind)
    if wood == "" then
        return kind:sub(1, 1):upper() .. kind:sub(2)
    end
    return wood .. " " .. kind
end

-- Cutting one log into shafts (`count` per log).
local function shafts(logs, level, count, xp, product)
    product = product or "Shaft"
    add("Shafts", string.format("%s x%d (from %s)", product, count, logs), level, xp,
        { item(logs) }, { "shafts" })
end

-- A bow type: cutting the unstrung bow from a log, and stringing it.
-- `autoString` marks bows the strung-bow procs are known to apply to.
local function bow(wood, kind, level, cutXp, stringXp, autoString)
    local strung = bowName(wood, kind)
    local unstrung = strung .. " (unstrung)"
    local cutTags = { "unstrung_bow" }
    if autoString then
        table.insert(cutTags, "auto_string")
    end
    add("Unstrung bows", unstrung, level, cutXp, { item(logsOf(wood)) }, cutTags)
    add("Stringing bows", strung .. " (stringing)", level, stringXp,
        { item(unstrung), item("Bowstring") }, { "stringing" })
end

-- 15 shafts + 15 feathers.
local function headless(product, shaft, level, xp)
    add("Headless shafts", product .. " x15", level, xp,
        { item(shaft, 15), item("Feather", 15) }, { "headless" })
end

-- 15 arrowheads + 15 headless shafts. `xp` is for all 15 arrows.
local function arrows(metal, level, xp, headlessShaft)
    add("Arrows", metal .. " arrow x15", level, xp,
        { item(metal .. " arrowheads", 15), item(headlessShaft or "Headless shaft", 15) },
        { "arrows", "ammo" })
end

-- 10 unfinished bolts + 10 feathers. `xp` is for all 10 bolts.
local function bolts(metal, level, xp)
    add("Bolts", metal .. " bolts x10", level, xp,
        { item(metal .. " bolts (unf)", 10), item("Feather", 10) }, { "bolts", "ammo" })
end

-- 10 dart tips + 10 feathers. `xp` is for all 10 darts.
local function darts(metal, level, xp)
    add("Darts", metal .. " dart x10", level, xp,
        { item(metal .. " dart tip", 10), item("Feather", 10) }, { "darts", "ammo" })
end

---------------------------------------------------------------------------
-- Shafts (Shaft page; numbers re-tiered on 20 July 2026)
---------------------------------------------------------------------------
shafts("Logs", 1, 15, 5)
shafts("Oak logs", 10, 20, 7.5)
shafts("Willow logs", 20, 25, 10)
shafts("Teak logs", 30, 30, 11.2)
shafts("Maple logs", 40, 35, 12.5)
shafts("Acadia logs", 50, 40, 13.7)
shafts("Mahogany logs", 60, 45, 15)
shafts("Yew logs", 70, 50, 17.5)
shafts("Magic logs", 80, 55, 20)
shafts("Elder logs", 90, 60, 22.5)
-- Elder logs can instead be cut into 15 elder shafts (used for elder
-- headless shafts and the special level 92-95 arrows).
shafts("Elder logs", 90, 15, 20, "Elder shaft")
shafts("Eternal magic logs", 100, 30, 25, "Eternal magic shaft")

---------------------------------------------------------------------------
-- Bows: cutting XP, then stringing XP. They're equal for every bow except
-- the eternal magic ones.
---------------------------------------------------------------------------
bow("", "shortbow", 1, 5, 5, true)
bow("", "longbow", 5, 7.5, 7.5, true)
bow("Oak", "shortbow", 10, 10, 10, true)
bow("Oak", "longbow", 15, 14.7, 14.7, true)
bow("Willow", "shortbow", 20, 16.5, 16.5, true)
bow("Willow", "longbow", 25, 25, 25, true)
bow("Maple", "shortbow", 40, 41.5, 41.5, true)
bow("Maple", "longbow", 45, 46, 46, true)
bow("Acadia", "shortbow", 50, 50, 50, true)
bow("Acadia", "longbow", 55, 58.3, 58.3, true)
bow("Yew", "shortbow", 70, 75, 75, true)
bow("Yew", "longbow", 75, 80, 80, true)
bow("Magic", "shortbow", 80, 83.3, 83.3, true)
bow("Magic", "longbow", 85, 91.5, 91.5, true)
bow("Elder", "shortbow", 90, 101.2, 101.2, true)
bow("Elder", "longbow", 95, 116.4, 116.4, true)
-- Not tagged auto_string: the wiki doesn't confirm the strung-bow procs
-- for eternal magic bows, and their stringing XP differs from cutting XP.
bow("Eternal magic", "shortbow", 100, 90, 50, false)
bow("Eternal magic", "longbow", 105, 106, 58.5, false)

---------------------------------------------------------------------------
-- Headless shafts (15 per action)
---------------------------------------------------------------------------
headless("Headless shaft", "Shaft", 1, 15)
headless("Elder headless shaft", "Elder shaft", 90, 15)
headless("Eternal magic headless shaft", "Eternal magic shaft", 100, 18)

---------------------------------------------------------------------------
-- Arrows (15 per action; XP below is for 15)
---------------------------------------------------------------------------
arrows("Bronze", 1, 19.5)
arrows("Iron", 10, 37.5)
arrows("Steel", 20, 75)
arrows("Mithril", 30, 112.5)
arrows("Adamant", 40, 150)
arrows("Rune", 50, 187.5)
-- Broad arrows need the Broad arrow fletching unlock bought with Slayer points.
arrows("Broad", 52, 225)
arrows("Orikalkum", 60, 225)
arrows("Dragon", 60, 225)
arrows("Necronium", 70, 243)
arrows("Dark", 70, 262.5)
arrows("Bane", 80, 262.5)
arrows("Elder rune", 90, 280.5)
arrows("Primal", 100, 300, "Eternal magic headless shaft")

---------------------------------------------------------------------------
-- Bolts (10 per action; XP below is for 10)
---------------------------------------------------------------------------
bolts("Bronze", 3, 5)
bolts("Iron", 13, 15)
bolts("Blurite", 16, 15)
bolts("Steel", 23, 35)
bolts("Mithril", 33, 50)
bolts("Adamant", 43, 70)
bolts("Silver", 43, 25)
bolts("Rune", 53, 100)
bolts("Orikalkum", 63, 112)
bolts("Necronium", 73, 125)
bolts("Bane", 83, 137)
bolts("Elder rune", 93, 150)
bolts("Primal", 103, 162)
-- Ascension bolts are made straight from ascension shards, no feathers.
add("Bolts", "Ascension bolts x10", 90, 200, { item("Ascension shard", 10) }, { "bolts", "ammo" })

---------------------------------------------------------------------------
-- Darts (10 per action; XP below is for 10)
---------------------------------------------------------------------------
darts("Bronze", 11, 18)
darts("Iron", 22, 38)
darts("Steel", 37, 75)
darts("Mithril", 52, 112)
darts("Adamant", 67, 150)
darts("Rune", 81, 188)
darts("Dragon", 95, 250)

---------------------------------------------------------------------------
-- Eternal magic shortbow and primal crossbow upgrades (levels 100-110).
-- Upgrading Mk. 1 to Mk. 5 uses 2 + 4 + 8 + 16 + 32 = 62 eternal magic logs
-- and gives the same XP for every log at every tier (shortbow: 52,700 XP per
-- bow = 850 per log; crossbow: 65,100 per bow = 1,050 per log). So one action
-- here is one log, and each log uses 1/62 of a base bow. Must be started at a
-- fletching workbench. Not counted: the level 102/105/107 "chance to save 2
-- logs" levelling benefits, and the martial versions (their XP depends on
-- your level).
---------------------------------------------------------------------------
add("Eternal magic upgrades", "Eternal magic shortbow Mk. 1-5 (per log)", 100, 850,
    { item("Eternal magic logs"), item("Eternal magic shortbow", 1 / 62) }, { "eternal_upgrade" })
add("Eternal magic upgrades", "Primal crossbow Mk. 1-5 (per log)", 103, 1050,
    { item("Eternal magic logs"), item("Primal crossbow", 1 / 62) }, { "eternal_upgrade" })

---------------------------------------------------------------------------
-- Fenmoor Totems (Havenhythe, from 28 September 2026): one action is one
-- piece of petrified wood carved into a totem. XP doesn't depend on which
-- totem it goes into, and higher-tier wood can go into the level 65 toad
-- totem (gathering bark needs 85 Woodcutting). Petrified logs are left out:
-- the wiki gives two different values for them (660 and 705 XP).
---------------------------------------------------------------------------
add("Fenmoor Totems", "Totem carving (petrified roots)", 65, 310,
    { item("Petrified roots") }, { "fenmoor_totem" })
add("Fenmoor Totems", "Totem carving (petrified bark)", 65, 430,
    { item("Petrified bark") }, { "fenmoor_totem" })

return activities
