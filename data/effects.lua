-- effects.lua
-- Every XP bonus the plugin knows about. Values from the RuneScape Wiki
-- (https://runescape.wiki), checked October 2026. Bonuses that have been
-- removed from the game (Goldsmith gauntlets, auras, the portable forge,
-- Demonic skull) are deliberately left out.
--
-- Fields:
--   id            unique name, used to save the user's settings
--   name          shown in the panel
--   kind          how it changes XP - see src/calculator.lua:
--                   multiplyBase, basePercent, addBase, percent, multiplier,
--                   globalPercent, doubleXp, urnPercent, extraChance,
--                   saveChance, inputScale
--   ofRawXp       for basePercent: add a percent of the activity's own XP
--                 instead of multiplying (e.g. Fort Forinthry rooms)
--   value         the amount (a percent, a multiplier, or a 0-1 chance)
--   appliesTo     { skills = { "SMITHING" } } and/or { tags = { "smelting" } },
--                 or { allSkills = true }
--   detect        how the plugin spots it for the "Auto" setting:
--                   { type = "set", pieces = {...}, perPiece = 1, fullSetBonus = 1 }
--                   { type = "worn", names = {...} }       worn equipment
--                   { type = "backpack", names = {...} }   in the backpack
--                   { type = "carried", names = {...} }    worn or in the backpack
--                   { type = "nearby", names = {...} }     scenery within 8 tiles
--                   { type = "area", area = areas.X }      standing in an area
--                   { type = "toggle" }                    can't be detected: it's
--                                                          Off until the player picks it
--                 Whatever the type, players can also choose it in the panel.
--   choices       optional list of { label, value } the player picks from
--                 (defaultChoice: the index used when detected automatically)
--   hint          a sentence shown when the bonus is picked in the panel
--   toggleId      share another effect's setting (its id) instead of having one
--   requiresArea  optional { id, name } from data/areas.lua; for Auto only
--   exclusiveGroup  only the best active effect in a group applies
--   cancels       ids of effects this one switches off
--   cancelsAll    true if no other bonus works alongside it
--   extraInputs   resources this method needs on top of the activity's own
--   onlyInputs    for saveChance/inputScale: only these items are affected
--                 (inputsLabel: a short name for them in the explanation)
--   saveQty       for saveChance: save this many pieces per action instead of
--                 the whole input (e.g. one leather of the three in a body)
--   onlySaveable  for saveChance: only inputs marked `saveable` on the
--                 activity, one of them at random
--   valueFromActivity  take the value from this field of the activity
--   scaleByActivity    multiply the value by this field of the activity
--                      (e.g. Solemn Smith: 1% x the burial set's burial XP)
--   (set detection may use minPieces = N to need at least N pieces worn)
--   note          extra text shown in the explanation

local areas = require("data/areas")

local effects = {}

local function add(effect)
    table.insert(effects, effect)
    return effect
end

---------------------------------------------------------------------------
-- All skills
---------------------------------------------------------------------------

add({
    id = "double_xp", name = "Double XP", kind = "doubleXp", value = 100,
    appliesTo = { allSkills = true },
    detect = { type = "toggle" }, hint = "Double XP is live",
    -- Double XP switches off brawling gloves and powder of burials.
    cancels = {
        "brawling_smithing", "brawling_prayer", "brawling_cooking", "brawling_firemaking",
        "powder_of_burials",
    },
})

-- Dwarven army axe: +3 base XP for food cooked on a fire or range, burning
-- normal and oak logs, and soft and hard leather items. Works wielded or in
-- the backpack. https://runescape.wiki/w/Dwarven_army_axe
add({
    id = "dwarven_army_axe", name = "Dwarven army axe", kind = "addBase", value = 3,
    appliesTo = { tags = { "fire_or_range", "normal_or_oak", "dwarven_army_axe" } },
    detect = { type = "carried", names = { "Dwarven army axe" } },
})

-- Brawling gloves: x1.5, or x1.75 with an Infernal Puzzle Box at tier 4+.
-- Double XP switches them off (see double_xp above).
local function brawlingGloves(id, name, appliesTo)
    return add({
        id = id, name = name, kind = "multiplier", appliesTo = appliesTo,
        detect = { type = "worn", names = { name } },
        defaultChoice = 1,
        choices = {
            { label = "+50%", value = 1.5 },
            { label = "+75% (Infernal Puzzle Box tier 4+)", value = 1.75 },
        },
    })
end

-- Skilling urns fill with 20% (decorated) or 25% (exquisite) of base XP,
-- paid out when teleported; an urn enhancer adds 25% on top.
-- https://runescape.wiki/w/Urns
local function urn(id, name, hint, appliesTo)
    add({
        id = id, name = name, kind = "urnPercent", appliesTo = appliesTo,
        detect = { type = "toggle" }, hint = hint,
        defaultChoice = 1,
        choices = {
            { label = "Decorated", value = 20 },
            { label = "Decorated + urn enhancer", value = 25 },
            { label = "Exquisite", value = 25 },
            { label = "Exquisite + urn enhancer", value = 31.25 },
        },
    })
end

add({
    id = "clan_avatar", name = "Clan avatar", kind = "globalPercent",
    appliesTo = { allSkills = true },
    detect = { type = "toggle" }, hint = "Clan avatar nearby",
    defaultChoice = 4,
    choices = {
        { label = "3%", value = 3 }, { label = "4%", value = 4 },
        { label = "5%", value = 5 }, { label = "6%", value = 6 },
    },
})

---------------------------------------------------------------------------
-- Smithing
---------------------------------------------------------------------------

add({
    id = "blacksmiths_outfit", name = "Blacksmith's outfit", kind = "percent",
    appliesTo = { skills = { "SMITHING" } },
    detect = {
        type = "set", perPiece = 1, fullSetBonus = 1,
        pieces = {
            { "Blacksmith's helmet", "Modified blacksmith's helmet" },
            "Blacksmith's top",
            "Blacksmith's apron",
            -- Smelting gauntlets count as the gloves if you own the gloves.
            { "Blacksmith's gloves", "Smelting gauntlets" },
            "Blacksmith's boots",
        },
    },
})

-- Since June 2025 smithing urns fill from both smelting and smithing.
urn("smithing_urn", "Smithing urn", "Smithing urn filling in backpack", { skills = { "SMITHING" } })

add({
    id = "ring_of_forging", name = "Ring of forging", kind = "inputScale", value = 0.5,
    appliesTo = { tags = { "iron_bar" } },
    detect = { type = "worn", names = { "Ring of forging" } },
    note = "1 iron ore per bar instead of 2",
})

brawlingGloves("brawling_smithing", "Brawling gloves (Smithing)", { skills = { "SMITHING" } })

-- Solemn Smith (Artisans' Workshop reward shop): each tier adds 1% of a
-- burial set's burial XP, on top of the 5% every set gets. It doesn't boost
-- making and upgrading the pieces. https://runescape.wiki/w/Solemn_Smith
add({
    id = "solemn_smith", name = "Solemn Smith", kind = "addBase",
    appliesTo = { tags = { "burial_set" } },
    detect = { type = "toggle" }, hint = "Bought from the Artisans' Workshop reward shop",
    choices = {
        { label = "Solemn Smith I", value = 0.01 }, { label = "Solemn Smith II", value = 0.02 },
        { label = "Solemn Smith III", value = 0.03 }, { label = "Solemn Smith IV", value = 0.04 },
        { label = "Solemn Smith V", value = 0.05 },
    },
    scaleByActivity = "burialSetXp",
})

add({
    id = "vos_trahaearn", name = "Voice of Seren (Trahaearn)", kind = "basePercent", value = 20,
    appliesTo = { tags = { "corrupted_ore" } },
    detect = { type = "toggle" }, hint = "Voice of Seren is on Trahaearn this hour",
})

---------------------------------------------------------------------------
-- Prayer
---------------------------------------------------------------------------

add({
    id = "first_age_outfit", name = "First age outfit", kind = "percent",
    appliesTo = { skills = { "PRAYER" } },
    detect = {
        type = "set", perPiece = 1, fullSetBonus = 1,
        pieces = {
            { "First age tiara", "Modified first age tiara" },
            "First age amulet",
            -- A Prayer cape counts as the First age cape if you own one.
            { "First age cape", "Prayer cape", "Prayer cape (t)", "Retro prayer cape",
              "Retro prayer cape (t)", "Hooded prayer cape", "Hooded prayer cape (t)" },
            "First age ring",
            "First age bracelet",
        },
    },
})

add({
    id = "first_age_tiara_save", name = "Modified first age tiara", kind = "saveChance", value = 0.02,
    appliesTo = { skills = { "PRAYER" } },
    detect = { type = "worn", names = { "Modified first age tiara" } },
})

-- Offering methods. You can only use one at a time, so they share an
-- exclusive group; altars also switch off Double XP and the Dragon Rider
-- amulet, which only works when burying.
local ALTAR_CANCELS = { "double_xp", "dragon_rider_amulet" }

-- Player-owned house altars: the altar's own multiplier, +0.5 per lit
-- incense burner (up to 2; a Prayer cape counts as 2 lit burners).
local POH_ALTARS = {
    { id = "oak", name = "Oak altar", value = 1.5 },
    { id = "teak", name = "Teak altar", value = 1.6 },
    { id = "cloth", name = "Cloth altar", value = 1.7 },
    { id = "mahogany", name = "Mahogany altar", value = 1.8 },
    { id = "limestone", name = "Limestone altar", value = 1.9 },
    { id = "marble", name = "Marble altar", value = 2.0 },
    { id = "gilded", name = "Gilded altar", value = 2.5 },
}
for _, altar in ipairs(POH_ALTARS) do
    add({
        id = altar.id .. "_altar", name = altar.name, kind = "multiplyBase",
        appliesTo = { skills = { "PRAYER" } },
        detect = { type = "nearby", names = { altar.name } },
        exclusiveGroup = "prayer_method", cancels = ALTAR_CANCELS,
        defaultChoice = 3,
        choices = {
            { label = "no burners lit", value = altar.value },
            { label = "1 burner lit", value = altar.value + 0.5 },
            { label = "2 burners lit (or Prayer cape)", value = altar.value + 1.0 },
        },
    })
end

add({
    id = "chaos_altar", name = "Chaos altar", kind = "multiplyBase",
    appliesTo = { skills = { "PRAYER" } },
    detect = { type = "nearby", names = { "Chaos altar" } },
    requiresArea = areas.WILDERNESS,
    exclusiveGroup = "prayer_method", cancels = ALTAR_CANCELS,
    defaultChoice = 1,
    choices = {
        { label = "No Wilderness achievements", value = 1.5 }, { label = "Easy achievements", value = 2.0 },
        { label = "Medium achievements", value = 2.5 }, { label = "Hard achievements", value = 3.0 },
        { label = "Elite achievements", value = 3.5 },
    },
})

add({
    id = "fort_chapel", name = "Fort Forinthry chapel", kind = "multiplyBase",
    appliesTo = { skills = { "PRAYER" } },
    detect = { type = "toggle" }, hint = "Offering at the Fort Forinthry chapel",
    exclusiveGroup = "prayer_method", cancels = ALTAR_CANCELS,
    defaultChoice = 3,
    choices = {
        { label = "Tier 1", value = 2.0 }, { label = "Tier 2", value = 2.5 }, { label = "Tier 3", value = 3.0 },
    },
})

add({
    id = "other_altar", name = "Altar offering", kind = "multiplyBase", value = 1.5,
    appliesTo = { skills = { "PRAYER" } },
    detect = { type = "toggle" }, hint = "Offering at another altar",
    exclusiveGroup = "prayer_method", cancels = { "dragon_rider_amulet" },
})

-- The Ectofuntus gives 4x XP but no other bonus works with it. Bones are
-- ground into bonemeal (needs a pot); ashes go straight in.
add({
    id = "ectofuntus_bones", name = "Ectofuntus", kind = "multiplyBase", value = 4,
    appliesTo = { tags = { "bones" } },
    detect = { type = "nearby", names = { "Ectofuntus" } },
    cancelsAll = true, note = "no other bonuses apply",
    extraInputs = { { item = "Pot", qty = 1 }, { item = "Bucket of slime", qty = 1 } },
})
add({
    id = "ectofuntus_ashes", name = "Ectofuntus", kind = "multiplyBase", value = 4,
    appliesTo = { tags = { "ashes" } },
    detect = { type = "nearby", names = { "Ectofuntus" } },
    cancelsAll = true, note = "no other bonuses apply",
    extraInputs = { { item = "Bucket of slime", qty = 1 } },
})

add({
    id = "powder_of_burials", name = "Powder of burials", kind = "multiplyBase", value = 3.5,
    appliesTo = { tags = { "bones" } },
    detect = { type = "toggle" }, hint = "Powder of burials active",
    exclusiveGroup = "prayer_method",
})

add({
    id = "auto_sanctifier", name = "Auto-sanctifier", kind = "multiplyBase", value = 3.5,
    appliesTo = { skills = { "PRAYER" } },
    detect = { type = "backpack", names = { "Auto-sanctifier" } },
    exclusiveGroup = "prayer_method",
})

add({
    id = "dragon_rider_amulet", name = "Dragon Rider amulet", kind = "multiplyBase", value = 2,
    appliesTo = { tags = { "dragon_bones" } },
    detect = { type = "worn", names = { "Dragon Rider amulet" } },
    -- Wearing it replaces powder of burials and the auto-sanctifier.
    cancels = { "powder_of_burials", "auto_sanctifier" },
})

local prayerGloves = brawlingGloves("brawling_prayer", "Brawling gloves (Prayer)", { skills = { "PRAYER" } })
-- They switch off the Wilderness chaos altar bonus and the auto-sanctifier.
prayerGloves.cancels = { "chaos_altar", "auto_sanctifier" }

---------------------------------------------------------------------------
-- Cooking (tags in data/activities/cooking.lua)
---------------------------------------------------------------------------

add({
    id = "cooking_sous_chef_outfit", name = "Sous chef's outfit", kind = "percent",
    appliesTo = { skills = { "COOKING" } },
    detect = {
        type = "set", perPiece = 1, fullSetBonus = 1,
        pieces = {
            { "Sous chef's toque", "Modified sous chef's toque" },
            "Sous chef's jacket",
            "Sous chef's trousers",
            -- Cooking gauntlets count as the mitts if you own the mitts.
            { "Sous chef's mitts", "Cooking gauntlets" },
            "Sous chef's shoes",
        },
    },
})

-- Wine doesn't fill cooking urns, so this targets the "urn" tag.
urn("cooking_urn", "Cooking urn", "Cooking urn filling in backpack", { tags = { "cooking_urn" } })

-- A tier 3 kitchen gives +5% base XP to anything cooked inside it. Like the
-- port workshop it's added to the raw XP rather than multiplied in, so the
-- two together on sailfish soup give 600 -> 750.
add({
    id = "cooking_fort_kitchen", name = "Fort Forinthry kitchen (tier 3)", kind = "basePercent", value = 5,
    ofRawXp = true,
    appliesTo = { tags = { "kitchen" } },
    detect = { type = "toggle" }, hint = "My Fort Forinthry kitchen is tier 3",
    requiresArea = areas.FORT_KITCHEN,
})

-- Player-made bonfires only: the permanent bonfires in Prifddinas, Yeti Town
-- and Menaphos don't give it. Desert sole, catfish and beltfish don't get it.
add({
    id = "cooking_bonfire", name = "Bonfire", kind = "basePercent", value = 10,
    appliesTo = { tags = { "bonfire_cooking" } },
    detect = { type = "toggle" }, hint = "Cooking on a player-made bonfire",
})

-- Port soups get the player-owned port workshop's XP boost, at the port's
-- Cooking Station or the Fort Forinthry soup creation station.
add({
    id = "cooking_port_workshop", name = "Player-owned port workshop", kind = "basePercent",
    ofRawXp = true,
    appliesTo = { tags = { "soup" } },
    detect = { type = "toggle" }, hint = "Port workshop upgraded",
    defaultChoice = 4,
    choices = {
        { label = "Refitted (+5%)", value = 5 },
        { label = "Renovated (+10%)", value = 10 },
        { label = "Refurbished (+15%)", value = 15 },
        { label = "Revamped (+20%)", value = 20 },
    },
})

brawlingGloves("brawling_cooking", "Brawling gloves (Cooking)", { skills = { "COOKING" } })

---------------------------------------------------------------------------
-- Firemaking (tags in data/activities/firemaking.lua)
---------------------------------------------------------------------------

-- Ring of fire and Flame gloves: 2% each, plus 1% for wearing both (5%).
-- Both also work for curly roots.
add({
    id = "firemaking_fired_up", name = "Fired up set", kind = "percent",
    appliesTo = { tags = { "logs", "curly_roots" } },
    detect = {
        type = "set", perPiece = 2, fullSetBonus = 1,
        pieces = { "Ring of fire", "Flame gloves" },
    },
})

-- More players on the same bonfire give extra XP; the permanent bonfires
-- (Yeti Town, Menaphos, and the Tower of Voices and Max Guild in Prifddinas)
-- always give the full 4%. Treated as a base XP boost, which matches the
-- wiki's worked example (magic logs: 309.5 x 1.04 x 1.05 = 338).
add({
    id = "firemaking_bonfire", name = "Shared bonfire", kind = "basePercent",
    appliesTo = { tags = { "bonfire" } },
    detect = { type = "toggle" }, hint = "Adding logs to a shared or permanent bonfire",
    defaultChoice = 4,
    choices = {
        { label = "2 players: +1%", value = 1 },
        { label = "3 players: +2%", value = 2 },
        { label = "4 players: +3%", value = 3 },
        { label = "5+ players, or a permanent bonfire: +4%", value = 4 },
    },
})

brawlingGloves("brawling_firemaking", "Brawling gloves (Firemaking)", { tags = { "logs", "curly_roots" } })

-- Tinker perk on an augmented tinderbox: a 5% chance per rank (5.5% on a
-- level 20 tool) for an action to give 25% more base XP. The values are the
-- average gain per log.
add({
    id = "firemaking_tinker", name = "Tinker perk", kind = "basePercent",
    appliesTo = { tags = { "logs" } },
    detect = { type = "toggle" }, hint = "Augmented tinderbox with the Tinker perk",
    defaultChoice = 4,
    choices = {
        { label = "Tinker 1", value = 1.25 },
        { label = "Tinker 2", value = 2.5 },
        { label = "Tinker 3", value = 3.75 },
        { label = "Tinker 4", value = 5 },
        { label = "Tinker 1, level 20 tool", value = 1.375 },
        { label = "Tinker 2, level 20 tool", value = 2.75 },
        { label = "Tinker 3, level 20 tool", value = 4.125 },
        { label = "Tinker 4, level 20 tool", value = 5.5 },
    },
    note = "average: 25% extra XP on 5% of actions per rank",
})

-- Familiars that add 10 XP per log lit (not on bonfires). Only one familiar
-- can be summoned at a time.
add({
    id = "firemaking_pyrelord", name = "Pyrelord", kind = "addBase", value = 10,
    appliesTo = { tags = { "lighting", "curly_roots" } },
    detect = { type = "toggle" }, hint = "Pyrelord familiar summoned",
    exclusiveGroup = "firemaking_familiar",
})
add({
    id = "firemaking_forge_regent", name = "Forge regent", kind = "addBase", value = 10,
    appliesTo = { tags = { "lighting" } },
    detect = { type = "toggle" }, hint = "Forge regent familiar summoned",
    exclusiveGroup = "firemaking_familiar",
})

-- The Book of Char's "Unleash": double XP for logs lit by walking over them,
-- for 2 minutes once a day. Nothing else stacks with it.
add({
    id = "firemaking_book_of_char", name = "The Book of Char", kind = "multiplyBase", value = 2,
    appliesTo = { tags = { "lighting" } },
    detect = { type = "toggle" }, hint = "The Book of Char is unleashed",
    cancelsAll = true, note = "lasts 2 minutes, once a day; no other bonuses apply",
})

---------------------------------------------------------------------------
-- Fletching (tags in data/activities/fletching.lua)
---------------------------------------------------------------------------

add({
    id = "fletching_fletchers_outfit", name = "Fletcher's outfit", kind = "percent",
    appliesTo = { skills = { "FLETCHING" } },
    detect = {
        type = "set", perPiece = 1, fullSetBonus = 1,
        pieces = {
            "Fletcher's headwear", "Fletcher's chestpiece", "Fletcher's legwear",
            "Fletcher's gloves", "Fletcher's boots",
        },
    },
})

-- Artisan's Acolyte: +3% Fletching XP, adding to the Fletcher's outfit.
add({
    id = "fletching_amulet_of_offerings", name = "Amulet of Offerings", kind = "percent", value = 3,
    appliesTo = { skills = { "FLETCHING" } },
    detect = { type = "worn", names = { "Amulet of Offerings" } },
})

-- Fletcher's Acolyte: +10% base XP, but everything you fletch is destroyed.
-- One charge per action; one moonstone dust recharges 10 charges. The wiki
-- doesn't say whether it works on the Mk. upgrades or Fenmoor Totems.
add({
    id = "fletching_amulet_of_fletchers_offerings", name = "Amulet of Fletcher's Offerings",
    kind = "basePercent", value = 10,
    appliesTo = { tags = { "shafts", "unstrung_bow", "stringing", "headless", "arrows", "bolts", "darts" } },
    detect = { type = "worn", names = { "Amulet of Fletcher's Offerings" } },
    extraInputs = { { item = "Moonstone dust", qty = 0.1 } },
    note = "destroys what you fletch; the dust is to recharge it",
})

-- Fletching cape perk: 0.75% chance of a free extra bundle of ammo or
-- headless shafts, with full XP. Not detected when the perk is stored in a
-- max cape or another back-slot item.
add({
    id = "fletching_cape", name = "Fletching cape perk", kind = "extraChance", value = 0.0075,
    appliesTo = { tags = { "ammo", "headless" } },
    detect = {
        type = "worn",
        names = {
            "Fletching cape", "Fletching cape (t)", "Retro fletching cape", "Retro fletching cape (t)",
            "Hooded fletching cape", "Hooded fletching cape (t)",
            "Retro hooded fletching cape", "Retro hooded fletching cape (t)",
            "Fletching master cape", "Inverted Fletching master cape",
        },
    },
})

-- Crystal knife: 5% chance that cutting an unstrung bow gives a strung bow,
-- with the stringing XP as well (equal to the cutting XP for these bows).
-- Its double-shafts chance uses no extra logs and gives no extra XP.
add({
    id = "fletching_crystal_knife", name = "Crystal knife", kind = "extraChance", value = 0.05,
    appliesTo = { tags = { "auto_string" } },
    detect = { type = "worn", names = { "Crystal knife" } },
})

-- Ranger's Workroom at Fort Forinthry: bonuses count while you're inside
-- it. The game doesn't tell us which tier you've built, so tiers 2 and 3
-- are tick boxes.
add({
    id = "fletching_rangers_workroom", name = "Ranger's Workroom (tier 3)", kind = "basePercent", value = 5,
    ofRawXp = true,
    appliesTo = { skills = { "FLETCHING" } },
    detect = { type = "toggle" }, hint = "My Ranger's Workroom is tier 3",
    requiresArea = areas.RANGERS_WORKROOM,
})

-- Tier 1: 2% chance the workroom supplies the materials (tested on cutting
-- bows, tipping arrows and feathering bolts and darts; not on stringing).
-- The workbench only exists once the workroom is built, so it's detection.
add({
    id = "fletching_rangers_workroom_save", name = "Ranger's Workroom", kind = "saveChance", value = 0.02,
    appliesTo = { tags = { "unstrung_bow", "arrows", "bolts", "darts" } },
    detect = { type = "nearby", names = { "Fletching workbench" } },
    requiresArea = areas.RANGERS_WORKROOM,
})

-- Tier 2: 1% chance of a free extra bundle of ammo or headless shafts, and a
-- 2% chance that cutting a bow gives it strung (with stringing XP). These
-- add to the Fletching cape's and crystal knife's chances.
add({
    id = "fletching_rangers_workroom_bundle", name = "Ranger's Workroom (tier 2)", kind = "extraChance", value = 0.01,
    appliesTo = { tags = { "ammo", "headless" } },
    detect = { type = "toggle" }, hint = "My Ranger's Workroom is tier 2 or higher",
    requiresArea = areas.RANGERS_WORKROOM,
})
add({
    id = "fletching_rangers_workroom_strung", name = "Ranger's Workroom (tier 2)", kind = "extraChance", value = 0.02,
    appliesTo = { tags = { "auto_string" } },
    detect = { type = "toggle" }, hint = "My Ranger's Workroom is tier 2 or higher",
    toggleId = "fletching_rangers_workroom_bundle",
    requiresArea = areas.RANGERS_WORKROOM,
})

---------------------------------------------------------------------------
-- Crafting (tags in data/activities/crafting.lua)
---------------------------------------------------------------------------

add({
    id = "crafting_artisans_outfit", name = "Artisan's outfit", kind = "percent",
    appliesTo = { skills = { "CRAFTING" } },
    detect = {
        type = "set", perPiece = 1, fullSetBonus = 1,
        pieces = {
            { "Artisan's bandana", "Modified artisan's bandana" },
            "Artisan's top", "Artisan's legs", "Artisan's gloves", "Artisan's boots",
        },
    },
})

-- 5% chance per item to save one piece of leather (sent to the bank).
-- Thread is never saved.
add({
    id = "crafting_artisans_bandana_save", name = "Modified artisan's bandana", kind = "saveChance", value = 0.05,
    appliesTo = { tags = { "leather" } },
    onlyInputs = {
        "Leather", "Hard leather",
        "Green dragon leather", "Blue dragon leather", "Red dragon leather",
        "Black dragon leather", "Royal dragon leather", "Undead dragon leather",
    },
    inputsLabel = "leather", saveQty = 1,
    detect = { type = "worn", names = { "Modified artisan's bandana" } },
})

-- The Crafting cape perk: no thread needed for leather. The same perk can be
-- stored in a max, completionist or artisan's cape, which can't be seen from
-- the item name, hence the tick box.
local THREAD_FREE = { tags = { "thread" } }
add({
    id = "crafting_cape_thread", name = "Crafting cape", kind = "inputScale", value = 0,
    appliesTo = THREAD_FREE, onlyInputs = { "Thread" },
    detect = {
        type = "worn",
        names = {
            "Crafting cape", "Crafting cape (t)", "Retro crafting cape", "Retro crafting cape (t)",
            "Hooded crafting cape", "Hooded crafting cape (t)",
            "Retro hooded crafting cape", "Retro hooded crafting cape (t)", "Crafting master cape",
        },
    },
    exclusiveGroup = "crafting_cape_perk",
})
add({
    id = "crafting_cape_perk_stored", name = "Crafting cape perk", kind = "inputScale", value = 0,
    appliesTo = THREAD_FREE, onlyInputs = { "Thread" },
    detect = { type = "toggle" },
    hint = "Crafting cape perk stored in my max/completionist/artisan's cape",
    exclusiveGroup = "crafting_cape_perk",
})

-- Ithell Voice of Seren: +20% base XP from crystal flasks and harps while in
-- the Ithell district. A worn artificer's measure gives harps the same bonus
-- all the time; the two don't stack.
add({
    id = "crafting_vos_ithell", name = "Voice of Seren (Ithell)", kind = "basePercent", value = 20,
    appliesTo = { tags = { "crystal_flask", "harp" } },
    detect = { type = "toggle" }, hint = "Voice of Seren is on Ithell this hour",
    exclusiveGroup = "crafting_ithell_voice",
})
add({
    id = "crafting_artificers_measure_harp", name = "Artificer's measure", kind = "basePercent", value = 20,
    appliesTo = { tags = { "harp" } },
    detect = { type = "worn", names = { "Artificer's measure" } },
    exclusiveGroup = "crafting_ithell_voice",
})

-- Artificer's Measure buff: +0.5% Crafting XP per stack, up to 10 stacks.
-- Stacks come from the scroll of dexterity saving a material while the
-- measure is worn. Adds together with outfits.
local ARTIFICER_STACKS = {}
for stacks = 1, 10 do
    table.insert(ARTIFICER_STACKS, { label = string.format("%d stacks (+%.1f%%)", stacks, stacks * 0.5), value = stacks * 0.5 })
end
add({
    id = "crafting_artificers_measure_buff", name = "Artificer's Measure buff", kind = "percent",
    appliesTo = { skills = { "CRAFTING" } },
    detect = { type = "toggle" }, hint = "Artificer's Measure buff active",
    defaultChoice = 10,
    choices = ARTIFICER_STACKS,
})

-- Scroll of dexterity (Daemonheim reward, permanent once read): on items using
-- 3+ of the same leather, a chance to save one. The chance depends on the
-- leather; a worn artificer's measure multiplies it by 1.25. One effect per
-- colour, all sharing one tick box. Unknown for undead dragon leather.
local DEXTERITY = {
    { colour = "green", leather = "Green dragon leather", chance = 0.25 },
    { colour = "blue", leather = "Blue dragon leather", chance = 0.20 },
    { colour = "red", leather = "Red dragon leather", chance = 0.15 },
    { colour = "black", leather = "Black dragon leather", chance = 0.10 },
    { colour = "royal", leather = "Royal dragon leather", chance = 0.05 },
}
for _, scroll in ipairs(DEXTERITY) do
    add({
        id = "crafting_dexterity_" .. scroll.colour, name = "Scroll of dexterity", kind = "saveChance",
        appliesTo = { tags = { "dexterity_" .. scroll.colour } },
        onlyInputs = { scroll.leather }, saveQty = 1,
        detect = { type = "toggle" }, hint = "Scroll of dexterity read",
        toggleId = "crafting_dexterity",
        defaultChoice = 1,
        choices = {
            { label = "Read", value = scroll.chance },
            { label = "Read, wearing an artificer's measure", value = scroll.chance * 1.25 },
        },
    })
end

---------------------------------------------------------------------------
-- Herblore (tags in data/activities/herblore.lua)
---------------------------------------------------------------------------

add({
    id = "herblore_botanists_outfit", name = "Botanist's outfit", kind = "percent",
    appliesTo = { skills = { "HERBLORE" } },
    detect = {
        type = "set", perPiece = 1, fullSetBonus = 1,
        pieces = {
            { "Botanist's mask", "Modified botanist's mask" },
            "Botanist's top", "Botanist's trousers", "Botanist's gloves", "Botanist's boots",
        },
    },
})

-- Factory outfit, all 5 pieces: making an unfinished potion also gives the XP
-- for cleaning its herb (each activity's cleaningXp), on top of the usual 1.
add({
    id = "herblore_factory_outfit", name = "Factory outfit", kind = "addBase",
    valueFromActivity = "cleaningXp",
    appliesTo = { tags = { "unfinished" } },
    detect = {
        type = "set", minPieces = 5,
        pieces = { "Factory mask", "Factory top", "Factory trousers", "Factory gloves", "Factory boots" },
    },
    note = "the herb's cleaning XP",
})

-- Scroll of cleansing (permanent unlock): a 10% chance per mix to save one
-- ingredient - the herb in an unfinished potion, or a secondary. Never the
-- vial, crystal flask or base potion. With several it can save, it picks one
-- at random. Activities mark the ingredients it can save as `saveable`.
add({
    id = "herblore_scroll_of_cleansing", name = "Scroll of cleansing", kind = "saveChance", value = 0.1,
    appliesTo = { tags = { "unfinished", "potion" } },
    detect = { type = "toggle" }, hint = "Scroll of cleansing unlocked",
    onlySaveable = true, inputsLabel = "herb or secondary",
})

-- Combination potions made in the Meilyr district during its Voice of Seren hour.
add({
    id = "herblore_vos_meilyr", name = "Voice of Seren (Meilyr)", kind = "basePercent", value = 20,
    appliesTo = { tags = { "combination" } },
    detect = { type = "toggle" }, hint = "Voice of Seren is on Meilyr this hour",
})

-- A perfect plus potion gives the same effect.
add({
    id = "herblore_perfect_juju", name = "Perfect juju herblore potion", kind = "basePercent", value = 5,
    appliesTo = { tags = { "combination" } },
    detect = { type = "toggle" }, hint = "Perfect juju herblore (or perfect plus) potion active",
})

-- Juju potions and cleaning Herblore Habitat herbs, not unfinished juju
-- potions. The wiki doesn't say how it stacks; treated as a base XP boost.
add({
    id = "herblore_guthixs_gift", name = "Guthix's gift", kind = "basePercent", value = 10,
    appliesTo = { tags = { "juju", "vine_herb" } },
    detect = { type = "toggle" }, hint = "Guthix's gift active",
})

-- The herbicide burns herbs dropped by monsters for twice the cleaning XP.
add({
    id = "herblore_herbicide", name = "Herbicide", kind = "multiplyBase", value = 2,
    appliesTo = { tags = { "herbicide" } },
    detect = { type = "toggle" }, hint = "Burning herb drops with the herbicide",
})

return effects
