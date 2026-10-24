-- xp.lua
-- Converts between skill levels and experience (XP) using RuneScape 3's curves.
-- Pure Lua: no game API calls, so it can be unit tested outside the client.

local xp = {}

-- No skill can hold more than 200 million XP.
xp.MAX_XP = 200000000

-- The highest level we build tables for. Levels above a skill's real cap are
-- "virtual" levels; we still compute them so targets like "level 120" work.
local MAX_TABLE_LEVEL = 126

-- Standard curve, used by almost every skill:
--   XP(L) = floor( (1/4) * sum_{n=1}^{L-1} floor(n + 300 * 2^(n/7)) )
local standard = { [1] = 0 }
do
    local points = 0
    for level = 1, MAX_TABLE_LEVEL - 1 do
        points = points + math.floor(level + 300 * 2 ^ (level / 7))
        standard[level + 1] = math.floor(points / 4)
    end
end

-- Elite curve (Invention). It has no simple formula, so the XP for each level
-- is listed directly. Filled in by xp.setEliteTable() from data/skills.lua.
local elite = nil

--- Supplies the elite (Invention) XP table: an array where index L is the XP
--- needed for level L.
function xp.setEliteTable(tbl)
    elite = tbl
end

local function curveFor(curveName)
    if curveName == "elite" and elite ~= nil then
        return elite
    end
    return standard
end

--- Returns the total XP needed to reach `level` on the named curve
--- ("standard" or "elite"). Levels past the table are clamped to MAX_XP.
function xp.forLevel(level, curveName)
    local curve = curveFor(curveName)
    if level <= 1 then
        return 0
    end
    local value = curve[level]
    if value == nil or value > xp.MAX_XP then
        return xp.MAX_XP
    end
    return value
end

--- Returns the (possibly virtual) level that `totalXp` corresponds to.
function xp.levelFor(totalXp, curveName)
    local curve = curveFor(curveName)
    local level = 1
    while curve[level + 1] ~= nil and curve[level + 1] <= totalXp do
        level = level + 1
    end
    return level
end

return xp
