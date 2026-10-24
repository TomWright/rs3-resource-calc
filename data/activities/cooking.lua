-- cooking.lua
-- Cooking activities. One "action" is cooking one item: one raw fish into
-- one cooked fish, one raw pie into a pie, one bowl of port soup, or one jug
-- of wine (grapes + jug of water, fermented).
-- Burning isn't modelled: every action is assumed to succeed, as if wearing
-- a Cooking cape (which stops all food burning). Likewise wine assumes no
-- jugs of bad wine (they stop at level 68). Burnt food gives no XP, so below
-- the no-burn level you'll need extra raw food.
-- Values from each item's Infobox Recipe on https://runescape.wiki (e.g.
-- https://runescape.wiki/w/Shark) and https://runescape.wiki/w/Cooking,
-- checked October 2026.
--
-- Tags bonuses can target (see data/effects.lua):
--   cooking        every activity here
--   fish           cooked fish
--   bonfire_cooking  gets the +10% player-made bonfire bonus when cooked on one
--   fire_or_range  cooked on a fire or range (Dwarven army axe +3 XP applies)
--   cooking_urn    fills cooking urns (wine doesn't)
--   kitchen        can be cooked inside the Fort Forinthry kitchen
--   soup           port soups (Player-owned port workshop bonus applies)

local activities = {}

-- Adds an activity. `tags` is a list of tag names; "cooking" is always added.
local function add(group, name, level, xp, inputs, tags)
    local tagSet = { cooking = true }
    for _, tag in ipairs(tags) do
        tagSet[tag] = true
    end
    table.insert(activities, {
        skill = "COOKING", group = group,
        name = name, level = level, xp = xp, inputs = inputs, tags = tagSet,
    })
end

local function item(name, qty)
    return { item = name, qty = qty or 1 }
end

-- A fish cooked on a fire or range, one raw fish per action.
local function fish(name, level, xp, raw)
    add("Fish", name, level, xp, { item(raw) },
        { "fish", "fire_or_range", "cooking_urn", "kitchen", "bonfire_cooking" })
end

-- A fish that doesn't get the bonfire bonus (no "bonfire_cooking" tag).
local function fishNoBonfire(name, level, xp, raw)
    add("Fish", name, level, xp, { item(raw) },
        { "fish", "fire_or_range", "cooking_urn", "kitchen" })
end

-- A port soup: one cooked fish plus one spice, made at the Cooking Station in
-- a player-owned port workshop or the soup creation station in a tier 3 Fort
-- Forinthry kitchen. Needs the Eastern Soups Recipe scroll. Can't be burnt.
local function soup(name, level, xp, cookedFish)
    add("Soups", name, level, xp, { item(cookedFish), item("Spices") },
        { "soup", "cooking_urn", "kitchen" })
end

fish("Shrimps", 1, 30, "Raw shrimps")
fish("Crayfish", 1, 30, "Raw crayfish")
fish("Anchovies", 1, 30, "Raw anchovies")
fish("Sardine", 1, 40, "Raw sardine")
fish("Herring", 5, 50, "Raw herring")
fish("Mackerel", 10, 60, "Raw mackerel")
fish("Trout", 15, 70, "Raw trout")
fish("Cod", 18, 75, "Raw cod")
fish("Pike", 20, 80, "Raw pike")
fish("Salmon", 25, 90, "Raw salmon")
-- The wiki says slimy eels give 95 XP "on a range or bonfire", i.e. no bonus.
fishNoBonfire("Cooked slimy eel", 28, 95, "Slimy eel")
fish("Tuna", 30, 100, "Raw tuna")
-- Needs Tai Bwo Wannai Trio (and learning from Tiadeche); otherwise you only
-- make poison karambwan.
fish("Cooked karambwan", 30, 190, "Raw karambwan")
fish("Rainbow fish", 35, 110, "Raw rainbow fish")
fish("Cave eel", 38, 115, "Raw cave eel")
fish("Lobster", 40, 120, "Raw lobster")
fish("Bass", 43, 130, "Raw bass")
fish("Swordfish", 45, 140, "Raw swordfish")
-- Desert sole, catfish and beltfish don't get the bonfire bonus
-- (https://runescape.wiki/w/Bonfire).
fishNoBonfire("Desert sole", 52, 142.5, "Raw desert sole")
fish("Claret crab", 56, 144, "Raw claret crab")
fishNoBonfire("Catfish", 60, 145, "Raw catfish")
fish("Monkfish", 62, 150, "Raw monkfish")
-- Not on the wiki's bonfire exception list, but no page confirms the bonus
-- either, so it's left off to be safe.
fishNoBonfire("Ghostly sole", 66, 160, "Raw ghostly sole")
fish("Hogfish", 69, 170, "Raw hogfish")
-- Beltfish give less XP on a fire than on a range.
fishNoBonfire("Beltfish (range)", 72, 180, "Raw beltfish")
fishNoBonfire("Beltfish (fire)", 72, 165, "Raw beltfish")
fish("Green blubber jellyfish", 72, 165, "Raw green blubber jellyfish")
fish("Baron shark", 80, 210, "Raw baron shark")
fish("Shark", 80, 210, "Raw shark")
fish("Sea turtle", 82, 211.3, "Raw sea turtle")
fish("Great white shark", 84, 212, "Raw great white shark")
fish("Giant crayfish", 86, 212, "Raw giant crayfish")
fish("Cavefish", 88, 214, "Raw cavefish")
fish("Manta ray", 91, 216, "Raw manta ray")
fish("Rocktail", 93, 225, "Raw rocktail")
fish("Tiger shark", 95, 230, "Raw tiger shark")
fish("Blue blubber jellyfish", 95, 235, "Raw blue blubber jellyfish")
fish("Sailfish", 99, 270, "Raw sailfish")

soup("Rocktail soup", 93, 500, "Rocktail")
soup("Sailfish soup", 99, 600, "Sailfish")

-- Cooking a raw summer pie on a range (it can't go on a fire). Putting the
-- raw pie together isn't counted.
add("Pies", "Summer pie", 95, 260, { item("Raw summer pie") },
    { "fire_or_range", "cooking_urn", "kitchen" })

-- 1 XP for adding the grapes plus 200 when the wine ferments. Wine doesn't
-- fill cooking urns and the Dwarven army axe doesn't affect it.
add("Wine", "Jug of wine", 35, 201, { item("Grapes"), item("Jug of water") },
    { "wine" })

return activities
