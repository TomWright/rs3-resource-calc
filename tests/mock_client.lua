-- mock_client.lua
-- A minimal fake of the RuneScape client API, just enough to load main.lua
-- outside the game and fire events at it. Only used by tests/smoke_test.lua.
-- It checks the plugin's wiring (no typos, no nil errors); it does not prove
-- the real client behaves the same way.

local mock = {}

-- Generic stand-in object: any field you read is another stub, calling it
-- returns a stub, and fields you set are remembered.
local function stub(name)
    local object = { __name = name }
    return setmetatable(object, {
        __index = function(self, key)
            local child = stub(name .. "." .. tostring(key))
            rawset(self, key, child)
            return child
        end,
        __call = function()
            return stub(name .. "()")
        end,
    })
end
mock.stub = stub

-- Every UI component created, so tests can inspect what was displayed.
mock.components = {}
-- Hook callbacks subscribed on components: { component, hook, fn }
mock.hooks = {}

local function newComponent(kind)
    return function(parent)
        local component = stub(kind)
        component.kind = kind
        component.parent = parent
        component.entries = {}
        function component.Subscribe(self, hook, idOrFn, fn)
            table.insert(mock.hooks, { component = self, hook = hook, fn = fn or idOrFn })
        end
        function component.Add(self, label, entryId) table.insert(self.entries, { text = label, id = entryId }) return true end
        function component.Clear(self) self.entries = {} self.selectedEntries = {} end
        function component.HasEntry(self, entryId)
            for _, e in ipairs(self.entries) do if e.id == entryId then return true end end
            return false
        end
        -- Lists remember their selection, like the real ones.
        component.selectedEntries = {}
        -- Like the real client in testing: selects by 0-based position,
        -- not by ID.
        function component.SetEntrySelected(self, position, selected)
            local entry = self.entries[position + 1]
            self.selectedEntries = (selected and entry) and { { id = entry.id, text = entry.text } } or {}
            return entry ~= nil
        end
        component.destroyed = false
        function component.Destroy(self) self.destroyed = true end
        table.insert(mock.components, component)
        return component
    end
end

---------------------------------------------------------------------------
-- Fake PrettyUI: the parts of the library plugin src/view.lua uses, with
-- the same function names and callback arguments. Components are recorded
-- in mock.components like the client's own.
---------------------------------------------------------------------------

local function record(kind, parent, fields)
    local component = fields or {}
    component.kind = kind
    component.parent = parent
    component.destroyed = false
    table.insert(mock.components, component)
    return component
end

-- Dropdown (PrettyUI.ComboBox with ordered entries): entries are shown in
-- `order`, and it keeps track of the selection itself.
local function newCombo(parent, options)
    local combo = record("List", parent, { entries = {}, onChange = options.onChange })
    combo.root = { hidden = false, SetSize = function() end }
    function combo.SetEntries(self, entries, selectedId)
        local sorted = {}
        for _, entry in ipairs(entries) do table.insert(sorted, entry) end
        table.sort(sorted, function(a, b) return (a.order or 0) < (b.order or 0) end)
        self.entries = {}
        for _, entry in ipairs(sorted) do table.insert(self.entries, { text = entry.label, id = entry.id }) end
        self.selected = selectedId or (self.entries[1] and self.entries[1].id)
    end
    function combo.GetSelectedID(self) return self.selected end
    function combo.SetTooltip(self, value) self.tooltip = value end
    combo:SetEntries(options.entries or {})
    return combo
end

local function newTextField(parent, options)
    local field = record("InputField", parent, { emptyText = options.placeholder, onChange = options.onChange })
    field.root = {}
    function field.SetText(self, value) self.content = value end
    function field.SetPlaceholder(self, value) self.emptyText = value end
    return field
end

local function newText(parent, options)
    return record("Text", parent, { content = options.text })
end

local function newButton(parent, label, action, options)
    local button = record("Button", parent, { label = label, action = action,
        toggleable = options.toggleable == true, active = options.active == true })
    function button.SetActive(self, active) self.active = active end
    return button
end

-- Tick box (PrettyUI.CheckboxButton) with one choice.
local function newCheckbox(parent, choices, options)
    local box = record("Checkbox", parent, { label = choices[1].text, value = choices[1].value,
        selected = choices[1].selected == true, onChange = options.onChange })
    function box.SetSelected(self, _, selected) self.selected = selected end
    return box
end

