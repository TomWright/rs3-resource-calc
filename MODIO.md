# Mod.io listing

The text for the plugin's page on Mod.io, kept here so it changes along with
the code. Copy each part into the matching field when adding the plugin
("Add plugin" on the RuneScape page on Mod.io) or editing it later. Field
rules come from developer.runescape.com/rs/submission/process.html.

## Upload checklist

- [ ] Tests pass and the "Things to check in-game" list in the README has
      been checked in the beta client.
- [ ] `version` in `plugin.json` is the version you'll enter on Mod.io
      (numbers and full stops only).
- [ ] Build the zip: `powershell -File tools\package.ps1`, which writes
      `dist/resource-calc-<version>.zip` with `main.lua` and `plugin.json` at
      the top level.
- [ ] **Listing image**: 16:9, at least 512x288 (e.g. a screenshot of the
      calculator window over the game).
- [ ] **Media** (optional): screenshots of the Plan, Bonuses and Why tabs.
- [ ] **Homepage**: https://github.com/TomWright/rs3-resource-calc
- [ ] **Dependencies**: add PrettyUI. It's a required dependency in
      `plugin.json`, so it must be a dependency on Mod.io too.
- [ ] **Upload file**: tick Windows, Linux, Android, iOS and Source.
- [ ] **Tags**: no permission tags are needed (the plugin requests none).
- [ ] Optional: the contact email can be hidden from the public page (allowed
      for data protection case 1) by adding this line at the end of the
      description: "For Jagex: I request that the supplied email is hidden
      from public view."

## Plugin name

Resource Calculator

## Summary

ASCII only, 10 to 250 characters.

```
Plan your skilling: pick a skill, a start and goal level and an activity, and see how many resources to gather, with every XP bonus (outfits, altars, urns, Double XP) taken into account and explained.
```

## Description

Everything below the line goes in the Description field.

---

**Resource Calculator** answers "how many do I need?" Tell it the level
you're starting at, the level (or XP) you're aiming for and the activity
you'll train with, and it tells you how many resources to gather. It takes
your XP bonuses into account and explains each one.

> Smithing 60 -> level 70: 463,885 XP to go
> Gold bar x 62,519 (7.4 XP each)
> 62,519 Gold ore - you have 300 (gather 62,219 more)
> - Base XP: 7 per action
> - Blacksmith's outfit (5/5 pieces worn): +6%
> - Total: 7.4 XP per action (+6% overall)

### Skills covered

749 activities across seven skills:

- **Smithing**: smelting every bar; smithing items of every metal, at every
  upgrade tier, as burial items and as burial sets
- **Prayer**: bones and ashes, every altar and offering method
- **Cooking**: every fish, port soups, summer pie, wine
- **Firemaking**: every log (lighting and bonfires), curly roots, petrified
  wood
- **Fletching**: shafts, bows, stringing, arrows, bolts, darts, Mk. upgrades,
  totems
- **Crafting**: gems, jewellery, leather and dragonhide, battlestaves, glass,
  urns, tailoring
- **Herblore**: cleaning, unfinished potions, potions, juju and combination
  potions, tar

### How to use it

1. Right-click a skill in the Skills tab and choose **Calculate**. (The
   plugin's icon in the Plugins window can also reopen it.)
2. **Plan** tab: pick the activity, the level you're starting **From** (empty
   = your current XP) and where you're going **To** (a level up to 150, or an
   XP amount such as `5m`; empty = the target you've set in-game, or the next
   level).
3. **Bonuses** tab: set each bonus to **Auto** (what you're wearing or
   standing near now), **Off**, or the way you plan to use it, e.g. "3/5
   pieces", "Gilded altar, 2 burners lit" or "Exquisite urn". This lets you
   plan for gear you don't own yet.
4. **Why** tab: how the XP per action was worked out. **Show on screen**
   keeps a one-line summary on the game screen.

"You have" counts your backpack, plus your bank and metal bank once you've
opened them this session.

The **Calculate** option only opens this plugin's window; it never sends
anything to the game server.

### Good to know

- Bonuses stack the way the RuneScape Wiki's experience calculator
  describes. Altars and the Ectofuntus switch off bonuses that don't work
  with them (e.g. Double XP).
- Cooking assumes you don't burn anything, and extra output that gives no
  XP (e.g. the crystal chisel's extra gem) isn't counted.
- Items that have been removed from the game (Goldsmith gauntlets, auras,
  the portable forge) aren't included, and neither are portable skilling
  stations, which are due to be removed on 23 November 2026.
- The interface is built with the **PrettyUI** library plugin, which is
  installed along with this one.
- Source code and issue reports: https://github.com/TomWright/rs3-resource-calc

### Email

The contact email address for this plugin is contact@tomwright.me.

### EULA

<!-- Replace this comment with the EULA statement, word for word, from the
"EULA" section of https://developer.runescape.com/rs/submission/example.html -->

### Permissions

This plugin requests no permissions.

### Data protection (case 1)

This plugin uses the following information from the game: your skill levels
and XP, the skill targets you've set in-game, your worn equipment, the items
in your backpack, bank and metal bank, scenery near you (to recognise altars
and workbenches) and the tile you're standing on (to recognise areas such as
the Wilderness).

This information is not transmitted outside of the plugin under any
circumstances.

Game information is not stored by the plugin between sessions. Plugin
settings (the skill, activity, levels and bonus choices you last used,
whether the on-screen summary is shown, and where the window was) are stored
between sessions.
