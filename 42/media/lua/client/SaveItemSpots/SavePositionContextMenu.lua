--[[
    SavePositionContextMenu.lua (client)
    Context menu hooks for saving and restoring item positions.

    Hooks:
    1. OnFillInventoryObjectContextMenu - for items on the ground (Save Position)
       and items in inventory (Place at Saved Position)
    2. OnFillWorldObjectContextMenu - for tiles with saved presets (Place Saved Item submenu)
]]

require "ISUI/ISTextBox"
require "ISUI/ISWorldObjectContextMenu"
require "TimedActions/ISTimedActionQueue"
require "TimedActions/WalkToTimedAction"

SavePositionContextMenu = {}

--- Hook for inventory item context menu (right-click items in inventory or on ground).
--- @param player int Player index
--- @param context ISContextMenu
--- @param items table Array of items (may be wrapped in table with .items field)
function SavePositionContextMenu.onFillInventoryMenu(player, context, items)
    -- Unwrap items: PZ passes either InventoryItem objects directly,
    -- or tables with .items field containing stacked instances.
    -- The first entry in items is a duplicate — use items[1] to get the test item.
    if #items == 0 then return end

    local testItem = items[1]
    if not instanceof(testItem, "InventoryItem") then
        if testItem.items then
            testItem = testItem.items[1]
        else
            return
        end
    end
    if not testItem then return end

    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end
    local username = playerObj:getUsername()

    -- Case 1: Item is on the ground (has a worldItem) -> offer "Save Position"
    if testItem:getWorldItem() then
        local worldItem = testItem:getWorldItem()
        local square = worldItem:getSquare()
        if square then
            local option = context:addOption(getText("UI_SLP_SavePosition"), testItem, SavePositionContextMenu.onSavePosition, player, square, worldItem)
            local tooltip = ISWorldObjectContextMenu.addToolTip()
            tooltip.description = getText("UI_SLP_SavePosition_Tooltip")
            option.toolTip = tooltip
        end
    end

    -- Case 2: Item is in player inventory -> check if any tiles in range have saved presets
    if testItem:getContainer() == playerObj:getInventory() then
        -- Find accessible presets on adjacent tiles
        local playerSquare = playerObj:getCurrentSquare()
        if not playerSquare then return end

        -- Search tiles within a reasonable range (loaded chunks around player)
        -- For performance, we limit to tiles the player has visited / nearby
        -- The "Place at Saved Position" option shows a submenu of all accessible presets
        -- across all loaded tiles. For practical purposes, we scan nearby squares.
        local presetOptions = {}
        local cell = getCell()
        local px = playerSquare:getX()
        local py = playerSquare:getY()
        local pz = playerSquare:getZ()

        -- Scan a reasonable area (50 tile radius on same floor)
        for dx = -50, 50 do
            for dy = -50, 50 do
                local sq = cell:getGridSquare(px + dx, py + dy, pz)
                if sq and sq:hasModData() then
                    local presets = SavePositionData.getAccessiblePresets(sq, username)
                    for _, preset in ipairs(presets) do
                        presetOptions[#presetOptions + 1] = {preset = preset, square = sq}
                    end
                end
            end
        end

        if #presetOptions > 0 then
            local showCoords = SandboxVars and SandboxVars.SaveItemSpots and SandboxVars.SaveItemSpots.ShowCoordinates
            local categories = SavePositionData.getCategories(playerObj)

            -- Group presets by category
            local categorized = {}
            for _, cat in ipairs(categories) do
                categorized[cat] = {}
            end
            for _, opt in ipairs(presetOptions) do
                local cat = SavePositionData.getPresetCategory(playerObj, opt.square:getX(), opt.square:getY(), opt.square:getZ(), opt.preset.name)
                if not categorized[cat] then
                    cat = "Uncategorized"
                end
                categorized[cat][#categorized[cat] + 1] = opt
            end

            -- Build submenu: Category → Presets
            local topSubmenu = context:getNew(context)
            local option = context:addOption(getText("UI_SLP_PlaceAtPosition"), nil, nil)
            context:addSubMenu(option, topSubmenu)

            for _, cat in ipairs(categories) do
                local presets = categorized[cat]
                if presets and #presets > 0 then
                    local catSubmenu = context:getNew(context)
                    local catOption = topSubmenu:addOption(cat, nil, nil)
                    topSubmenu:addSubMenu(catOption, catSubmenu)
                    for _, opt in ipairs(presets) do
                        local label = opt.preset.name
                        if showCoords then
                            label = label .. " (" .. opt.square:getX() .. "," .. opt.square:getY() .. ")"
                        end
                        catSubmenu:addOption(label, testItem, SavePositionContextMenu.onPlaceAtPosition, player, opt.square, opt.preset)
                    end
                end
            end
        end
    end
end

--- Hook for world/tile context menu (right-click on ground tiles).
--- Shows "Place Saved Item" submenu and "Manage Position" options.
--- @param player int Player index
--- @param context ISContextMenu
--- @param worldobjects table Array of world objects under cursor
--- @param test boolean
function SavePositionContextMenu.onFillWorldObjectMenu(player, context, worldobjects, test)
    if test then return end

    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end
    local username = playerObj:getUsername()

    -- Get the square from the first world object
    local square = nil
    for _, obj in ipairs(worldobjects) do
        if obj:getSquare() then
            square = obj:getSquare()
            break
        end
    end
    if not square then return end

    -- "Item Spots" option (always available on any tile)
    context:addOption(getText("UI_SLP_Presets"), nil, SavePositionContextMenu.onOpenPresetManager, player)

    local presets = SavePositionData.getAccessiblePresets(square, username)
    if #presets == 0 then return end

    -- "Place Saved Item" submenu: list presets, each with sub-submenu of matching inventory items
    local inventory = playerObj:getInventory()
    local allItems = inventory:getItems()
    if allItems:size() > 0 then
        local placeSubmenu = context:getNew(context)
        local hasAnyOption = false
        for _, preset in ipairs(presets) do
            -- For each preset, list all items in inventory that could be placed
            local itemSubmenu = context:getNew(context)
            local hasItems = false
            for i = 0, allItems:size() - 1 do
                local item = allItems:get(i)
                -- Skip containers, optionally skip equipped items
                local filterEquipped = SandboxVars and SandboxVars.SaveItemSpots and SandboxVars.SaveItemSpots.FilterEquippedItems
                if not instanceof(item, "InventoryContainer") and (not filterEquipped or not item:isEquipped()) then
                    local label = item:getDisplayName()
                    itemSubmenu:addOption(label, item, SavePositionContextMenu.onPlaceAtPosition, player, square, preset)
                    hasItems = true
                end
            end
            if hasItems then
                local presetOption = placeSubmenu:addOption(preset.name, nil, nil)
                placeSubmenu:addSubMenu(presetOption, itemSubmenu)
                hasAnyOption = true
            end
        end
        if hasAnyOption then
            local option = context:addOption(getText("UI_SLP_PlaceSavedItem"), nil, nil)
            context:addSubMenu(option, placeSubmenu)
        end
    end

    -- "Forget" option for presets shared with the player (not owned)
    local sharedPresets = {}
    for _, p in ipairs(presets) do
        if p.owner ~= username then
            sharedPresets[#sharedPresets + 1] = p
        end
    end
    if #sharedPresets > 0 then
        local forgetSubmenu = context:getNew(context)
        for _, preset in ipairs(sharedPresets) do
            forgetSubmenu:addOption(preset.name .. " (" .. preset.owner .. ")", square, SavePositionContextMenu.onForgetPreset, player, preset)
        end
        local option = context:addOption(getText("UI_SLP_ForgetPosition"), nil, nil)
        context:addSubMenu(option, forgetSubmenu)
    end
end

--- Called when "Save Position" is selected. Opens the save preset dialog.
function SavePositionContextMenu.onSavePosition(item, player, square, worldItem)
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end

    local dialog = SavePresetDialog:new(0, 0, 320, 220, item, square, worldItem, player)
    dialog:initialise()
    dialog:setX(getMouseX() - dialog.width / 2)
    dialog:setY(getMouseY() - dialog.height / 2)
    dialog:addToUIManager()
end

--- Called when "Place at Saved Position" is selected from any menu.
function SavePositionContextMenu.onPlaceAtPosition(item, player, square, preset)
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end
    if not item or not square or not preset then return end

    -- Queue walk-to, then send server command to place the item
    ISTimedActionQueue.add(ISWalkToTimedAction:new(playerObj, square))
    ISTimedActionQueue.add(PlaceAtPositionClientAction:new(playerObj, item, square, preset))
end

--- Called when "Remove Preset" is selected.
function SavePositionContextMenu.onRemovePreset(square, player, preset)
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end
    local username = playerObj:getUsername()

    local success = SavePositionData.removePreset(square, preset.name, username)
    if success then
        HaloTextHelper.addText(playerObj, getText("UI_SLP_PresetRemoved", preset.name))
    end
end

--- Called when "Forget" is selected on a shared preset.
function SavePositionContextMenu.onForgetPreset(square, player, preset)
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end
    local username = playerObj:getUsername()

    SavePositionData.forgetPreset(square, preset.name, username)
    HaloTextHelper.addText(playerObj, getText("UI_SLP_PresetForgotten", preset.name))
end

--- Called when "Share" is selected - opens the manage sharing UI.
function SavePositionContextMenu.onManageSharing(square, player, preset)
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end

    local ui = ManagePositionUI:new(200, 200, 350, 300, square, preset, player)
    ui:initialise()
    ui:addToUIManager()
end

--- Called when "Preset Manager" is selected.
function SavePositionContextMenu.onOpenPresetManager(target, player)
    local panel = PresetManagerPanel:new(200, 100, 600, 400, player)
    panel:initialise()
    panel:addToUIManager()
end

-- Register event hooks
Events.OnFillInventoryObjectContextMenu.Add(SavePositionContextMenu.onFillInventoryMenu)
Events.OnFillWorldObjectContextMenu.Add(SavePositionContextMenu.onFillWorldObjectMenu)
