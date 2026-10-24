-- skills.lua
-- Every skill: its SkillType key (as used by the client API), display name,
-- current maximum level and XP curve. Levels past the maximum are shown as
-- "virtual" levels. Max levels from https://runescape.wiki/w/Skills
-- (checked October 2026; several skills went to 110/120 during 2024-2026).

local list = {
    { key = "ATTACK",        label = "Attack",        maxLevel = 120 },
    { key = "STRENGTH",      label = "Strength",      maxLevel = 120 },
    { key = "DEFENCE",       label = "Defence",       maxLevel = 99 },
    { key = "RANGED",        label = "Ranged",        maxLevel = 120 },
    { key = "PRAYER",        label = "Prayer",        maxLevel = 99 },
    { key = "MAGIC",         label = "Magic",         maxLevel = 120 },
    { key = "HITPOINTS",     label = "Constitution",  maxLevel = 99 },
    { key = "NECROMANCY",    label = "Necromancy",    maxLevel = 120 },
    { key = "CRAFTING",      label = "Crafting",      maxLevel = 110 },
    { key = "MINING",        label = "Mining",        maxLevel = 110 },
    { key = "SMITHING",      label = "Smithing",      maxLevel = 110 },
    { key = "FISHING",       label = "Fishing",       maxLevel = 99 },
    { key = "COOKING",       label = "Cooking",       maxLevel = 99 },
    { key = "FIREMAKING",    label = "Firemaking",    maxLevel = 110 },
    { key = "WOODCUTTING",   label = "Woodcutting",   maxLevel = 110 },
    { key = "RUNECRAFTING",  label = "Runecrafting",  maxLevel = 110 },
    { key = "DUNGEONEERING", label = "Dungeoneering", maxLevel = 120 },
    { key = "FLETCHING",     label = "Fletching",     maxLevel = 110 },
    { key = "AGILITY",       label = "Agility",       maxLevel = 99 },
    { key = "HERBLORE",      label = "Herblore",      maxLevel = 120 },
    { key = "THIEVING",      label = "Thieving",      maxLevel = 120 },
    { key = "SLAYER",        label = "Slayer",        maxLevel = 120 },
    { key = "FARMING",       label = "Farming",       maxLevel = 120 },
    { key = "CONSTRUCTION",  label = "Construction",  maxLevel = 120 },
    { key = "HUNTER",        label = "Hunter",        maxLevel = 110 },
    { key = "SUMMONING",     label = "Summoning",     maxLevel = 99 },
    { key = "DIVINATION",    label = "Divination",    maxLevel = 99 },
    { key = "INVENTION",     label = "Invention",     maxLevel = 120, curve = "elite" },
    { key = "ARCHAEOLOGY",   label = "Archaeology",   maxLevel = 120 },
}

local byKey = {}
for _, skill in ipairs(list) do
    skill.curve = skill.curve or "standard"
    byKey[skill.key] = skill
end

return {
    list = list,
    byKey = byKey,
    eliteXp = require("data/elite_xp"),
}