-- A tab page or window: anything with the Add... methods.
local function newHost(kind, parent)
    local host = record(kind, parent)
    function host.AddComboBox(self, options) return newCombo(self, options) end
    function host.AddTextField(self, options) return newTextField(self, options) end
    function host.AddText(self, options) return newText(self, options) end
    function host.AddSimpleButton(self, label, action, options) return newButton(self, label, action, options) end
    function host.SetContentHeight(self, height) self.contentHeight = height end
    function host.AddCheckboxButton(self, choices, options) return newCheckbox(self, choices, options) end
    function host.AddTabs(self, values)
        local tabs = record("Tabs", self, { pages = {} })
        for index in ipairs(values) do tabs.pages[index] = newHost("TabPage", tabs) end
        function tabs.GetPage(_, index) return tabs.pages[index] end
        return tabs
    end
    return host
end

local fakePrettyUI = {
    Window = {
        new = function(parent, options)
            local window = newHost("Window", parent)
            window.title = options.title
            window.options = options
            window.root = { x = options.x, y = options.y }
            function window.Close(self)
                options.onClose(self)
                self.destroyed = true
            end
            return window
        end,
    },
    Text = { new = newText },
    SimpleButton = { new = newButton },
}

--- Simulates the user picking an entry in a dropdown.
function mock.select(list, entryId)
    list.selected = entryId
    local label = nil
    for _, entry in ipairs(list.entries) do
        if entry.id == entryId then label = entry.text end
    end
    list.onChange(list, entryId, label, ui.SelectionChangeEvent.SELECTED)
end

--- The text of a dropdown's selected entry.
function mock.shown(list)
    for _, entry in ipairs(list.entries) do
        if entry.id == list.selected then return entry.text end
    end
    return nil
end

--- Simulates the user typing a number into a text field.
function mock.type(input, quantity)
    input.root.contentQuantity = quantity
    input.onChange(input, 0, tostring(quantity))
end

--- Simulates the user ticking or unticking a tick box.
function mock.tick(box, selected)
    box.selected = selected
    box.onChange(box, selected and { box.value } or {}, box.value, selected)
end

--- Simulates the user clicking a button.
function mock.press(button)
    if button.toggleable then button.active = not button.active end
    button.action(button, button.active)
end

--- Builds a fake right-click menu from { verb, subject, type, subjectHash }
--- entries and fires MiniMenuReady on it. Returns the menu (entries the
--- plugin added are in menu.added, as { label, fn, args }).
function mock.rightClick(entries)
    local menu = { entries = {}, added = {} }
    for _, e in ipairs(entries) do
        table.insert(menu.entries, {
            verbText = e[1], subjectText = e[2], actionEntryType = e[3], subjectHash = e[4] or -1,
            fullText = e[1] .. " " .. e[2],
        })
    end
    menu.entryCount = #menu.entries
    -- Like the real client: added entries go to the bottom of the menu.
    function menu.Add(self, label, fn, ...)
        table.insert(self.added, { label = label, fn = fn, args = { ... } })
        table.insert(self.entries, 1, { verbText = label, subjectText = "", actionEntryType = 10, fullText = label })
        self.entryCount = #self.entries
    end
    function menu.Swap(self, a, b) self.entries[a], self.entries[b] = self.entries[b], self.entries[a] end
    mock.fire("MiniMenuReady", { miniMenu = menu })
    return menu
end

--- True if neither the component nor anything it's inside was destroyed.
function mock.isLive(component)
    while component ~= nil do
        if rawget(component, "destroyed") == true then return false end
        component = rawget(component, "parent")
    end
    return true
end

--- Finds the dropdown list that has an entry with this text.
function mock.findList(text)
    for _, component in ipairs(mock.components) do
        if component.kind == "List" and mock.isLive(component) then
            for _, entry in ipairs(component.entries) do
                if entry.text == text then return component end
            end
        end
    end
    return nil
end

