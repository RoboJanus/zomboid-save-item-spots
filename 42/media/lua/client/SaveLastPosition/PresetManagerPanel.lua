--[[
    PresetManagerPanel.lua (client)
    Full management panel for viewing, organizing, and deleting presets and categories.
    Opened from the "Manage Positions" context menu or a future circle menu button.
]]

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "ISUI/ISModalDialog"
require "ISUI/ISTextBox"

PresetManagerPanel = ISPanel:derive("PresetManagerPanel")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)

function PresetManagerPanel:initialise()
    ISPanel.initialise(self)

    local pad = 10
    local btnHgt = math.max(25, FONT_HGT_SMALL + 6)
    local btnWid = 120
    local halfW = (self.width - pad * 3) / 2
    local y = pad

    -- Title
    self.titleY = y
    y = y + FONT_HGT_MEDIUM + pad

    -- Left side: Categories list
    self.catLabelY = y
    y = y + FONT_HGT_SMALL + 4

    self.categoryList = ISScrollingListBox:new(pad, y, halfW, (FONT_HGT_SMALL + 4) * 10)
    self.categoryList:initialise()
    self.categoryList:instantiate()
    self.categoryList.itemheight = FONT_HGT_SMALL + 4
    self.categoryList.font = UIFont.NewSmall
    self.categoryList.drawBorder = true
    self.categoryList.doDrawItem = PresetManagerPanel.drawListItem
    self.categoryList:setOnMouseDownFunction(self, PresetManagerPanel.onSelectCategory)
    self:addChild(self.categoryList)

    -- Right side: Presets in selected category
    self.presetLabelY = self.catLabelY
    self.presetList = ISScrollingListBox:new(pad * 2 + halfW, y, halfW, (FONT_HGT_SMALL + 4) * 10)
    self.presetList:initialise()
    self.presetList:instantiate()
    self.presetList.itemheight = FONT_HGT_SMALL + 4
    self.presetList.font = UIFont.NewSmall
    self.presetList.drawBorder = true
    self.presetList.doDrawItem = PresetManagerPanel.drawListItem
    self:addChild(self.presetList)

    y = self.categoryList:getBottom() + pad

    -- Category buttons
    self.newCatBtn = ISButton:new(pad, y, btnWid, btnHgt, getText("UI_SLP_CreateCategory"), self, PresetManagerPanel.onNewCategory)
    self.newCatBtn:initialise()
    self.newCatBtn:instantiate()
    self.newCatBtn:enableAcceptColor()
    self:addChild(self.newCatBtn)

    self.delCatBtn = ISButton:new(pad + btnWid + 4, y, btnWid, btnHgt, getText("UI_SLP_DeleteCategory"), self, PresetManagerPanel.onDeleteCategory)
    self.delCatBtn:initialise()
    self.delCatBtn:instantiate()
    self.delCatBtn:enableCancelColor()
    self:addChild(self.delCatBtn)

    -- Preset buttons (right side)
    self.delPresetBtn = ISButton:new(pad * 2 + halfW, y, btnWid, btnHgt, getText("UI_SLP_RemovePreset"), self, PresetManagerPanel.onDeletePreset)
    self.delPresetBtn:initialise()
    self.delPresetBtn:instantiate()
    self.delPresetBtn:enableCancelColor()
    self:addChild(self.delPresetBtn)

    self.moveCatBtn = ISButton:new(pad * 2 + halfW + btnWid + 4, y, btnWid, btnHgt, getText("UI_SLP_MoveToCategory"), self, PresetManagerPanel.onMovePreset)
    self.moveCatBtn:initialise()
    self.moveCatBtn:instantiate()
    self:addChild(self.moveCatBtn)

    y = y + btnHgt + pad + pad

    -- Close button
    self.closeBtn = ISButton:new(self.width - 80 - pad, y, 80, btnHgt, getText("UI_Close"), self, PresetManagerPanel.onClose)
    self.closeBtn:initialise()
    self.closeBtn:instantiate()
    self:addChild(self.closeBtn)

    y = y + btnHgt + pad
    self:setHeight(y)

    self.selectedCategory = "Uncategorized"
    self:populateCategories()
end

function PresetManagerPanel:prerender()
    ISPanel.prerender(self)
    local pad = 10
    self:drawRect(0, 0, self.width, self.height, 0.9, 0, 0, 0)
    self:drawRectBorder(0, 0, self.width, self.height, 1, 0.4, 0.4, 0.4)
    self:drawText(getText("UI_SLP_Presets"), pad, self.titleY, 1, 1, 1, 1, UIFont.Medium)
    self:drawText(getText("UI_SLP_CategoriesLabel"), pad, self.catLabelY, 0.8, 0.8, 0.8, 1, UIFont.Small)
    local halfW = (self.width - pad * 3) / 2
    self:drawText(getText("UI_SLP_PresetsInCategory"), pad * 2 + halfW, self.presetLabelY, 0.8, 0.8, 0.8, 1, UIFont.Small)
end

