-- firemaking.lua
-- Firemaking activities. One "action" is burning one log (or root):
--   * lighting: lighting a log on the ground (a "fire line")
--   * bonfire:  adding a log to a fire that's already burning
-- These give different base XP for most logs, so each log has a separate
-- lighting and bonfire activity. The bonfire numbers are for one player on
-- the fire; the +1% to +4% for more players (or a permanent bonfire) is a
-- bonus in data/effects.lua.
--
-- Values from each item's own page on https://runescape.wiki (the
-- "Firemaking info" box), cross-checked against
-- https://runescape.wiki/w/Firemaking, https://runescape.wiki/w/Bonfire and
-- https://runescape.wiki/w/Module:Skill_calc/Firemaking/data, checked
-- October 2026. Where those pages disagree, the item's own page is used.
--
-- Deliberately left out:
--   * Bonfire XP for maple, yew and acadia logs: it goes up with your
--     Firemaking level (maple 135 at level 45 up to 175 at 99, yew 220 at 60
--     up to about 260 at 99), and the plugin can't scale XP by level yet.
--     Lighting them is included.
--   * Bonfire XP for corrupted magic logs and blisterwood logs: the wiki
--     pages give conflicting numbers.
--   * Portable braziers (being removed on 23 November 2026), protean logs
--     (XP depends on your level), pyre logs (Shades of Mort'ton cremation),
--     and logs burned while chopping (inferno adze, Always Adze, Superheat
--     Form): these don't fit a "logs needed per XP" plan.

local activities = {}

-- Turns a list of tag names into a set, starting from `base`.
local function tagSet(base, extraTags)
    local tags = {}
    for tag, value in pairs(base) do
        tags[tag] = value
    end
    for _, tag in ipairs(extraTags or {}) do
        tags[tag] = true
    end
    return tags
end

-- Adds the lighting activity for a log and, if `bonfireXp` is given, the
-- bonfire one as well. Both use one log per action.
local function log(name, level, lightXp, bonfireXp, extraTags)
    local input = { { item = name, qty = 1 } }
    table.insert(activities, {
        skill = "FIREMAKING", group = "Lighting logs",
        name = name .. " (lighting)", level = level, xp = lightXp,
        inputs = input, tags = tagSet({ logs = true, lighting = true }, extraTags),
    })
    if bonfireXp ~= nil then
        table.insert(activities, {
            skill = "FIREMAKING", group = "Bonfire",
            name = name .. " (bonfire)", level = level, xp = bonfireXp,
            inputs = input, tags = tagSet({ logs = true, bonfire = true }, extraTags),
        })
    end
end

-- Adds something that's burned in one particular place (a firepit, a
-- brazier...), one item per action.
local function burn(group, name, level, xp, tags)
    table.insert(activities, {
        skill = "FIREMAKING", group = group,
        name = name, level = level, xp = xp,
        inputs = { { item = name, qty = 1 } }, tags = tags,
    })
end

--  name                    level  lighting  bonfire
-- "normal_or_oak": the Dwarven army axe adds 3 XP to these.
log("Logs",                     1,     40,      50, { "normal_or_oak" })
log("Achey tree logs",          1,     40,      50)
log("Oak logs",                15,     60,      85, { "normal_or_oak" })
log("Willow logs",             30,     90,     105)
log("Teak logs",               35,    105,     120)
log("Arctic pine logs",        42,    125,     130)
log("Maple logs",              45,    135)               -- bonfire XP scales with level
log("Acadia logs",             47,    140)               -- bonfire XP scales with level
-- Mahogany's own page also mentions 170.3 bonfire XP; its info box, the
-- Bonfire page and the wiki calculator all say 180.
log("Mahogany logs",           50,    157.5,   180)
log("Eucalyptus logs",         58,    193.5,   195)
log("Yew logs",                60,    202.5)             -- bonfire XP scales with level
log("Magic logs",              75,    303.8,   309.5)
log("Corrupted magic logs",    75,    319)               -- bonfire XP unclear
-- Cut and burned in the Spirit Realm; they turn into magic logs if you
-- carry them back out through the portal.
log("Cursed magic logs",       75,    303.8,   309.5)
log("Blisterwood logs",        76,    303.5)             -- bonfire XP unclear
log("Elder logs",              90,    434.3,   449)
-- Found on the Uncharted Isles; can go on permanent bonfires too.
log("Driftwood",               92,    454,     563.5)
log("Eternal magic logs",     100,    552,     553)

-- Coloured logs: normal logs with a gnomish firelighter used on them. They
-- give 10 XP more than normal logs when lit (no bonfire XP is documented).
log("Red logs",                 1,     50)
log("Green logs",               1,     50)
log("Blue logs",                1,     50)
log("Purple logs",              1,     50)
log("White logs",               1,     50)

-- Curly roots can only be burned on the firepits in the Jadinko Lair.
burn("Jadinko Lair", "Curly root", 83, 378.7, { curly_roots = true })

-- Petrified wood from Fenmoor (Havenhythe, added 28 September 2026), added
-- to the swamp braziers next to the petrified trees. The wiki pages for
-- these are still stubs, so re-check the numbers if they look off.
burn("Swamp brazier", "Petrified roots", 67, 457.6, { petrified = true })
burn("Swamp brazier", "Petrified bark", 85, 702, { petrified = true })
burn("Swamp brazier", "Petrified logs", 103, 1029.6, { petrified = true })

return activities
