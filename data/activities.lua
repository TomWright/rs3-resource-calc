-- activities.lua
-- Collects every skill's activities, keyed by SkillType key. To add a skill,
-- create data/activities/<skill>.lua (see smithing.lua for the format) and
-- add it here. Each activity needs:
--   skill   SkillType key, e.g. "SMITHING"
--   name    shown in the panel
--   level   level required
--   xp      base XP per action
--   inputs  resources used per action: { { item = "Exact item name", qty = 1 }, ... }
--           (the first input is the one shown on the on-screen overlay)
--   tags    labels bonuses can target, e.g. { smelting = true }
-- and optionally:
--   group   the group it's listed under in the panel (e.g. "Smelting")
--   item, tier  for activities that are one item taken to different tiers
--           (smithing upgrades): `item` is listed once, and a second
--           dropdown picks the `tier`

return {
    SMITHING = require("data/activities/smithing"),
    PRAYER = require("data/activities/prayer"),
    COOKING = require("data/activities/cooking"),
    FIREMAKING = require("data/activities/firemaking"),
    FLETCHING = require("data/activities/fletching"),
    CRAFTING = require("data/activities/crafting"),
    HERBLORE = require("data/activities/herblore"),
}
