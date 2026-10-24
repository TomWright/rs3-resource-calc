-- crafting.lua
-- Crafting activities. One "action" is one item made (one gem cut, one ring
-- cast, one dragonhide body sewn...), except where the name says otherwise:
--   * tailoring (starbloom / apex hide, level 100+): one piece of cloth or
--     leather. Every piece and every upgrade tier (+1 to +5) gives the same XP
--     per cloth/leather, so it works like Smithing's "per bar".
--   * exquisite urns: moulding, firing and adding the gem, counted as one.
--   * harps: one successful note.
-- Values from https://runescape.wiki/w/Crafting,
-- https://runescape.wiki/w/Module:Skill_calc/Crafting/data and each item's own
-- page (Infobox Item name and Infobox Recipe), checked October 2026.
--
-- Not modelled:
--   * Amulets come off the furnace unstrung. In-game the unstrung amulet has
--     the same name as the strung one (e.g. "Diamond amulet"), so the
--     stringing activities use that name for their input.
--   * Thread for tailoring: the wiki says the amount varies, so it's left out.
--   * Portable crafters: due to be removed from the game.

local activities = {}

local function item(name, qty)
    return { item = name, qty = qty or 1 }
end

-- Turns { "a", "b" } into { a = true, b = true }.
local function tagSet(list)
    local tags = {}
    for _, tag in ipairs(list) do
        tags[tag] = true
    end
    return tags
end

local function add(group, name, level, xp, inputs, tags)
    table.insert(activities, {
        skill = "CRAFTING", group = group,
        name = name, level = level, xp = xp, inputs = inputs, tags = tagSet(tags),
    })
end

-- Rounds to 1 decimal place, so sums like 80.2 + 123.7 come out clean.
local function round1(value)
    return math.floor(value * 10 + 0.5) / 10
end

---------------------------------------------------------------------------
-- Gem cutting (chisel). The crystal chisel's extra gem is output only.
---------------------------------------------------------------------------

local function cut(gem, uncut, level, xp)
    add("Gem cutting", gem, level, xp, { item(uncut) }, { "gems" })
end

cut("Opal", "Uncut opal", 1, 15)
cut("Lapis lazuli gem", "Uncut lapis lazuli", 1, 20)
cut("Jade", "Uncut jade", 13, 20)
cut("Red topaz", "Uncut red topaz", 16, 25)
cut("Sapphire", "Uncut sapphire", 20, 50)
cut("Emerald", "Uncut emerald", 27, 67.5)
cut("Ruby", "Uncut ruby", 34, 85)
cut("Diamond", "Uncut diamond", 43, 107.5)
cut("Dragonstone", "Uncut dragonstone", 55, 137.5)
cut("Moonstone", "Uncut moonstone", 67, 167.5)
cut("Onyx", "Uncut onyx", 72, 180)
cut("Hydrix", "Uncut hydrix", 79, 197.5)

---------------------------------------------------------------------------
-- Jewellery (furnace + mould): bar first, then the cut gem if there is one.
---------------------------------------------------------------------------

-- `prefix` is the item name start ("Gold", "Sapphire"...), `gem` the cut gem
-- used (nil for plain gold), and `pieces` lists { name suffix, level, xp }.
local function jewellery(prefix, bar, gem, pieces)
    for _, piece in ipairs(pieces) do
        local inputs = { item(bar) }
        if gem ~= nil then
            table.insert(inputs, item(gem))
        end
        add("Jewellery", prefix .. " " .. piece[1], piece[2], piece[3], inputs, { "jewellery" })
    end
end