--- The id of the entry with this text in a list (nil if it isn't listed).
function mock.entryId(list, text)
    for _, entry in ipairs(list.entries) do
        if entry.text == text then return entry.id end
    end
    return nil
end

function mock.install()
    -- Console output.
    mock.logs = {}
    _G.log = function(...)
        local parts = {}
        for _, v in ipairs({ ... }) do table.insert(parts, tostring(v)) end
        table.insert(mock.logs, table.concat(parts, " "))
    end

    -- Skills.
    _G.SkillType = { SMITHING = 13, MINING = 14, PRAYER = 5, CRAFTING = 12, INVENTION = 26 }
    function SkillType.FromID(skillId)
        for key, value in pairs(SkillType) do
            if value == skillId then return key end
        end
        return nil
    end

    -- Player.
    mock.xp = { [13] = 2000000, [5] = 500000 }
    mock.coord = { x = 3200, z = 3200, level = 0 }
    _G.Player = {
        IsAvailable = function() return true end,
        GetXPUncapped = function(skill) return mock.xp[skill] or 0 end,
        GetLevelUncapped = function() return 1 end,
        GetEntity = function() return { isValid = true, coordGrid = mock.coord } end,
    }

    -- Inventories: mock.inventories[configName] = { ["Item"] = count }
    mock.inventories = { INV = {}, WORN = {} }
    _G.config = { Inv = {} }
    for _, name in ipairs({ "INV", "BANK", "WORN" }) do
        config.Inv[name] = { id = name, configName = name }
    end
    _G.Inventory = {
        Find = function(invConfig)
            local contents = mock.inventories[invConfig.configName]
            if contents == nil then return nil end
            local slots = {}
            for item, count in pairs(contents) do
                table.insert(slots, { obj = { name = item }, count = count })
            end
            return {
                isValid = true,
                slotCount = #slots + 2, -- plus some empty slots
                GetSlot = function(_, index) return slots[index] end,
            }
        end,
    }

    -- Nearby scenery: mock.scenery = { ["Name"] = { x =, z =, level = } }
    mock.scenery = {}
    _G.LocList = {
        ByName = function(name)
            local coord = mock.scenery[name]
            if coord == nil then return {} end
            return { { isValid = true, coordGrid = coord } }
        end,
    }

    -- VarPlayers: mock.varps[name] = value. Unknown names raise an error,
    -- which the plugin must cope with.
    mock.varps = {}
    _G.var = {
        VarPlayer = setmetatable({}, {
            __index = function(_, name)
                if mock.varps[name] == nil then error("unknown VarPlayer " .. name) end
                return { value = mock.varps[name] }
            end,
        }),
    }

    -- Persistent storage.
    mock.db = {}
    _G.PersistentDB = {
        GetStructuredData = function(_, key) return mock.db[key] end,
        SetStructuredData = function(_, key, value) mock.db[key] = value return true end,
    }

    -- Events: mock.events.ServerLogic = { handlers }
    mock.events = {}
    _G.Event = setmetatable({}, {
        __index = function(_, eventName)
            mock.events[eventName] = mock.events[eventName] or {}
            return {
                Subscribe = function(refName, fn) mock.events[eventName][refName] = fn end,
                Unsubscribe = function(refName) mock.events[eventName][refName] = nil end,
            }
        end,
    })

    -- Right-click menus.
    _G.MiniMenuEntryType = { NONE = 0, INTERFACE = 1, OBJ = 2, LOC = 3, NPC = 4, PLUGIN = 10 }

    -- UI.
    _G.ui = stub("ui")
    for _, kind in ipairs({ "Text", "List", "ComboField", "InputField", "Check", "Button", "Layer", "Rectangle", "GroupBox", "Panel" }) do
        ui[kind] = { new = newComponent(kind) }
    end
    ui.Hook = {
        ONBUTTONPRESSED = "ONBUTTONPRESSED", ONSELECTIONCHANGED = "ONSELECTIONCHANGED",
        ONCONTENTCHANGED = "ONCONTENTCHANGED", ONDRAG = "ONDRAG", ONDRAGCOMPLETE = "ONDRAGCOMPLETE",
    }
    ui.SelectionChangeEvent = { SELECTED = 1, DESELECTED = 0 }
    ui.Interfaces = { GetComponent = function() return stub("pluginLayer") end }
    _G.id = stub("id")
    ui.AlignMode = { TOPLEFT = 0, CENTRE = 1 }
    ui.InputFieldFilterMode = { NUMERIC = 1, QUANTITY = 2 }
    _G.PrettyUI = fakePrettyUI
    _G.Vector4 = { new = function(...) return { ... } end }
end

--- Calls every handler subscribed to a client event.
function mock.fire(eventName, payload)
    for _, fn in pairs(mock.events[eventName] or {}) do
        fn(payload)
    end
end

--- Simulates the user acting on a component (e.g. picking a list entry).
function mock.trigger(component, hook, ...)
    for _, entry in ipairs(mock.hooks) do
        if entry.component == component and entry.hook == hook then
            entry.fn(component, ...)
        end
    end
end

--- Finds created components of a kind, in creation order.
function mock.find(kind)
    local found = {}
    for _, component in ipairs(mock.components) do
        if component.kind == kind then table.insert(found, component) end
    end
    return found
end

return mock