function PresetManagerPanel.drawListItem(self, y, item, alt)
    local a = 0.9
    local midY = y + (self.itemheight - FONT_HGT_SMALL) / 2
    self:drawRectBorder(0, y, self:getWidth(), self.itemheight - 1, a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    if self.selected == item.index then
        self:drawRect(0, y, self:getWidth(), self.itemheight - 1, 0.3, 0.7, 0.35, 0.15)
    end
    self:drawText(item.text, 10, midY, 1, 1, 1, a, self.font)
    return y + self.itemheight
end

function PresetManagerPanel:populateCategories()
    self.categoryList:clear()
    local playerObj = getSpecificPlayer(self.playerIndex)
    local categories = SavePositionData.getCategories(playerObj)
    for _, cat in ipairs(categories) do
        self.categoryList:addItem(cat, cat)
    end
    -- Select current
    for i, item in ipairs(self.categoryList.items) do
        if item.item == self.selectedCategory then
            self.categoryList.selected = i
            break
        end
    end
    self:populatePresets()
end

function PresetManagerPanel:populatePresets()
    self.presetList:clear()
    local playerObj = getSpecificPlayer(self.playerIndex)
    if not playerObj then return end
    local username = playerObj:getUsername()

    -- Collect all accessible presets across loaded tiles and filter by category
    local cell = getCell()
    local playerSquare = playerObj:getCurrentSquare()
    if not playerSquare then return end
    local px = playerSquare:getX()
    local py = playerSquare:getY()
    local pz = playerSquare:getZ()

    for dx = -50, 50 do
        for dy = -50, 50 do
            local sq = cell:getGridSquare(px + dx, py + dy, pz)
            if sq and sq:hasModData() then
                local presets = SavePositionData.getAccessiblePresets(sq, username)
                for _, preset in ipairs(presets) do
                    local cat = SavePositionData.getPresetCategory(playerObj, sq:getX(), sq:getY(), sq:getZ(), preset.name)
                    if cat == self.selectedCategory then
                        local label = preset.name .. " (" .. sq:getX() .. "," .. sq:getY() .. ")"
                        self.presetList:addItem(label, {preset = preset, square = sq})
                    end
                end
            end
        end
    end
end

function PresetManagerPanel:onSelectCategory(item)
    if self.categoryList.selected > 0 and self.categoryList.items[self.categoryList.selected] then
        self.selectedCategory = self.categoryList.items[self.categoryList.selected].item
        self:populatePresets()
    end
end

function PresetManagerPanel:onNewCategory(button)
    local modal = ISTextBox:new(0, 0, 280, 100, getText("UI_SLP_EnterCategoryName"), "", self, PresetManagerPanel.onNewCategoryConfirm, self.playerIndex)
    modal:initialise()
    modal:addToUIManager()
end

function PresetManagerPanel:onNewCategoryConfirm(button)
    if button.internal ~= "OK" then return end
    local modal = button.parent
    local catName = modal.entry:getText()
    if not catName or catName == "" then return end

    local playerObj = getSpecificPlayer(self.playerIndex)
    local success, err = SavePositionData.addCategory(playerObj, catName)
    if success then
        self.selectedCategory = catName
        self:populateCategories()
    else
        if playerObj then
            HaloTextHelper.addBadText(playerObj, err or getText("UI_SLP_Error_Generic"))
        end
    end
end

function PresetManagerPanel:onDeleteCategory(button)
    if self.selectedCategory == "Uncategorized" then
        local playerObj = getSpecificPlayer(self.playerIndex)
        if playerObj then
            HaloTextHelper.addBadText(playerObj, getText("UI_SLP_Error_CantDeleteUncategorized"))
        end
        return
    end

    -- Show confirmation dialog
    local msg = getText("UI_SLP_DeleteCategoryWarning", self.selectedCategory)
    local modal = ISModalDialog:new(0, 0, 350, 150, msg, true, self, PresetManagerPanel.onDeleteCategoryConfirm)
    modal:initialise()
    modal:addToUIManager()
end

function PresetManagerPanel:onDeleteCategoryConfirm(button)
    if button.internal ~= "YES" then return end
    local playerObj = getSpecificPlayer(self.playerIndex)
    if not playerObj then return end

    -- Delete all presets in this category from their tiles
    local deletedCategory = self.selectedCategory
    local username = playerObj:getUsername()
    local cell = getCell()
    local playerSquare = playerObj:getCurrentSquare()
    if playerSquare then
        local px = playerSquare:getX()
        local py = playerSquare:getY()
        local pz = playerSquare:getZ()
        for dx = -50, 50 do
            for dy = -50, 50 do
                local sq = cell:getGridSquare(px + dx, py + dy, pz)
                if sq and sq:hasModData() then
                    local presets = SavePositionData.getPresets(sq)
                    for _, preset in ipairs(presets) do
                        if preset.owner == username then
                            local cat = SavePositionData.getPresetCategory(playerObj, sq:getX(), sq:getY(), sq:getZ(), preset.name)
                            if cat == self.selectedCategory then
                                SavePositionData.removePreset(sq, preset.name, username)
                            end
                        end
                    end
                end
            end
        end
    end

    SavePositionData.removeCategory(playerObj, self.selectedCategory)
    self.selectedCategory = "Uncategorized"
    HaloTextHelper.addText(playerObj, getText("UI_SLP_CategoryDeleted", deletedCategory))
    self:populateCategories()
end

function PresetManagerPanel:onDeletePreset(button)
    local selected = self.presetList.selected
    if selected < 1 then return end
    local item = self.presetList.items[selected]
    if not item then return end

    local playerObj = getSpecificPlayer(self.playerIndex)
    if not playerObj then return end
    local username = playerObj:getUsername()
    local data = item.item
    SavePositionData.removePreset(data.square, data.preset.name, username)
    HaloTextHelper.addText(playerObj, getText("UI_SLP_PresetRemoved", data.preset.name))
    self:populatePresets()
end

function PresetManagerPanel:onMovePreset(button)
    local selected = self.presetList.selected
    if selected < 1 then return end

    -- Open a category selector
    local moveUI = PresetManagerMoveUI:new(self:getX() + 50, self:getY() + 50, 250, 250, self)
    moveUI:initialise()
    moveUI:addToUIManager()
end

function PresetManagerPanel:movePresetToCategory(categoryName)
    local selected = self.presetList.selected
    if selected < 1 then return end
    local item = self.presetList.items[selected]
    if not item then return end

    local playerObj = getSpecificPlayer(self.playerIndex)
    if not playerObj then return end
    local data = item.item
    SavePositionData.setPresetCategory(playerObj, data.square:getX(), data.square:getY(), data.square:getZ(), data.preset.name, categoryName)
    self:populatePresets()
end

function PresetManagerPanel:onClose(button)
    self:setVisible(false)
    self:removeFromUIManager()
end

function PresetManagerPanel:new(x, y, width, height, playerIndex)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = {r = 0, g = 0, b = 0, a = 0.9}
    o.borderColor = {r = 0.4, g = 0.4, b = 0.4, a = 1}
    o.moveWithMouse = true
    o.playerIndex = playerIndex
    o.selectedCategory = "Uncategorized"
    return o
end

-- ============================================================
-- PresetManagerMoveUI: category selector for moving a preset
-- ============================================================

PresetManagerMoveUI = ISPanel:derive("PresetManagerMoveUI")

function PresetManagerMoveUI:initialise()
    ISPanel.initialise(self)

    local pad = 10
    local btnHgt = math.max(25, FONT_HGT_SMALL + 6)
    local btnWid = 80
    local y = pad

    y = y + FONT_HGT_MEDIUM + pad

    self.categoryList = ISScrollingListBox:new(pad, y, self.width - pad * 2, (FONT_HGT_SMALL + 4) * 6)
    self.categoryList:initialise()
    self.categoryList:instantiate()
    self.categoryList.itemheight = FONT_HGT_SMALL + 4
    self.categoryList.font = UIFont.NewSmall
    self.categoryList.drawBorder = true
    self.categoryList.doDrawItem = PresetManagerPanel.drawListItem
    self:addChild(self.categoryList)
    y = self.categoryList:getBottom() + pad

    self.moveBtn = ISButton:new(pad, y, 130, btnHgt, getText("UI_SLP_MoveToCategory"), self, PresetManagerMoveUI.onMove)
    self.moveBtn:initialise()
    self.moveBtn:instantiate()
    self.moveBtn:enableAcceptColor()
    self:addChild(self.moveBtn)

    self.cancelBtn = ISButton:new(pad + 130 + 8, y, btnWid, btnHgt, getText("UI_Cancel"), self, PresetManagerMoveUI.onCancel)
    self.cancelBtn:initialise()
    self.cancelBtn:instantiate()
    self.cancelBtn:enableCancelColor()
    self:addChild(self.cancelBtn)
    y = y + btnHgt + pad

    self:setHeight(y)

    -- Populate categories
    local playerObj = getSpecificPlayer(self.parentPanel.playerIndex)
    local categories = SavePositionData.getCategories(playerObj)
    for _, cat in ipairs(categories) do
        self.categoryList:addItem(cat, cat)
    end
end

function PresetManagerMoveUI:prerender()
    ISPanel.prerender(self)
    local pad = 10
    self:drawRect(0, 0, self.width, self.height, 0.9, 0, 0, 0)
    self:drawRectBorder(0, 0, self.width, self.height, 1, 0.4, 0.4, 0.4)
    self:drawText(getText("UI_SLP_MoveToCategory"), pad, 10, 1, 1, 1, 1, UIFont.Medium)
end

function PresetManagerMoveUI:onMove(button)
    local selected = self.categoryList.selected
    if selected < 1 then return end
    local item = self.categoryList.items[selected]
    if not item then return end
    self.parentPanel:movePresetToCategory(item.item)
    self:setVisible(false)
    self:removeFromUIManager()
end

function PresetManagerMoveUI:onCancel(button)
    self:setVisible(false)
    self:removeFromUIManager()
end

function PresetManagerMoveUI:new(x, y, width, height, parentPanel)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = {r = 0, g = 0, b = 0, a = 0.9}
    o.borderColor = {r = 0.4, g = 0.4, b = 0.4, a = 1}
    o.moveWithMouse = true
    o.parentPanel = parentPanel
    return o
end
