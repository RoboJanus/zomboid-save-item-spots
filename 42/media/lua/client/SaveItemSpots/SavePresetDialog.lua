--[[
    SavePresetDialog.lua (client)
    Custom dialog for saving a preset with name and category selection.
]]

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "ISUI/ISComboBox"

SavePresetDialog = ISPanel:derive("SavePresetDialog")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)

function SavePresetDialog:initialise()
    ISPanel.initialise(self)

    local pad = 10
    local btnHgt = math.max(25, FONT_HGT_SMALL + 6)
    local btnWid = 100
    local y = pad

    -- Title
    self.titleY = y
    y = y + FONT_HGT_MEDIUM + pad

    -- Preset name label + entry
    self.nameLabelY = y
    y = y + FONT_HGT_SMALL + 4
    self.nameEntry = ISTextEntryBox:new("", pad, y, self.width - pad * 2, FONT_HGT_SMALL + 8)
    self.nameEntry:initialise()
    self.nameEntry:instantiate()
    self.nameEntry:setMaxTextLength(32)
    self:addChild(self.nameEntry)
    y = self.nameEntry:getBottom() + pad

    -- Category label + combo box
    self.categoryLabelY = y
    y = y + FONT_HGT_SMALL + 4
    self.categoryCombo = ISComboBox:new(pad, y, self.width - pad * 2, FONT_HGT_SMALL + 8, self, SavePresetDialog.onCategorySelected)
    self.categoryCombo:initialise()
    self.categoryCombo:instantiate()
    -- Populate with existing categories
    local playerObj = getSpecificPlayer(self.playerIndex)
    local categories = SavePositionData.getCategories(playerObj)
    for _, cat in ipairs(categories) do
        self.categoryCombo:addOption(cat)
    end
    -- Add "New Category..." option at the end
    self.categoryCombo:addOption(getText("UI_SLP_CreateCategory"))
    self:addChild(self.categoryCombo)
    y = self.categoryCombo:getBottom() + pad + pad

    -- OK / Cancel buttons
    self.okBtn = ISButton:new((self.width - pad) / 2 - btnWid, y, btnWid, btnHgt, getText("UI_Ok"), self, SavePresetDialog.onClick)
    self.okBtn.internal = "OK"
    self.okBtn:initialise()
    self.okBtn:instantiate()
    self.okBtn:enableAcceptColor()
    self:addChild(self.okBtn)

    self.cancelBtn = ISButton:new((self.width + pad) / 2, y, btnWid, btnHgt, getText("UI_Cancel"), self, SavePresetDialog.onClick)
    self.cancelBtn.internal = "CANCEL"
    self.cancelBtn:initialise()
    self.cancelBtn:instantiate()
    self.cancelBtn:enableCancelColor()
    self:addChild(self.cancelBtn)
    y = y + btnHgt + pad

    self:setHeight(y)
    self.nameEntry:focus()
end

function SavePresetDialog:prerender()
    ISPanel.prerender(self)
    local pad = 10
    self:drawRect(0, 0, self.width, self.height, 0.9, 0, 0, 0)
    self:drawRectBorder(0, 0, self.width, self.height, 1, 0.4, 0.4, 0.4)
    self:drawText(getText("UI_SLP_EnterPresetName"), pad, self.titleY, 1, 1, 1, 1, UIFont.Medium)
    self:drawText(getText("UI_SLP_PresetNameLabel"), pad, self.nameLabelY, 0.8, 0.8, 0.8, 1, UIFont.Small)
    self:drawText(getText("UI_SLP_CategoryLabel"), pad, self.categoryLabelY, 0.8, 0.8, 0.8, 1, UIFont.Small)
end

function SavePresetDialog:onCategorySelected(combo)
    local selected = combo:getSelectedText()
    if selected == getText("UI_SLP_CreateCategory") then
        -- Open a text box for new category name
        local modal = ISTextBox:new(0, 0, 280, 100, getText("UI_SLP_EnterCategoryName"), "", self, SavePresetDialog.onNewCategory, self.playerIndex)
        modal:initialise()
        modal:addToUIManager()
    end
end

function SavePresetDialog:onNewCategory(button)
    if button.internal ~= "OK" then return end
    local modal = button.parent
    local catName = modal.entry:getText()
    if not catName or catName == "" then return end

    local playerObj = getSpecificPlayer(self.playerIndex)
    local success, err = SavePositionData.addCategory(playerObj, catName)
    if success then
        -- Add to combo box (before the "New Category..." option)
        local count = self.categoryCombo:getOptionCount()
        self.categoryCombo:insertOptionBefore(count, catName)
        self.categoryCombo:select(catName)
    else
        if playerObj then
            HaloTextHelper.addBadText(playerObj, err or getText("UI_SLP_Error_Generic"))
        end
    end
end

function SavePresetDialog:onClick(button)
    if button.internal == "CANCEL" then
        self:setVisible(false)
        self:removeFromUIManager()
        return
    end

    if button.internal == "OK" then
        local name = self.nameEntry:getText()
        if not name or name == "" then return end
        if string.len(name) > 32 then
            local playerObj = getSpecificPlayer(self.playerIndex)
            if playerObj then
                HaloTextHelper.addBadText(playerObj, getText("UI_SLP_Error_NameTooLong"))
            end
            return
        end

        local playerObj = getSpecificPlayer(self.playerIndex)
        if not playerObj or not self.worldItem then return end

        local xoff = self.worldItem:getOffX() or 0
        local yoff = self.worldItem:getOffY() or 0
        local zoff = self.worldItem:getOffZ() or 0
        local xRot = self.item:getWorldXRotation() or 0
        local yRot = self.item:getWorldYRotation() or 0
        local zRot = self.item:getWorldZRotation() or 0
        local username = playerObj:getUsername()

        local success, err = SavePositionData.addPreset(self.square, name, xoff, yoff, zoff, xRot, yRot, zRot, username)
        if success then
            HaloTextHelper.addText(playerObj, getText("UI_SLP_PositionSaved", name))
            -- Assign category
            local selectedCat = self.categoryCombo:getSelectedText()
            if selectedCat and selectedCat ~= getText("UI_SLP_CreateCategory") then
                SavePositionData.setPresetCategory(playerObj, self.square:getX(), self.square:getY(), self.square:getZ(), name, selectedCat)
            end
        else
            HaloTextHelper.addBadText(playerObj, err or getText("UI_SLP_Error_Generic"))
        end

        self:setVisible(false)
        self:removeFromUIManager()
    end
end

function SavePresetDialog:new(x, y, width, height, item, square, worldItem, playerIndex)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = {r = 0, g = 0, b = 0, a = 0.9}
    o.borderColor = {r = 0.4, g = 0.4, b = 0.4, a = 1}
    o.moveWithMouse = true
    o.item = item
    o.square = square
    o.worldItem = worldItem
    o.playerIndex = playerIndex
    return o
end
