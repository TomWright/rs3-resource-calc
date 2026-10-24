-- format.lua
-- Small text-formatting helpers shared by the UI and the console output.

local format = {}

--- 1234567 -> "1,234,567"
function format.number(value)
    local text = tostring(math.floor(value + 0.5))
    local sign, digits = text:match("^(-?)(%d+)$")
    if digits == nil then
        return text
    end
    local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return sign .. grouped:gsub("^,", "")
end

--- XP values keep one decimal place, like the game: 56.2, 1,250.5
function format.xp(value)
    local rounded = math.floor(value * 10 + 0.5) / 10
    local whole = math.floor(rounded)
    local tenth = math.floor((rounded - whole) * 10 + 0.5)
    if tenth == 0 then
        return format.number(whole)
    end
    return format.number(whole) .. "." .. tenth
end

--- 6 -> "+6%", 2.5 -> "+2.5%"
function format.percent(value)
    if value == math.floor(value) then
        return string.format("%+d%%", value)
    end
    return string.format("%+.1f%%", value)
end

--- "SMITHING" -> "Smithing"
function format.skillName(skillKey)
    return skillKey:sub(1, 1) .. skillKey:sub(2):lower()
end

return format
