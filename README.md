# Resource Calculator

A RuneScape 3 planning plugin. Tell it your starting level, your goal and the
activity you'll train with, and it tells you **how many resources to gather**,
taking your XP bonuses into account and explaining each one.

> Smithing 60 -> level 70: 463,885 XP to go
> Gold bar x 62,519 (7.4 XP each)
> 62,519 Gold ore - you have 300 (gather 62,219 more)
> - Base XP: 7 per action
> - Blacksmith's outfit (5/5 pieces worn): +6%
> - Total: 7.4 XP per action (+6% overall)

Covers 749 activities in seven skills:

| Skill | What's included |
| --- | --- |
| Smithing | Smelting every bar; smithing items of every metal, at every upgrade tier, as burial items and as burial sets |
| Prayer | Bones and ashes, every altar and offering method |
| Cooking | Every fish, port soups, summer pie, wine |
| Firemaking | Every log (lighting and bonfires), curly roots, petrified wood |
| Fletching | Shafts, bows, stringing, arrows, bolts, darts, Mk. upgrades, totems |
| Crafting | Gems, jewellery, leather and dragonhide, battlestaves, glass, urns, tailoring |
| Herblore | Cleaning, unfinished potions, potions, juju and combination potions, tar |

Assumptions: cooking assumes you don't burn anything, and items that give
extra output with no XP (e.g. the crystal chisel's extra gem) aren't counted.

## What it takes into account

Every bonus can be set on the **Bonuses** tab to **Auto**, **Off**, or the way
you plan to use it (e.g. "3/5 pieces", "Gilded altar, 2 burners lit",
"Exquisite urn"), so you can plan for gear you don't own yet. **Auto** uses
what the plugin can see right now:

| Source | What Auto looks at |
| --- | --- |
| Skilling outfits (e.g. Blacksmith's, Botanist's, Fletcher's) | Your worn equipment, piece by piece |
| XP-changing items (e.g. Ring of forging, Dwarven army axe, Crafting cape) | Worn equipment / backpack |
| Altars and stations (e.g. gilded altar, Ectofuntus, fletching workbench) | Scenery within 8 tiles of you |
| Areas (e.g. the Wilderness, Fort Forinthry's kitchen and Ranger's Workroom) | Your current tile |
| Things the plugin can't see (urns, Double XP, Voice of Seren, clan avatar, unlocks) | Nothing: Off until you choose them |

Bonuses stack the way the RuneScape Wiki's experience calculator describes
(see the comment at the top of `src/calculator.lua`). Altars and the
Ectofuntus switch off bonuses that don't work with them (e.g. Double XP).

"You have" counts your backpack, plus your bank and metal bank once you've
opened them this session.

Data for skills, activities and bonuses lives in `data/`, sourced from the
RuneScape Wiki (checked October 2026), and is meant to be easy to extend; see
the comments at the top of each file. Items that have been removed from the
game (Goldsmith gauntlets, auras, the portable forge) are deliberately left
out. Portable skilling stations are due to be removed on 23 November 2026,
which is why none are included.

## Using it

1. Right-click a skill in the Skills tab and choose **Calculate** to open the
   calculator window for that skill. Drag the window by its title bar to move
   it; it opens in the same place next time. (The plugin's icon in the
   **Plugins** window also has a button to reopen it for the last skill.)
2. **Plan** tab: pick the activity (grouped, e.g. Smelting / Adamant items).
   With **Hide items above my level** ticked (the default), only activities
   your starting level allows are listed; untick it to plan for things you'll
   unlock later (the plan notes the level they need). Smithing items are
   listed by the bars they use (every item of a metal gives the same XP per
   bar), and **Make** beside them picks how far you'll take each one: the
   base item, an upgrade (+1 to +5, made from bars) or burial. A burial set
   counts making, upgrading and burying all five armour pieces.
3. **From**: the level you're starting at. Leave it empty to use your current XP.
4. **To**: a level (up to 150) or an XP amount (e.g. `5m`). Leave it empty to
   use the target you've set on the skill in-game, or the next level.
5. **Bonuses** tab: every bonus that applies to the activity, one per row,
   with how you'll use it: **Auto** (what you're wearing or standing near
   now), **Off**, or an option to plan for (e.g. "Full set (5/5)"). Hover a
   setting for a description.
6. **Why** tab: how the XP per action was worked out. **Show on screen** keeps
   a one-line summary on the game screen.

The full report is also printed to the client console (`ALT` + `` ` ``) when
you open the plugin from the Plugins window.

The interface is built with **PrettyUI**, a library plugin that's installed
along with this one (it's a required dependency).

## Developing

Plugin files live in `C:\ProgramData\Jagex\RuneScape-BETA\dev_plugins\resource-calc`.
In the beta world's console: `prf` (refresh), `pon resource-calc` (enable),
`prl resource-calc` (reload after editing).

Tests run outside the game with any Lua 5.4 interpreter, from this folder:

```
lua tests/run_tests.lua     # unit tests for the maths and data
lua tests/smoke_test.lua    # loads main.lua against a fake client
```

`tools/package.ps1` builds the upload zip (in `dist/`) with only `main.lua`,
`plugin.json`, `src/` and `data/`. `docs/` is a local copy of
developer.runescape.com for reference; it's Jagex's, so it stays out of both
the zip and the git repository. `MODIO.md` has the text for the Mod.io page
and a checklist to go through for each upload.

The interface uses the PrettyUI library plugin (by rsnJ3), declared in
`plugin.json` as `"requiredDependencies": { "PrettyUI": "6398181" }`, which
makes it available as the global `PrettyUI`. When uploading to Mod.io, add
PrettyUI as a dependency there too (a required dependency in the manifest
must match one on Mod.io). Only `src/view.lua` uses it; the smoke test uses a
fake of the parts it needs (`tests/mock_client.lua`).

Dependencies are found by **folder name**. The plugin hub installs plugins
in folders named by their Mod.io ID, so PrettyUI is `6398181` (`plist` in the
console lists every plugin's name). For local testing, install PrettyUI from
the plugin hub; the dev client finds it there too.

### Things to check in-game (not verifiable outside the client)

- **Worn equipment**: the docs don't name the equipment inventory. `src/game.lua`
  tries `WORN`, `WORN_ITEMS` and `EQUIPMENT`. If gear isn't detected, run `pan Inv`
  in the console and add the right name there.
- **Window layout**: `src/view.lua` lays out the tabs with fixed sizes based
  on PrettyUI's window frame (40 high) and tab buttons (42 high); adjust
  `WINDOW_FRAME` / `TAB_HEADER` if PrettyUI changes them.
- **"Calculate" on skills**: the Skills tab's menu entries ("View Skillguide",
  "Set Level Target"...) don't name the skill, so each skill is recognised by
  the entries' `subjectHash` (`SKILLS_TAB_HASHES` in `main.lua`, one per skill
  the plugin covers). If a game update moves the Skills tab around, log
  `entry.subjectHash` in `Event.MiniMenuOpened` to find the new values.
- **Dropdowns**: the client's own dropdown sorts entries alphabetically and,
  in testing, selected by position rather than ID. `src/view.lua` gives every
  entry an `order`, which makes PrettyUI use its ordered dropdown instead
  (it keeps our order and tracks the selection itself).
- **In-game skill targets**: read from the VarPlayers `STATS_TARG_01` to
  `STATS_TARG_29` (SkillType + 1; Smithing is 14), found with `pan VarPlayer`.
  On load the plugin logs every target it can see ("In-game skill targets:
  ...") so the numbering and the level/XP split can be confirmed.
- **Area bounds** in `data/areas.lua`: confirm with the `getcoord` cheat.

Useful cheats for testing: `!skillsetxp`, `!give`, `!tele`, `!getcoord`.

## Data protection & permissions

This plugin requests **no permissions**. Everything it reads stays on your
machine: your settings are saved with the plugin's own PersistentDB storage and
nothing is sent anywhere (data protection case 1).

Contact: contact@tomwright.me

## License

MIT; see [LICENSE](LICENSE).
