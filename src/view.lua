-- view.lua
-- Builds the plugin's interface with PrettyUI, a library plugin (a required
-- dependency, see plugin.json) whose windows, tabs and dropdowns look like
-- RuneScape's own:
--   * the calculator window, opened with "Calculate" on a skill's right-click
--     menu. It can be dragged by its title bar, and clicks on it don't reach
--     the game behind it.
--   * the panel in the Plugins window (ribbon icon), which explains how to
--     open the calculator and has a button to reopen it
--   * a small optional overlay line on the game screen
--
-- The calculator has three tabs:
--   Plan     group, activity (plus "Make": base item, +1 ... burial, for
--            smithing items), from/to levels, whether to hide what's above
--            your level, and what you need
--   Why      the bonuses applied, and the "Show on screen" button
--   Bonuses  every bonus that applies, one per row, each with how you'll
--            use it (Auto / Off / an option)
--
-- The view never calculates anything itself. It shows what main.lua gives it
-- and reports user input back through the `callbacks` table.

local PrettyUI = assert(PrettyUI, "Resource Calculator needs the PrettyUI plugin")

local view = {}

-- Layout inside a tab page (interface units). PrettyUI pages are scrollable,
-- so the text areas have fixed heights rather than filling the page.
local PAD = 14          -- space around a page's edges (PrettyUI's default)
local ROW = 30          -- dropdowns and text fields (PrettyUI's default height)
local GAP = 8
local INTRO = 44        -- the explanation at the top of the Bonuses tab
local NAME_SHARE = 0.4  -- a bonus row: name on the left, setting on the right
local TIER_WIDTH = 110  -- the "Make" dropdown beside smithing items

-- The calculator window. PrettyUI's title bar and bottom border take 40 of
-- its height and the tabs fill the rest; each tab's page is below the 42
-- high row of tab buttons.
local WINDOW_WIDTH, WINDOW_HEIGHT = 460, 520
local WINDOW_FRAME = 40
local TAB_HEADER = 42
local PAGE_HEIGHT = WINDOW_HEIGHT - WINDOW_FRAME - TAB_HEADER

---------------------------------------------------------------------------
-- Dropdowns
---------------------------------------------------------------------------

-- What each dropdown's entries stand for: comboValues[combo][entryId] = value.
local comboValues = setmetatable({}, { __mode = "k" })

-- Replaces a dropdown's entries and selects the one standing for
-- `selectedValue`. `entries` is a list of { label =, id = } where `id` is
-- the value reported when the entry is picked. Each entry's own ID is its
-- position, and `order` keeps them in our order.
local function fillEntries(combo, entries, selectedValue)
    local list, values, selectedId = {}, {}, nil
    for position, entry in ipairs(entries) do
        list[position] = { label = entry.label, id = position, order = position }
        values[position] = entry.id
        if entry.id == selectedValue then
            selectedId = position
        end
    end
    comboValues[combo] = values
    combo:SetEntries(list, selectedId)
end

-- Adds a dropdown to a tab page and calls `onPick(value)` with the value of
-- the entry the player picks. `place` sets its position and width.
-- Entries with an `order` make PrettyUI use its ordered dropdown, which
-- keeps our order and tracks the selection itself. (The client's own
-- dropdown sorts entries alphabetically, and in testing selected by
-- position instead of by ID.) Typing in it filters the list.
local function addDropdown(page, place, onPick)
    return page:AddComboBox({
        x = place.x or PAD, xAnchor = place.xAnchor, y = place.y,
        width = place.width or -2 * PAD, widthAnchor = place.widthAnchor or 1.0,
        maxVisibleEntries = 10,
        entries = { { label = "", id = 0, order = 0 } },
        onChange = function(combo, entryId)
            local value = (comboValues[combo] or {})[entryId]
            if value ~= nil then
                onPick(value)
            end
        end,
    })
end

-- Adds multi-line text to a tab page at `y`, `height` tall, full width.
local function addText(page, y, height, text)
    return page:AddText({
        text = text or "", x = PAD, y = y, width = -2 * PAD, widthAnchor = 1.0, height = height,
        alignVertical = ui.AlignMode.TOPLEFT, maxLines = 0,
    })
end

---------------------------------------------------------------------------
-- Activities and the "Make" dropdown
---------------------------------------------------------------------------

-- True if an activity can be done at the panel's level limit (if any).
local function available(panel, activity)
    return panel.maxLevel == nil or activity.level <= panel.maxLevel
end

-- True if two activities are tiers of the same item (see data/activities.lua).
local function sameItem(a, b)
    return a.item ~= nil and a.item == b.item and a.group == b.group
end

-- Fills the "Make" dropdown with the tiers of the activity at `index` (base
-- item, +1 ... burial) and selects it. The dropdown only shows when there's
-- a choice; otherwise the activity dropdown takes the full width.
local function fillTiers(panel, index)
    panel.current = index
    local selected = panel.activities[index or 0]
    local entries = {}
    for other, activity in ipairs(panel.activities) do
        if selected ~= nil and sameItem(activity, selected) and available(panel, activity) then
            table.insert(entries, { label = activity.tier, id = other })
        end
    end
    local showTier = #entries > 1
    fillEntries(panel.tier, entries, index)
    panel.tier.root.hidden = not showTier
    panel.activity.root:SetSize(-(2 * PAD + (showTier and TIER_WIDTH + GAP or 0)), ROW, 1.0, 0)
end

-- The activity for the item at `index` in the tier that was chosen before
-- (e.g. switching from platebody +2 to platelegs gives platelegs +2), or
-- `index` itself if that item doesn't have that tier.
local function keepTier(panel, index)
    local picked, current = panel.activities[index], panel.activities[panel.current or 0]
    if picked == nil or picked.item == nil or current == nil or current.tier == nil then
        return index
    end
    for other, activity in ipairs(panel.activities) do
        if sameItem(activity, picked) and activity.tier == current.tier and available(panel, activity) then
            return other
        end
    end
    return index
end

-- The first tier of the activity's item, which stands for the item in the
-- activity dropdown (the activity itself if it has no tiers).
local function firstTier(panel, index)
    local activity = panel.activities[index or 0]
    for other, candidate in ipairs(panel.activities) do
        if activity ~= nil and sameItem(candidate, activity) then
            return other
        end
    end
    return index
end

---------------------------------------------------------------------------
-- The calculator
---------------------------------------------------------------------------

-- Adds a row to the Bonuses tab: the bonus's name, and a dropdown of how
-- you'll use it. Rows are reused as the activity changes (see setBonuses);
-- `row.key` is the bonus currently shown in it.
local function addBonusRow(panel)
    local row = {}
    local y = PAD + INTRO + GAP + #panel.bonusRows * (ROW + GAP)
    row.name = panel.bonusPage:AddText({
        x = PAD, y = y, width = -(PAD + GAP / 2), widthAnchor = NAME_SHARE, height = ROW,
        alignVertical = ui.AlignMode.CENTRE, maxLines = 2,
    })
    row.setting = addDropdown(panel.bonusPage, { x = GAP / 2, xAnchor = NAME_SHARE, y = y,
        width = -(PAD + GAP / 2), widthAnchor = 1 - NAME_SHARE }, function(stateId)
        if row.key ~= nil then
            panel.callbacks.onBonus(row.key, stateId)
        end
    end)
    table.insert(panel.bonusRows, row)
    return row
end

--- Builds the calculator's tabs inside a window from view.buildWindow().
--- `callbacks` = { onActivity(index), onFrom(level or nil), onTo(value or nil),
---                 onHideLocked(bool), onBonus(key, stateId), onOverlay(bool) }
function view.buildPanel(window, callbacks)
    local panel = { callbacks = callbacks, bonusRows = {} }
    local tabs = window.ui:AddTabs({ "Plan", "Why", "Bonuses" }, { height = WINDOW_HEIGHT - WINDOW_FRAME })
    local plan, why, bonuses = tabs:GetPage(1), tabs:GetPage(2), tabs:GetPage(3)

    -- Plan tab: group, activity (and Make), the from/to row, the "hide"
    -- tick box, then the results. Created bottom first, so each dropdown's
    -- open list draws over the rows below it.
    local groupY = PAD
    local activityY = groupY + ROW + GAP
    local inputsY = activityY + ROW + GAP
    local hideY = inputsY + ROW + GAP
    local textY = hideY + ROW + GAP
    panel.planText = addText(plan, textY, PAGE_HEIGHT - textY - PAD)

    -- Ticked (the default): only list what your starting level can do.
    -- Unticked: list everything, to plan for things you'll unlock later.
    panel.hideLocked = plan:AddCheckboxButton({ { text = "Hide items above my level", value = "hide" } }, {
        x = PAD, y = hideY,
        onChange = function(_, _, _, selected) callbacks.onHideLocked(selected) end,
    })

    -- "From" left empty means "from my current XP". "To" left empty means
    -- the in-game target if one is set, otherwise the next level; up to 150
    -- is a level, anything bigger an XP amount (the client reads "5m" etc.).
    panel.fromInput = plan:AddTextField({
        x = PAD, y = inputsY, width = -(PAD + GAP / 2), widthAnchor = 0.5,
        placeholder = "From: current", filterMode = ui.InputFieldFilterMode.NUMERIC, maxLength = 3,
        onChange = function(field) callbacks.onFrom(field.root.contentQuantity) end,
    })
    panel.toInput = plan:AddTextField({
        x = GAP / 2, xAnchor = 0.5, y = inputsY, width = -(PAD + GAP / 2), widthAnchor = 0.5,
        placeholder = "To: next level", filterMode = ui.InputFieldFilterMode.QUANTITY, maxLength = 12,
        onChange = function(field) callbacks.onTo(field.root.contentQuantity) end,
    })

    -- "Make", right of the activity dropdown: how far to take the item.
    panel.tier = addDropdown(plan, { x = -(PAD + TIER_WIDTH), xAnchor = 1.0, y = activityY,
        width = TIER_WIDTH, widthAnchor = 0 }, function(index)
        panel.current = index
        callbacks.onActivity(index)
    end)
    panel.activity = addDropdown(plan, { y = activityY }, function(index)
        index = keepTier(panel, index)
        fillTiers(panel, index)
        callbacks.onActivity(index)
    end)
    -- Picking a group shows its activities and selects the first one.
    panel.group = addDropdown(plan, { y = groupY }, function(groupIndex)
        local index = view.fillActivities(panel, panel.groups[groupIndex], nil)
        if index ~= nil then
            callbacks.onActivity(index)
        end
    end)

    -- Why tab: the explanation, and the on-screen summary button below it.
    local buttonY = PAGE_HEIGHT - PAD - ROW
    panel.whyText = addText(why, PAD, buttonY - GAP - PAD)
    panel.overlayButton = why:AddSimpleButton("Show on screen", function(_, active)
        callbacks.onOverlay(active)
    end, { x = PAD, y = buttonY, toggleable = true })

    -- Bonuses tab: an explanation, then a row per bonus (added by setBonuses).
    panel.bonusPage = bonuses
    panel.bonusIntro = addText(bonuses, PAD, INTRO)

    return panel
end

--- Fills the activity dropdown with one group's available activities and
--- selects `selectedIndex` (if it's in the group), otherwise the first one,
--- keeping the tier chosen before. An item with tiers is listed once (its
--- tiers go in the "Make" dropdown). Values are positions in the skill's
--- full activity list. Returns the selected one.
function view.fillActivities(panel, group, selectedIndex)
    local selected = panel.activities[selectedIndex or 0]
    if selected == nil or (selected.group or "All") ~= group or not available(panel, selected) then
        selectedIndex = nil
    end
    local entries, listed = {}, {}
    for index, activity in ipairs(panel.activities) do
        local label = activity.item or activity.name
        if (activity.group or "All") == group and available(panel, activity) and not listed[label] then
            listed[label] = true
            table.insert(entries, { label = label, id = index })
        end
    end
    if selectedIndex == nil and entries[1] ~= nil then
        selectedIndex = keepTier(panel, entries[1].id)
    end
    fillEntries(panel.activity, entries, firstTier(panel, selectedIndex))
    fillTiers(panel, selectedIndex)
    return selectedIndex
end

--- Fills the group and activity dropdowns from a skill's activity list,
--- showing only activities up to `maxLevel` (nil = all) and selecting the
--- activity at `selectedIndex` and its group.
function view.setActivities(panel, activities, selectedIndex, maxLevel)
    panel.activities = activities
    panel.maxLevel = maxLevel
    panel.groups = {}
    local groupIds, entries = {}, {}
    for _, activity in ipairs(activities) do
        local group = activity.group or "All"
        if groupIds[group] == nil and available(panel, activity) then
            table.insert(panel.groups, group)
            groupIds[group] = #panel.groups
            table.insert(entries, { label = group, id = #panel.groups })
        end
    end
    local selected = activities[selectedIndex]
    local group = selected and (selected.group or "All") or panel.groups[1]
    fillEntries(panel.group, entries, groupIds[group])
    view.fillActivities(panel, group, selectedIndex)
end

--- Shows the saved from/to values (nil = blank). `toHint` is what an empty
--- "To" box means, e.g. "To: target level 70".
function view.setInputs(panel, fromLevel, toValue, toHint)
    panel.fromInput:SetText(fromLevel ~= nil and tostring(fromLevel) or "")
    panel.toInput:SetText(toValue ~= nil and tostring(toValue) or "")
    view.setToHint(panel, toHint)
end

function view.setToHint(panel, toHint)
    panel.toInput:SetPlaceholder(toHint or "To: next level")
end

--- Ticks or unticks "Hide items above my level" (without reporting it back).
function view.setHideLocked(panel, hide)
    panel.hideLocked:SetSelected("hide", hide, false)
end

--- Fills the Bonuses tab with a row per bonus. `entries` is a list of
---   { key =, name =, hint =, states = { { label =, id = }, ... }, current = id }
--- Hovering a bonus's setting shows its hint.
function view.setBonuses(panel, entries)
    if #entries == 0 then
        panel.bonusIntro.content = "No bonuses apply to this activity."
    else
        panel.bonusIntro.content = "How you'll train. Auto uses what you're wearing or standing "
            .. "near right now; pick an option to plan for something else."
    end
    for index, entry in ipairs(entries) do
        local row = panel.bonusRows[index] or addBonusRow(panel)
        row.key = entry.key
        row.name.content = entry.name
        fillEntries(row.setting, entry.states, entry.current)
        row.setting:SetTooltip(entry.hint)
    end
    -- Hide rows left over from an activity with more bonuses.
    for index, row in ipairs(panel.bonusRows) do
        local used = index <= #entries
        row.name.hidden = not used
        row.setting.root.hidden = not used
        if not used then
            row.key = nil
        end
    end
    panel.bonusPage:SetContentHeight(PAD + INTRO + GAP + #entries * (ROW + GAP) + PAD)
end

--- Shows a report from report.build(): the headline and resources on the
--- Plan tab, the bonus explanation on the Why tab. Lines are joined with <br>.
function view.showReport(panel, lines)
    local plan = { lines.headline or "" }
    for _, line in ipairs(lines.needs or {}) do
        table.insert(plan, line)
    end
    panel.planText.content = table.concat(plan, "<br>")
    panel.whyText.content = table.concat(lines.reasons or {}, "<br>")
end

function view.setOverlayButton(panel, enabled)
    panel.overlayButton:SetActive(enabled)
end

---------------------------------------------------------------------------
-- Windows
---------------------------------------------------------------------------

-- The layer plugins draw their own interfaces on.
local function pluginLayer()
    return ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)
end

--- Opens the calculator window. `options`:
---   title     shown in the title bar
---   position  { x =, y = } of its top-left corner, or nil to centre it
---   onClose(position)  when it closes (its X, or view.closeWindow), with
---             where it was, to reopen it there
--- Returns { ui = the PrettyUI window }, or nil if the plugin layer isn't
--- available.
function view.buildWindow(options)
    local parent = pluginLayer()
    if parent == nil then
        return nil
    end
    -- Centred, unless it was moved; then where it was, kept on screen.
    local x, y, xAnchor, yAnchor = -WINDOW_WIDTH / 2, -WINDOW_HEIGHT / 2, 0.5, 0.5
    local position = options.position
    if position ~= nil then
        local ok, maxX, maxY = pcall(function()
            return parent.width - WINDOW_WIDTH, parent.height - WINDOW_HEIGHT
        end)
        x, y, xAnchor, yAnchor = position.x, position.y, 0, 0
        if ok then
            x = math.max(0, math.min(maxX, x))
            y = math.max(0, math.min(maxY, y))
        end
    end

    local window = {}
    window.ui = PrettyUI.Window.new(parent, {
        title = options.title,
        x = x, y = y, xAnchor = xAnchor, yAnchor = yAnchor,
        width = WINDOW_WIDTH, height = WINDOW_HEIGHT,
        scrollable = false,
        layout = { startY = 0, padding = 0 }, -- the tabs fill the window
        destroyOnClose = true,
        onClose = function(closing)
            local ok, where = pcall(function()
                return { x = closing.root.x, y = closing.root.y }
            end)
            options.onClose(ok and where or nil)
        end,
    })
    return window
end

function view.closeWindow(window)
    window.ui:Close()
end

--- Fills the Plugins window's panel (`parent`): how to open the calculator,
--- and a button that opens it for the last skill used. `onOpen()` opens it.
function view.buildLauncher(parent, skillName, onOpen)
    PrettyUI.Text.new(parent, {
        text = "Right-click a skill in the Skills tab and choose Calculate.",
        x = 8, y = 8, width = -16, height = 60, alignVertical = ui.AlignMode.TOPLEFT, maxLines = 0,
    })
    PrettyUI.SimpleButton.new(parent, "Open " .. skillName, function()
        onOpen()
    end, { x = 8, y = 76 })
end

---------------------------------------------------------------------------
-- The on-screen line
---------------------------------------------------------------------------

--- Creates the one-line on-screen overlay (hidden until shown).
function view.buildOverlay()
    local parent = pluginLayer()
    if parent == nil then
        return nil
    end
    local overlay = {}
    overlay.root = ui.Layer.new(parent)
    overlay.root:SetPos(0, 40, 0.5, 0.0, -0.5, 0.0) -- centred near the top
    overlay.root:SetSize(460, 26)
    overlay.root.clickthrough = true

    local background = ui.Rectangle.new(overlay.root)
    background:SetSize(0, 0, 1.0, 1.0)
    background.colour = Vector4.new(0.0, 0.0, 0.0, 0.6)
    background.fill = true

    overlay.text = ui.Text.new(overlay.root)
    overlay.text:SetSize(0, 0, 1.0, 1.0)
    overlay.text.font = id.Font.MUSEO_SANS_15PT_REGULAR
    overlay.text:AlignTo(ui.AlignMode.CENTRE)
    overlay.text.isShadowed = true
    overlay.text.content = ""

    overlay.root.hidden = true
    return overlay
end

function view.setOverlay(overlay, visible, line)
    if overlay == nil then
        return
    end
    overlay.root.hidden = not visible
    overlay.text.content = line or ""
end

return view
