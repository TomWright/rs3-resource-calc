-- herblore.lua
-- Herblore activities. One "action" is:
--   * cleaning: one grimy herb into one clean herb
--   * unfinished potions: one clean herb into one vial of water
--   * potions: one unfinished (or base) potion plus its secondary ingredient(s)
--   * combination potions: one set of 4-dose potions poured into a crystal
--     flask, making one 6-dose flask (recipe bought in the Meilyr district)
--   * tar: one clean herb plus 15 swamp tar, making 15 tar (needs a pestle
--     and mortar; the Telekinetic Grind spell gives the same XP per herb)
--   * primal extract: one primal fruit pulp plus 1 to 3 empty vials
-- How many doses a potion comes out with (3 or 4 doses, or a free duplicate
-- from the modified botanist's mask) never changes the XP or the ingredients
-- used per action, so it isn't modelled: every action is one mix.
-- Batches with the Herblore master cape (5 overloads from 4 sets) give the
-- same XP per set of ingredients, so they're the same as 4 normal actions.
-- Daemonheim-only herbs (sagewort, valerian, aloe, etc.) are left out: they
-- can't be taken out of Daemonheim.
--
-- Values from each item's Infobox Recipe on https://runescape.wiki (e.g.
-- https://runescape.wiki/w/Prayer_potion), cross-checked with
-- https://runescape.wiki/w/Herblore/Experience_table and
-- https://runescape.wiki/w/Combination_potions, checked October 2026.
-- Item names are from each item's Infobox Item. Since 30 June 2025 the game
-- calls unfinished potions "X potion (unfinished)", not "(unf)".
--
-- Tags bonuses can target (see data/effects.lua):
--   cleaning      cleaning a grimy herb
--   herbicide     herbs the herbicide can burn for double cleaning XP
--   vine_herb     Herblore Habitat herbs (Guthix's gift boosts cleaning them)
--   unfinished    herb + vial unfinished potions
--   potion        finished potions, including juju and combination potions
--   juju          juju potions (Guthix's gift)
--   combination   combination potions (Voice of Seren in Meilyr, perfect
--                 juju herblore potion)
--   tar           herb tar
--   extract       primal extract
--
-- Extra fields some bonuses use:
--   saveable      on an input: the Scroll of cleansing can save it. It never
--                 saves the first ingredient of the game's recipe (the vial,
--                 crystal flask or base potion); when a recipe has several it
--                 can save, it picks one of them at random.
--   cleaningXp    on unfinished potions: the herb's cleaning XP, which the
--                 full Factory outfit adds to every mix.

local activities = {}

local function item(name, qty)
    return { item = name, qty = qty or 1 }
end

-- An ingredient the Scroll of cleansing can save.
local function saveable(name, qty)
    return { item = name, qty = qty or 1, saveable = true }
end

-- "dwarf weed" -> "Dwarf weed"
local function capitalise(text)
    return text:sub(1, 1):upper() .. text:sub(2)
end

-- Adds an activity. `tags` is a list of tag names; `extra` holds any extra
-- fields (e.g. cleaningXp).
local function add(group, name, level, xp, inputs, tags, extra)
    local tagSet = {}
    for _, tag in ipairs(tags) do
        tagSet[tag] = true
    end
    local activity = {
        skill = "HERBLORE", group = group,
        name = name, level = level, xp = xp, inputs = inputs, tags = tagSet,
    }
    for key, value in pairs(extra or {}) do
        activity[key] = value
    end
    table.insert(activities, activity)
end

-- Cleaning one grimy herb. `herb` is lower case, as in "Grimy dwarf weed".
local function clean(herb, level, xp, extraTags)
    local tags = { "cleaning" }
    for _, tag in ipairs(extraTags or {}) do
        table.insert(tags, tag)
    end
    add("Cleaning herbs", "Clean " .. herb, level, xp, { item("Grimy " .. herb) }, tags)
end

-- One clean herb into a vial of water (a juju vial of water for Herblore
-- Habitat herbs). `cleaningXp` is the herb's cleaning XP, added by the full
-- Factory outfit; nil where the wiki doesn't confirm the outfit works.
local function unfinished(herb, level, xp, cleaningXp, vial)
    add("Unfinished potions", capitalise(herb) .. " potion (unfinished)", level, xp,
        { saveable("Clean " .. herb), item(vial or "Vial of water") },
        { "unfinished" }, { cleaningXp = cleaningXp })
end

-- A potion: `base` (an unfinished potion, or a potion being upgraded) plus
-- `secondaries` (made with saveable()). The base can't be saved.
local function potion(name, level, xp, base, secondaries, group, extraTags)
    local inputs = { item(base) }
    for _, secondary in ipairs(secondaries) do
        table.insert(inputs, secondary)
    end
    local tags = { "potion" }
    for _, tag in ipairs(extraTags or {}) do
        table.insert(tags, tag)
    end
    add(group or "Potions", name, level, xp, inputs, tags)
end

-- A combination potion: the listed ingredients (mostly 4-dose potions) go
-- into a crystal flask. The flask can't be saved; everything else can.
local function combination(name, level, xp, ingredients)
    local inputs = {}
    for _, ingredient in ipairs(ingredients) do
        table.insert(inputs, saveable(ingredient))
    end
    table.insert(inputs, item("Crystal flask"))
    add("Combination potions", name, level, xp, inputs, { "potion", "combination" })
end

-- A juju potion: an unfinished juju potion plus one vine.
local function juju(name, level, xp, unf, vine)
    potion(name, level, xp, unf, { saveable(vine) }, "Juju potions", { "juju" })
end

-- Herb tar: one clean herb and 15 swamp tar make 15 tar.
local function tar(herb, level, xp)
    add("Tar", capitalise(herb) .. " tar (15 per herb)", level, xp,
        { item("Clean " .. herb), item("Swamp tar", 15) }, { "tar" })
end

---------------------------------------------------------------------------
-- Cleaning herbs
---------------------------------------------------------------------------

clean("guam", 1, 2.5, { "herbicide" })
clean("tarromin", 5, 3.8, { "herbicide" })
clean("marrentill", 9, 5, { "herbicide" })
clean("harralander", 20, 6.3, { "herbicide" })
clean("ranarr", 25, 7.5, { "herbicide" })
clean("toadflax", 30, 8, { "herbicide" })
clean("spirit weed", 35, 7.8, { "herbicide" })
clean("irit", 40, 8.8, { "herbicide" })
clean("wergali", 41, 9.5, { "herbicide" })
clean("avantoe", 48, 10, { "herbicide" })
clean("kwuarm", 54, 11.3, { "herbicide" })
clean("bloodweed", 57, 11.5)
clean("snapdragon", 59, 11.8, { "herbicide" })
clean("cadantine", 65, 12.5, { "herbicide" })
clean("lantadyme", 67, 13.1, { "herbicide" })
clean("dwarf weed", 70, 13.8, { "herbicide" })
clean("torstol", 75, 15, { "herbicide" })
clean("arbuck", 77, 13.5)
clean("fellstalk", 91, 16.8, { "herbicide" })

-- Herblore Habitat (vine herb patch) herbs.
clean("erzille", 54, 10, { "vine_herb" })
clean("ugune", 55, 11.5, { "vine_herb" })
clean("argway", 56, 11.6, { "vine_herb" })
clean("shengo", 57, 11.7, { "vine_herb" })
clean("samaden", 58, 11.7, { "vine_herb" })

-- Karamja herbs from the Jungle Potion quest.
clean("rogue's purse", 3, 2.5)
clean("snake weed", 3, 2.5)
clean("ardrigal", 3, 2.5)
clean("sito foil", 3, 2.5)
clean("volencia moss", 3, 2.5)

---------------------------------------------------------------------------
-- Unfinished potions (herb + vial of water)
---------------------------------------------------------------------------

unfinished("guam", 1, 1, 2.5)
unfinished("tarromin", 5, 1, 3.8)
unfinished("marrentill", 9, 1, 5)
unfinished("harralander", 20, 1, 6.3)
unfinished("ranarr", 25, 1, 7.5)
unfinished("toadflax", 30, 1, 8)
unfinished("spirit weed", 35, 1, 7.8)
unfinished("irit", 40, 1, 8.8)
unfinished("wergali", 41, 1, 9.5)
unfinished("avantoe", 48, 1, 10)
unfinished("kwuarm", 54, 1, 11.3)
unfinished("bloodweed", 57, 1, 11.5)
unfinished("snapdragon", 59, 1, 11.8)
unfinished("cadantine", 65, 1, 12.5)
unfinished("lantadyme", 67, 1, 13.1)
unfinished("dwarf weed", 70, 1, 13.8)
unfinished("torstol", 75, 1, 15)
unfinished("arbuck", 77, 1.2, 13.5)
unfinished("fellstalk", 91, 1, 16.8)
-- Herblore Habitat herbs go into juju vials of water.
unfinished("erzille", 54, 1, 10, "Juju vial of water")
unfinished("ugune", 55, 1, 11.5, "Juju vial of water")
unfinished("argway", 56, 1, 11.6, "Juju vial of water")
unfinished("shengo", 57, 1, 11.7, "Juju vial of water")
unfinished("samaden", 58, 1, 11.7, "Juju vial of water")
-- Relicym's balm base. No Factory outfit figure: the wiki doesn't say.
unfinished("rogue's purse", 5, 1, nil)

---------------------------------------------------------------------------
-- Potions
---------------------------------------------------------------------------

potion("Attack potion", 1, 25, "Guam potion (unfinished)", { saveable("Eye of newt") })
potion("Ranging potion", 3, 30, "Guam potion (unfinished)", { saveable("Redberries") })
potion("Strength potion", 7, 40, "Tarromin potion (unfinished)", { saveable("Limpwurt root") })
potion("Defence potion", 9, 45, "Marrentill potion (unfinished)", { saveable("Bear fur") })
potion("Necromancy potion", 11, 50, "Marrentill potion (unfinished)", { saveable("Cadava berries") })
potion("Antipoison", 13, 50, "Marrentill potion (unfinished)", { saveable("Unicorn horn dust") })
potion("Restore potion", 22, 62.5, "Harralander potion (unfinished)", { saveable("Red spiders' eggs") })
potion("Energy potion", 26, 67.5, "Harralander potion (unfinished)", { saveable("Chocolate dust") })
potion("Agility potion", 34, 80, "Toadflax potion (unfinished)", { saveable("Toad's legs") })
potion("Combat potion", 36, 84, "Harralander potion (unfinished)", { saveable("Goat horn dust") })
potion("Prayer potion", 38, 87.5, "Ranarr potion (unfinished)", { saveable("Snape grass") })
potion("Crafting potion", 42, 95, "Wergali potion (unfinished)", { saveable("Frog spawn") })
potion("Divination potion", 43, 97.5, "Spirit weed potion (unfinished)", { saveable("Rabbit foot") })
potion("Super attack", 45, 100, "Irit potion (unfinished)", { saveable("Eye of newt") })
potion("Super antipoison", 48, 106.3, "Irit potion (unfinished)", { saveable("Unicorn horn dust") })
potion("Fishing potion", 50, 112.5, "Avantoe potion (unfinished)", { saveable("Snape grass") })
potion("Super energy", 52, 117.5, "Avantoe potion (unfinished)", { saveable("Mort myre fungus") })
potion("Hunter potion", 53, 120, "Avantoe potion (unfinished)", { saveable("Kebbit teeth dust") })
potion("Super strength", 55, 125, "Kwuarm potion (unfinished)", { saveable("Limpwurt root") })
potion("Weapon poison", 60, 137.5, "Kwuarm potion (unfinished)", { saveable("Dragon scale dust") })
potion("Super restore", 63, 142.5, "Snapdragon potion (unfinished)", { saveable("Red spiders' eggs") })
potion("Super defence", 66, 150, "Cadantine potion (unfinished)", { saveable("White berries") })
potion("Antifire", 69, 157.5, "Lantadyme potion (unfinished)", { saveable("Dragon scale dust") })
potion("Super ranging potion", 72, 162.5, "Dwarf weed potion (unfinished)", { saveable("Wine of Zamorak") })
potion("Super magic potion", 76, 172.5, "Lantadyme potion (unfinished)", { saveable("Potato cactus") })
potion("Zamorak brew", 78, 175, "Torstol potion (unfinished)", { saveable("Jangerberries") })
-- 5 congealed blood per potion (all 5 are saved together).
potion("Super necromancy", 79, 177.5, "Spirit weed potion (unfinished)", { saveable("Congealed blood", 5) })
potion("Saradomin brew", 81, 180, "Toadflax potion (unfinished)", { saveable("Crushed nest") })
potion("Aggression potion", 82, 185, "Bloodweed potion (unfinished)", { saveable("Searing ashes") })
potion("Adrenaline potion", 84, 200, "Super energy (3)", { saveable("Papaya fruit") })
potion("Super antifire", 85, 210, "Antifire (3)", { saveable("Phoenix feather") })

-- Extreme potions: a 3-dose super potion plus a herb or secondary.
potion("Extreme attack", 88, 220, "Super attack (3)", { saveable("Clean avantoe") })
potion("Extreme strength", 89, 230, "Super strength (3)", { saveable("Clean dwarf weed") })
potion("Extreme defence", 90, 240, "Super defence (3)", { saveable("Clean lantadyme") })
potion("Extreme magic", 91, 250, "Super magic potion (3)", { saveable("Ground mud runes") })
-- 5 grenwall spikes per potion (all 5 are saved together).
potion("Extreme ranging", 92, 260, "Super ranging potion (3)", { saveable("Grenwall spikes", 5) })
potion("Extreme necromancy", 93, 265, "Super necromancy (3)", { saveable("Ground miasma rune") })

potion("Prayer renewal", 94, 190, "Fellstalk potion (unfinished)", { saveable("Morchella mushroom") })
-- Super prayer takes either secondary.
potion("Super prayer (wyvern bonemeal)", 94, 270, "Prayer potion (3)", { saveable("Wyvern bonemeal") })
potion("Super prayer (ground wyvern bones)", 94, 270, "Prayer potion (3)", { saveable("Ground wyvern bones") })

-- Overload: all six 3-dose extremes plus a clean torstol. The scroll of
-- cleansing can save anything but the extreme attack.
potion("Overload", 96, 1000, "Extreme attack (3)", {
    saveable("Extreme strength (3)"), saveable("Extreme defence (3)"), saveable("Extreme magic (3)"),
    saveable("Extreme ranging (3)"), saveable("Extreme necromancy (3)"), saveable("Clean torstol"),
})

---------------------------------------------------------------------------
-- Juju potions (Herblore Habitat)
---------------------------------------------------------------------------

juju("Juju hunter potion", 54, 123, "Erzille potion (unfinished)", "Corrupt vine")
juju("Scentless potion", 59, 135, "Argway potion (unfinished)", "Shadow vine")
juju("Juju farming potion", 64, 146, "Ugune potion (unfinished)", "Marble vine")
juju("Juju cooking potion", 67, 152, "Shengo potion (unfinished)", "Plant teeth")
juju("Juju fishing potion", 70, 158, "Shengo potion (unfinished)", "Aquatic vine")
juju("Juju woodcutting potion", 71, 160, "Samaden potion (unfinished)", "Oily vine")
juju("Juju mining potion", 74, 168, "Samaden potion (unfinished)", "Draconic vine")
juju("Saradomin's blessing", 75, 179, "Samaden potion (unfinished)", "Saradomin vine")
juju("Guthix's gift", 75, 179, "Samaden potion (unfinished)", "Guthix vine")
juju("Zamorak's favour", 75, 179, "Samaden potion (unfinished)", "Zamorak vine")

---------------------------------------------------------------------------
-- Combination potions (6-dose flasks)
---------------------------------------------------------------------------
-- The Scroll of cleansing is assumed never to save the crystal flask (the
-- wiki says so for supreme overload salves; the other recipes are assumed
-- to work the same way).

combination("Grand strength potion", 75, 123.8, { "Super strength (4)", "Strength potion (4)" })
combination("Grand ranging potion", 76, 144.4, { "Super ranging potion (4)", "Ranging potion (4)" })
combination("Grand magic potion", 77, 155.7, { "Super magic potion (4)", "Magic potion (4)" })
combination("Grand attack potion", 78, 93.8, { "Super attack (4)", "Attack potion (4)" })
combination("Grand defence potion", 79, 146.3, { "Super defence (4)", "Defence potion (4)" })
combination("Super melee potion", 81, 281.3, { "Super attack (4)", "Super strength (4)", "Super defence (4)" })
combination("Super warmaster's potion", 85, 500, {
    "Super attack (4)", "Super strength (4)", "Super defence (4)", "Super magic potion (4)", "Super ranging potion (4)",
})
combination("Replenishment potion", 87, 256.9, { "Adrenaline potion (4)", "Super restore (4)" })
combination("Wyrmfire potion", 89, 275.7, { "Super antifire (4)", "Antifire (4)" })
combination("Extreme brawler's potion", 91, 367.5, { "Extreme attack (4)", "Extreme strength (4)", "Extreme defence (4)" })
combination("Extreme battlemage's potion", 91, 367.5, { "Extreme magic (4)", "Extreme defence (4)" })
combination("Extreme sharpshooter's potion", 92, 367.5, { "Extreme ranging (4)", "Extreme defence (4)" })
combination("Extreme warmaster's potion", 93, 500, {
    "Extreme attack (4)", "Extreme strength (4)", "Extreme defence (4)", "Extreme magic (4)", "Extreme ranging (4)",
})
combination("Supreme attack potion", 93, 240, { "Extreme attack (4)", "Super attack (4)" })
combination("Supreme strength potion", 93, 266.3, { "Extreme strength (4)", "Super strength (4)" })
combination("Supreme defence potion", 93, 292.5, { "Extreme defence (4)", "Super defence (4)" })
combination("Supreme ranging potion", 93, 217.5, { "Extreme ranging (4)", "Super ranging potion (4)" })
combination("Supreme magic potion", 93, 316.9, { "Extreme magic (4)", "Super magic potion (4)" })
combination("Brightfire potion", 94, 300, { "Super antifire (4)", "Prayer renewal (4)" })
combination("Super prayer renewal potion", 96, 208.2, { "Prayer renewal (4)", "Prayer potion (4)" })
combination("Aggroverload", 96, 325, { "Overload (4)", "Aggression potion (4)", "Clean arbuck" })
combination("Holy overload potion", 97, 350, { "Overload (4)", "Prayer renewal (4)" })
combination("Searing overload potion", 97, 350, { "Overload (4)", "Super antifire (4)" })
combination("Overload salve", 97, 500, {
    "Overload (4)", "Prayer renewal (4)", "Prayer potion (4)", "Super antipoison (4)", "Antifire (4)", "Super antifire (4)",
})
combination("Supreme overload potion", 98, 600, {
    "Overload (4)", "Super attack (4)", "Super strength (4)", "Super defence (4)",
    "Super ranging potion (4)", "Super magic potion (4)", "Super necromancy (4)",
})
combination("Supreme overload salve", 99, 700, {
    "Supreme overload potion (6)", "Prayer renewal (4)", "Prayer potion (4)",
    "Super antipoison (4)", "Antifire (4)", "Super antifire (4)",
})
combination("Perfect plus potion", 99, 1000, { "Overload (4)", "Harmony moss", "Crystal tree blossom" })
combination("Spiritual prayer potion", 110, 850, { "Prayer potion (4)", "Summoning potion (4)", "Primal extract" })
-- No crystal flask: the supreme overload is the base (assumed not saveable).
potion("Elder overload potion", 106, 850, "Supreme overload potion (6)",
    { saveable("Primal extract"), saveable("Clean fellstalk") }, "Combination potions", { "combination" })

---------------------------------------------------------------------------
-- Tar and primal extract (the Scroll of cleansing doesn't work on tar)
---------------------------------------------------------------------------

tar("guam", 19, 30)
tar("marrentill", 31, 42.5)
tar("tarromin", 39, 55)
tar("harralander", 44, 72.5)

-- 145 XP per fruit pulp at any level; higher levels fill more vials per pulp.
add("Primal extract", "Primal extract (1 per pulp, below level 102)", 90, 145,
    { item("Primal fruit pulp"), item("Vial") }, { "extract" })
add("Primal extract", "Primal extract (2 per pulp, level 102-111)", 102, 145,
    { item("Primal fruit pulp"), item("Vial", 2) }, { "extract" })
add("Primal extract", "Primal extract (3 per pulp, level 112+)", 112, 145,
    { item("Primal fruit pulp"), item("Vial", 3) }, { "extract" })

return activities