jewellery("Gold", "Gold bar", nil, {
    { "ring", 5, 15 }, { "necklace", 6, 20 }, { "bracelet", 7, 25 }, { "amulet (unstrung)", 8, 30 },
})
jewellery("Sapphire", "Gold bar", "Sapphire", {
    { "ring", 20, 40 }, { "necklace", 22, 55 }, { "bracelet", 23, 60 }, { "amulet (unstrung)", 24, 65 },
})
jewellery("Emerald", "Gold bar", "Emerald", {
    { "ring", 27, 55 }, { "necklace", 29, 60 }, { "bracelet", 30, 65 }, { "amulet (unstrung)", 31, 70 },
})
jewellery("Ruby", "Gold bar", "Ruby", {
    { "ring", 34, 70 }, { "necklace", 40, 75 }, { "bracelet", 42, 80 }, { "amulet (unstrung)", 50, 85 },
})
jewellery("Diamond", "Gold bar", "Diamond", {
    { "ring", 43, 85 }, { "necklace", 56, 90 }, { "bracelet", 58, 95 }, { "amulet (unstrung)", 70, 100 },
})
jewellery("Dragonstone", "Gold bar", "Dragonstone", {
    { "ring", 55, 100 }, { "necklace", 72, 105 }, { "bracelet", 74, 110 }, { "amulet (unstrung)", 80, 150 },
})
jewellery("Onyx", "Gold bar", "Onyx", {
    { "ring", 72, 115 }, { "necklace", 82, 120 }, { "bracelet", 84, 125 }, { "amulet (unstrung)", 90, 165 },
})
jewellery("Hydrix", "Gold bar", "Hydrix", {
    { "ring", 79, 130 }, { "necklace", 90, 135 }, { "bracelet", 94, 140 }, { "amulet (unstrung)", 99, 180 },
})
-- Moonstone jewellery is cast from an ensouled bar (made with Necromancy).
jewellery("Moonstone", "Ensouled bar", "Moonstone", {
    { "ring", 67, 130 }, { "necklace", 77, 135 }, { "bracelet", 79, 140 }, { "amulet (unstrung)", 85, 145 },
})
-- Platinum jewellery (104-109) uses a dragonstone in every piece.
jewellery("Platinum", "Platinum bar", "Dragonstone", {
    { "ring", 104, 214 }, { "necklace", 105, 227 }, { "bracelet", 106, 235 },
    { "amulet (unstrung)", 108, 248 }, { "anklet", 109, 263 },
})

-- Stringing an amulet with a ball of wool gives a little extra XP.
local function stringAmulet(amulet, level, xp)
    add("Jewellery", "String " .. amulet, level, xp, { item(amulet), item("Ball of wool") },
        { "jewellery", "amulet_stringing" })
end

stringAmulet("Gold amulet", 8, 4)
stringAmulet("Sapphire amulet", 24, 4)
stringAmulet("Emerald amulet", 31, 4)
stringAmulet("Ruby amulet", 50, 4)
stringAmulet("Diamond amulet", 70, 4)
stringAmulet("Dragonstone amulet", 80, 4)
stringAmulet("Moonstone amulet", 85, 4)
stringAmulet("Onyx amulet", 90, 4)
stringAmulet("Hydrix amulet", 99, 4)
stringAmulet("Platinum amulet", 108, 15)

---------------------------------------------------------------------------
-- Silver casting (furnace + mould), one silver bar each.
---------------------------------------------------------------------------

local function silver(name, level, xp)
    add("Silver", name, level, xp, { item("Silver bar") }, { "silver" })
end

silver("Unstrung symbol", 16, 50)
silver("Unstrung emblem", 17, 50) -- needs the Observatory Quest
silver("Silver sickle", 18, 50)   -- needs partial Nature Spirit
silver("Tiara", 23, 52.5)

---------------------------------------------------------------------------
-- Leather and dragonhide armour (needle).
-- A spool of thread lasts 5 items (4 for hard leather), so thread is
-- 0.2 / 0.25 per item. Soft leather items don't list thread on the wiki.
-- The hard leather shield is left out: the wiki disagrees on its thread.
---------------------------------------------------------------------------

