-- smithing.lua
-- Smithing activities. One "action" is:
--   * smelting: one smelt (usually one bar)
--   * smithing: one item, made from bars and taken as far as its tier says
--     (e.g. "+2" = make the base item, then upgrade it twice)
--   * burial set: the five armour pieces made, upgraded and buried as a set
-- Values from https://runescape.wiki/w/Smithing and
-- https://runescape.wiki/w/Burial_equipment (post Mining & Smithing rework),
-- checked October 2026. Extra bars from double-bar chances give no XP and
-- aren't counted.
--
-- Smithing items show in the panel as a group per metal, an item, and a
-- tier ("Make": base item, +1 ... burial), using these extra fields:
--   item   the entry in the activity dropdown, shared by all its tiers
--   tier   the entry in the "Make" dropdown

local activities = {}

-- Adds a smelting activity. `inputs` lists the ores used per smelt.
local function smelt(name, level, xp, inputs, extraTags)
    local tags = { smelting = true }
    for _, tag in ipairs(extraTags or {}) do
        tags[tag] = true
    end
    table.insert(activities, {
        skill = "SMITHING", group = "Smelting",
        name = name, level = level, xp = xp, inputs = inputs, tags = tags,
    })
end

-- Smithed items, by the bars the base item uses. Every item of a metal gives
-- the same XP per bar, so items only differ in how many bars they take.
local ITEMS = {
    { name = "Boots or gauntlets", bars = 1 },
    { name = "Helm, shield, pickaxe or 1-h weapon", bars = 2 },
    { name = "Platelegs or plateskirt", bars = 3 },
    { name = "2-handed weapon", bars = 4 },
    { name = "Platebody or chainbody", bars = 5 },
}

-- A burial set is a full helm, platebody, platelegs, gauntlets and armoured
-- boots: 2 + 5 + 3 + 1 + 1 bars as base items.
local SET_BARS = 12
local SET_LABEL = "Burial set (helm, body, legs, gauntlets, boots)"
-- Burying them as a set gives 5% more than burying each piece.
local BURIAL_SET_BONUS = 1.05

-- Adds one smithing activity: `what` is the item part of its name (e.g.
-- "burial platebody or chainbody"), made from `bars` of the metal's bars.
-- All tiers of a metal need the metal's level.
local function addSmithing(metal, level, fields)
    table.insert(activities, {
        skill = "SMITHING", group = metal .. " items",
        name = metal .. " " .. fields.what, item = fields.item, tier = fields.tier,
        level = level, xp = fields.xp, inputs = { { item = metal .. " bar", qty = fields.bars } },
        tags = fields.tags, burialSetXp = fields.burialSetXp,
    })
end

-- Adds a metal's smithing activities, everything planned from bars:
--   * each item as a base item, then upgraded to +1 ... +maxUpgrade. The
--     first upgrade uses as many bars as the base item and each one after
--     doubles that, so the bars used so far double with every upgrade; each
--     upgrade gives the same XP per bar.
--   * burial (adamant and up): reworking a fully upgraded item at a burial
--     anvil uses no bars and gives the XP of its last upgrade again, which
--     is half the bars used so far.
--   * a burial set: the five armour pieces, made, upgraded and buried as one.
-- e.g. an adamant platebody +2 is 5 + 5 + 10 = 20 bars for 20 x 170 XP, and
-- burying it adds another 10 x 170 XP.
local function smith(metal, level, xpPerBar, maxUpgrade, canBury)
    for _, item in ipairs(ITEMS) do
        local label = string.format("%s (%d bar%s)", item.name, item.bars, item.bars > 1 and "s" or "")
        local what = item.name:lower()
        local bars = item.bars
        addSmithing(metal, level, { what = what, item = label, tier = "Base item",
            bars = bars, xp = bars * xpPerBar, tags = { smithing = true } })
        for upgrade = 1, maxUpgrade do
            bars = bars * 2
            addSmithing(metal, level, { what = what .. " +" .. upgrade, item = label, tier = "+" .. upgrade,
                bars = bars, xp = bars * xpPerBar, tags = { smithing = true } })
        end
        if canBury then
            addSmithing(metal, level, { what = "burial " .. what, item = label, tier = "Burial",
                bars = bars, xp = bars * xpPerBar * 1.5, tags = { smithing = true, burial = true } })
        end
    end
    if canBury then
        local bars = SET_BARS
        for _ = 1, maxUpgrade do
            bars = bars * 2
        end
        local burialSetXp = bars / 2 * xpPerBar
        addSmithing(metal, level, { what = "burial set", item = SET_LABEL, tier = "Burial",
            bars = bars, xp = bars * xpPerBar + burialSetXp * BURIAL_SET_BONUS,
            -- The burial step's own XP, which Solemn Smith adds to.
            burialSetXp = burialSetXp,
            tags = { smithing = true, burial = true, burial_set = true } })
    end
end

local function ore(name, qty)
    return { item = name, qty = qty or 1 }
end

smelt("Bronze bar", 1, 1, { ore("Copper ore"), ore("Tin ore") })
smelt("Iron bar", 10, 2, { ore("Iron ore", 2) }, { "iron_bar" })
smelt("Silver bar", 20, 3, { ore("Silver ore") })
smelt("Steel bar", 20, 3, { ore("Iron ore"), ore("Coal") })
smelt("Mithril bar", 30, 5, { ore("Mithril ore"), ore("Coal") })
smelt("Gold bar", 40, 7, { ore("Gold ore") })
smelt("Adamant bar", 40, 7, { ore("Adamantite ore"), ore("Luminite") })
smelt("Rune bar", 50, 10, { ore("Runite ore"), ore("Luminite") })
smelt("Orikalkum bar", 60, 13, { ore("Orichalcite ore"), ore("Drakolith") })
smelt("Necronium bar", 70, 17, { ore("Necrite ore"), ore("Phasmatite") })
smelt("Bane bar", 80, 21, { ore("Banite ore", 2) })
smelt("Corrupted ore (Prifddinas)", 89, 160, { ore("Corrupted ore") }, { "corrupted_ore" })
smelt("Elder rune bar", 90, 26, { ore("Rune bar"), ore("Light animica"), ore("Dark animica") })
-- One primal smelt uses one of each of these ten ores and makes 5 bars.
smelt("Primal bar (5 per smelt)", 100, 31, {
    ore("Novite ore"), ore("Bathus ore"), ore("Marmaros ore"), ore("Kratonium ore"), ore("Fractite ore"),
    ore("Zephyrium ore"), ore("Argonite ore"), ore("Katagon ore"), ore("Gorgonite ore"), ore("Promethium ore"),
})
smelt("Platinum bar", 104, 33, { ore("Platinum ore") })

--     metal         level  XP per bar  upgrades  burial
smith("Bronze",      1,     15,         0,        false)
smith("Iron",        10,    40,         1,        false)
smith("Steel",       20,    75,         1,        false)
smith("Mithril",     30,    120,        2,        false)
smith("Adamant",     40,    170,        2,        true)
smith("Rune",        50,    240,        3,        true)
smith("Orikalkum",   60,    350,        3,        true)
smith("Necronium",   70,    500,        4,        true)
smith("Bane",        80,    700,        4,        true)
smith("Elder rune",  90,    1000,       5,        true)
smith("Primal",      100,   1400,       5,        true)

return activities
