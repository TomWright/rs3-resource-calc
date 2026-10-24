-- areas.lua
-- Map areas some bonuses depend on, as rectangles of world tiles (x/z as in
-- CoordGrid; the RuneScape Wiki calls z "y"). Check bounds in-game with the
-- `getcoord` cheat if a bonus isn't detected where it should be.

local areas = {}

-- The Wilderness, north of the wall at Edgeville. Covers both chaos altars
-- (the level 12 Chaos Temple at 3239,3608 and the level 38 hut at 2951,3821).
areas.WILDERNESS = {
    id = "wilderness", name = "the Wilderness",
    minX = 2944, maxX = 3391, minZ = 3520, maxZ = 3967,
}

-- The Fort Forinthry kitchen. Bounds from the area map on
-- https://runescape.wiki/w/Kitchen; the range (3317,3570), sink (3317,3567)
-- and soup creation station (3314,3571) are all inside.
areas.FORT_KITCHEN = {
    id = "fort_kitchen", name = "the Fort Forinthry kitchen",
    minX = 3312, maxX = 3319, minZ = 3566, maxZ = 3573,
}

-- Fort Forinthry's Ranger's Workroom. Bounds from the wiki's area map of the
-- building (https://runescape.wiki/w/Ranger%27s_Workroom); the fletching
-- workbench inside is at 3290,3538. The edges may be a tile off.
areas.RANGERS_WORKROOM = {
    id = "rangers_workroom", name = "the Ranger's Workroom",
    minX = 3287, maxX = 3292, minZ = 3532, maxZ = 3541,
}

-- The list main.lua checks the player's position against.
areas.list = { areas.WILDERNESS, areas.FORT_KITCHEN, areas.RANGERS_WORKROOM }

return areas
