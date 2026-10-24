-- prayer.lua
-- Prayer activities: one action is burying (or scattering) one bone/ash.
-- The XP here is the plain burying XP. Offering at an altar, the Ectofuntus,
-- powder of burials etc. are bonuses in data/effects.lua, detected or ticked
-- in the panel, because the same bones can be used in all of those ways.
-- Values from each item's page on https://runescape.wiki, checked October 2026.

local activities = {}

local function bones(name, xp, extraTags)
    local tags = { bones = true }
    for _, tag in ipairs(extraTags or {}) do
        tags[tag] = true
    end
    table.insert(activities, {
        skill = "PRAYER", group = "Bones",
        name = name, level = 1, xp = xp,
        inputs = { { item = name, qty = 1 } }, tags = tags,
    })
end

local function ashes(name, xp)
    table.insert(activities, {
        skill = "PRAYER", group = "Ashes",
        name = name, level = 1, xp = xp,
        inputs = { { item = name, qty = 1 } }, tags = { ashes = true },
    })
end

-- Bones the Dragon Rider amulet doubles are tagged "dragon_bones".
bones("Bones", 4.5)
bones("Wolf bones", 4.5)
bones("Bat bones", 5.3)
bones("Big bones", 15)
bones("Jogre bones", 15)
bones("Zogre bones", 22.5)
bones("Shaikahan bones", 25)
bones("Baby dragon bones", 30, { "dragon_bones" })
bones("Wyvern bones", 50)
bones("Dragon bones", 72, { "dragon_bones" })
bones("Fayrg bones", 84)
bones("Raurg bones", 96)
bones("Dagannoth bones", 125)
bones("Airut bones", 132.5)
bones("Ourg bones", 140)
bones("Hardened dragon bones", 144, { "dragon_bones" })
bones("Dragonkin bones", 160, { "dragon_bones" })
bones("Dinosaur bones", 170)
bones("Frost dragon bones", 180, { "dragon_bones" })
bones("Reinforced dragon bones", 190, { "dragon_bones" })
bones("Colossal bone", 400)

ashes("Impious ashes", 4)
ashes("Accursed ashes", 12.5)
ashes("Infernal ashes", 62.5)
ashes("Tortured ashes", 90)
ashes("Searing ashes", 200)

return activities