-- `leatherQty` pieces of `leather` per item, plus `threadQty` thread (or nil).
-- Tags: "leather" (the modified artisan's bandana can save it) and "thread"
-- (the Crafting cape removes it).
local function leatherItem(group, name, level, xp, leather, leatherQty, threadQty, extraTags)
    local inputs = { item(leather, leatherQty) }
    local tags = { "leather" }
    if threadQty ~= nil then
        table.insert(inputs, item("Thread", threadQty))
        table.insert(tags, "thread")
    end
    for _, tag in ipairs(extraTags or {}) do
        table.insert(tags, tag)
    end
    add(group, name, level, xp, inputs, tags)
end

-- The dwarven army axe gives +3 XP on soft and hard leather items.
local SOFT = { "soft_leather", "dwarven_army_axe" }
leatherItem("Leather", "Leather gloves", 1, 13.8, "Leather", 1, nil, SOFT)
leatherItem("Leather", "Leather boots", 1, 16.3, "Leather", 1, nil, SOFT)
leatherItem("Leather", "Leather cowl", 1, 18.5, "Leather", 1, nil, SOFT)
leatherItem("Leather", "Leather body", 1, 25, "Leather", 1, nil, SOFT)
leatherItem("Leather", "Leather chaps", 1, 27, "Leather", 1, nil, SOFT)
leatherItem("Leather", "Leather vambraces", 11, 22, "Leather", 1, nil, SOFT)
leatherItem("Leather", "Leather shield", 19, 30, "Leather", 1, nil, SOFT)

local HARD = { "hard_leather", "dwarven_army_axe" }
leatherItem("Leather", "Hard leather cowl", 25, 21, "Hard leather", 1, 0.25, HARD)
leatherItem("Leather", "Hard leather gloves", 25, 32, "Hard leather", 1, 0.25, HARD)
leatherItem("Leather", "Hard leather boots", 27, 34, "Hard leather", 1, 0.25, HARD)
leatherItem("Leather", "Hard leather body", 28, 35, "Hard leather", 1, 0.25, HARD)
leatherItem("Leather", "Hard leather chaps", 28, 35, "Hard leather", 1, 0.25, HARD)

-- Every dragonhide piece gives the same XP per leather used (checked on each
-- item's page). Pieces using 3+ leather are tagged "dexterity_<colour>" for
-- the scroll of dexterity, whose save chance depends on the leather colour.
local DRAGONHIDE_PIECES = {
    { "vambraces", 1 }, { "boots", 1 }, { "chaps", 2 }, { "coif", 2 }, { "body", 3 }, { "shield", 4 },
}

local function dragonhide(colour, level, xpPerLeather, hasShield, dexterityColour)
    local leather = colour .. " dragon leather"
    for _, piece in ipairs(DRAGONHIDE_PIECES) do
        local name, qty = piece[1], piece[2]
        if name ~= "shield" or hasShield then
            local tags = { "dragonhide" }
            if qty >= 3 and dexterityColour ~= nil then
                table.insert(tags, "dexterity_" .. dexterityColour)
            end
            leatherItem("Dragonhide", colour .. " dragonhide " .. name, level, xpPerLeather * qty,
                leather, qty, 0.2, tags)
        end
    end
end

dragonhide("Green", 40, 62, true, "green")
dragonhide("Blue", 50, 70, true, "blue")
dragonhide("Red", 55, 78, true, "red")
dragonhide("Black", 60, 86, true, "black")
dragonhide("Royal", 65, 94, false, "royal")  -- there's no royal shield
dragonhide("Undead", 75, 102, false, nil)    -- no shield; scroll chance unknown

---------------------------------------------------------------------------
-- Battlestaves: battlestaff + orb.
---------------------------------------------------------------------------

local function battlestaff(name, level, xp, orb)
    add("Battlestaves", name, level, xp, { item("Battlestaff"), item(orb) }, { "battlestaves" })
end

battlestaff("Water battlestaff", 54, 100, "Water orb")
battlestaff("Earth battlestaff", 58, 112.5, "Earth orb")
battlestaff("Fire battlestaff", 62, 125, "Fire orb")
battlestaff("Air battlestaff", 66, 137.5, "Air orb")
battlestaff("Armadyl battlestaff", 77, 150, "Orb of Armadyl") -- needs Ritual of the Mahjarrat

---------------------------------------------------------------------------
-- Glassblowing (glassblowing pipe). The artificer's measure's 5% chance of
-- a duplicate is output only, so it doesn't change these numbers.
---------------------------------------------------------------------------

local function glass(name, level, xp, material, extraTags)
    local tags = { "glassblowing" }
    for _, tag in ipairs(extraTags or {}) do
        table.insert(tags, tag)
    end
    add("Glassblowing", name, level, xp, { item(material) }, tags)
end

glass("Beer glass", 1, 17.5, "Molten glass")
glass("Candle lantern (empty)", 4, 19, "Molten glass")
glass("Oil lamp (empty)", 12, 25, "Molten glass")
glass("Vial", 33, 35, "Molten glass")
glass("Fishbowl", 42, 42.5, "Molten glass")
glass("Unpowered orb", 46, 52.5, "Molten glass")
glass("Lantern lens", 49, 55, "Molten glass")
glass("Bomb vial", 54, 55, "Molten glass")
glass("Empty light orb", 87, 70, "Molten glass")
glass("Potion flask", 89, 100, "Robust glass")                        -- needs As a First Resort
glass("Crystal flask", 89, 150, "Crystal glass", { "crystal_flask" }) -- Voice of Seren (Ithell): +20%

-- Filling an empty light orb with cave goblin wire.
add("Glassblowing", "Light orb", 87, 104, { item("Empty light orb"), item("Cave goblin wire") },
    { "glassblowing" })

---------------------------------------------------------------------------
-- Spinning (spinning wheel) and weaving (loom).
---------------------------------------------------------------------------

add("Spinning", "Bowstring", 1, 15, { item("Flax") }, { "spinning" })
add("Spinning", "Starbloom thread", 100, 47, { item("Starbloom flower") }, { "spinning", "starbloom" })
add("Spinning", "Starbloom cloth (weaving)", 100, 95, { item("Starbloom thread", 2) }, { "weaving", "starbloom" })

---------------------------------------------------------------------------
-- Prifddinas harps (Ithell district): 80 XP per successful note, nothing used
-- up. Voice of Seren (Ithell) or a worn artificer's measure: +20%.
---------------------------------------------------------------------------

add("Harps", "Harp (per successful note)", 75, 80, {}, { "harp" })

---------------------------------------------------------------------------
-- Exquisite urns (102-110): mould soft porcelain clay, fire it, add the gem.
---------------------------------------------------------------------------

-- XP for each of the three steps, from the (unfired), (no gem) and (no rune)
-- item pages.
local function exquisiteUrn(skillName, level, mouldXp, fireXp, gemXp, gem)
    add("Urns", "Exquisite " .. skillName .. " urn (no rune)", level, round1(mouldXp + fireXp + gemXp),
        { item("Soft porcelain clay"), item(gem) }, { "urns" })
end

exquisiteUrn("mining", 102, 78, 120, 120, "Jade")
exquisiteUrn("cooking", 103, 80.2, 123.7, 123.7, "Red topaz")
exquisiteUrn("fishing", 104, 81.5, 126.4, 126.4, "Sapphire")
exquisiteUrn("smithing", 105, 84.7, 130, 130, "Ruby")
exquisiteUrn("woodcutting", 106, 87, 133.1, 133.1, "Diamond")
exquisiteUrn("runecrafting", 107, 90.8, 134.9, 134.9, "Dragonstone")
exquisiteUrn("divination", 108, 92.4, 139, 139, "Dragonstone")
exquisiteUrn("hunter", 109, 96, 141.2, 141.2, "Opal")
exquisiteUrn("farming", 110, 99, 144, 144, "Emerald")

---------------------------------------------------------------------------
-- Tailoring (level 100+, Crafting Guild or Wendlewick): 2,640 XP per cloth or
-- leather for every piece and upgrade tier. Base apex hide pieces also use one
-- apex sinew per leather (plus 3 steel studs and 1 steel bar per full set,
-- not counted here). Thread use varies, so it isn't counted.
---------------------------------------------------------------------------

add("Tailoring", "Starbloom equipment (per cloth)", 100, 2640,
    { item("Starbloom cloth") }, { "tailoring", "starbloom" })
add("Tailoring", "Apex hide armour, base pieces (per leather)", 100, 2640,
    { item("Apex leather"), item("Apex sinew") }, { "tailoring", "apex_hide" })
add("Tailoring", "Apex hide armour, upgrades +1 to +5 (per leather)", 100, 2640,
    { item("Apex leather") }, { "tailoring", "apex_hide" })

-- Adorning a full +5 set at a tailor's display uses up the set. 304,128 XP at
-- level 100; the +5% (level 106) and +10% (level 109) bonuses aren't counted.
add("Tailoring", "Starbloom robes (adorned)", 100, 304128, {
    item("Starbloom robe top + 5"), item("Starbloom robe bottom + 5"), item("Starbloom hat + 5"),
    item("Starbloom gloves + 5"), item("Starbloom boots + 5"),
}, { "tailoring", "starbloom", "adornment" })
add("Tailoring", "Apex hide armour (adorned)", 100, 304128, {
    item("Apex hide body + 5"), item("Apex hide chaps + 5"), item("Apex hide cowl + 5"),
    item("Apex hide vambraces + 5"), item("Apex hide boots + 5"),
}, { "tailoring", "apex_hide", "adornment" })

return activities
