--[[
    ManagePositionUI.lua (client)
    ISPanel-based UI for managing sharing of a position preset.
    - Faction sharing: checkbox to share with your faction
    - Player sharing: scrolling list of shared players with Add (from scoreboard) / Remove
]]

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "ISUI/ISTickBox"

ManagePositionUI = ISPanel:derive("ManagePositionUI")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)

function ManagePositionUI:initialise()
    ISPanel.initialise(self)

    local pad = 10
    local btnHgt = math.max(25, FONT_HGT_SMALL + 6)
    local btnWid = 80
    local y = pad

    -- Title
    self.titleLabel = y
    y = y + FONT_HGT_MEDIUM + pad

    -- Faction sharing checkbox
    self.factionCheckY = y
    local playerObj = getSpecificPlayer(self.playerIndex)
    local playerFaction = Faction.getPlayerFaction(playerObj)
    self.playerFactionName = playerFaction and playerFaction:getName() or nil

    if self.playerFactionName then
        self.factionTick = ISTickBox:new(pad, y, self.width - pad * 2, FONT_HGT_SMALL + 4, "", self, ManagePositionUI.onFactionToggle)
        self.factionTick:initialise()
        self.factionTick:instantiate()
        self.factionTick:addOption(getText("UI_SLP_ShareWithFaction", self.playerFactionName))
        -- Check if already shared with this faction
        local isShared = false
        if self.preset.factions then
            for _, f in ipairs(self.preset.factions) do
                if f == self.playerFactionName then isShared = true end
            end
        end
        self.factionTick:setSelected(1, isShared)
        self:addChild(self.factionTick)
        y = y + FONT_HGT_SMALL + 8
    else
        y = y + FONT_HGT_SMALL + 4
    end

    y = y + pad

    -- Shared Players section
    self.playersLabelY = y
    y = y + FONT_HGT_SMALL + 4

    self.playerList = ISScrollingListBox:new(pad, y, self.width - pad * 2, (FONT_HGT_SMALL + 4) * 6)
    self.playerList:initialise()
    self.playerList:instantiate()
    self.playerList.itemheight = FONT_HGT_SMALL + 4
    self.playerList.font = UIFont.NewSmall
    self.playerList.drawBorder = true
    self:addChild(self.playerList)
    y = self.playerList:getBottom() + 4

    -- Add / Remove buttons
    self.addPlayerBtn = ISButton:new(pad, y, btnWid, btnHgt, getText("UI_SLP_AddPlayer"), self, ManagePositionUI.onAddPlayer)
    self.addPlayerBtn:initialise()
    self.addPlayerBtn:instantiate()
    self.addPlayerBtn:enableAcceptColor()
    self:addChild(self.addPlayerBtn)

    self.removePlayerBtn = ISButton:new(pad + btnWid + 4, y, btnWid, btnHgt, getText("UI_SLP_RemovePlayer"), self, ManagePositionUI.onRemovePlayer)
    self.removePlayerBtn:initialise()
    self.removePlayerBtn:instantiate()
    self.removePlayerBtn:enableCancelColor()
    self:addChild(self.removePlayerBtn)
    y = y + btnHgt + pad + pad

    -- Close button
    self.closeBtn = ISButton:new(self.width - btnWid - pad, y, btnWid, btnHgt, getText("UI_Close"), self, ManagePositionUI.onClose)
    self.closeBtn:initialise()
    self.closeBtn:instantiate()
    self:addChild(self.closeBtn)
    y = y + btnHgt + pad

    self:setHeight(y)
    self:populateLists()
end

function ManagePositionUI:populateLists()
    self.playerList:clear()

    -- Re-read preset from tile (may have been updated)
    local presets = SavePositionData.getPresets(self.square)
    for _, p in ipairs(presets) do
        if p.name == self.preset.name and p.owner == self.preset.owner then
            self.preset = p
            break
        end
    end

    -- Populate shared players
    if self.preset.shared then
        for _, name in ipairs(self.preset.shared) do
            self.playerList:addItem(name, name)
        end
    end
end

function ManagePositionUI:prerender()
    ISPanel.prerender(self)
    local pad = 10
    self:drawRect(0, 0, self.width, self.height, 0.8, 0, 0, 0)
    self:drawRectBorder(0, 0, self.width, self.height, 1, 0.4, 0.4, 0.4)
    -- Title
    local title = getText("UI_SLP_ManageTitle", self.preset.name)
    self:drawText(title, pad, self.titleLabel, 1, 1, 1, 1, UIFont.Medium)
    -- Section labels
    self:drawText(getText("UI_SLP_SharedPlayers"), pad, self.playersLabelY, 0.8, 0.8, 0.8, 1, UIFont.Small)
    if not self.playerFactionName then
        self:drawText(getText("UI_SLP_NoFaction"), pad, self.factionCheckY, 0.5, 0.5, 0.5, 1, UIFont.Small)
    end
end

function ManagePositionUI:onFactionToggle(index, selected)
    local playerObj = getSpecificPlayer(self.playerIndex)
    if not playerObj then return end
    local owner = playerObj:getUsername()

    if selected then
        SavePositionData.shareWithFaction(self.square, self.preset.name, owner, self.playerFactionName)
    else
        SavePositionData.unshareFaction(self.square, self.preset.name, owner, self.playerFactionName)
    end
end

function ManagePositionUI:onAddPlayer(button)
    -- Open the player selector (scoreboard-based)
    local addUI = ManagePositionAddPlayerUI:new(self:getX() + 50, self:getY() + 50, 300, 300, self)
    addUI:initialise()
    addUI:addToUIManager()
end

function ManagePositionUI:onRemovePlayer(button)
    local selected = self.playerList.selected
    if selected < 1 then return end
    local item = self.playerList.items[selected]
    if not item then return end
    local targetName = item.item
    local playerObj = getSpecificPlayer(self.playerIndex)
    if not playerObj then return end
    local owner = playerObj:getUsername()
    SavePositionData.unsharePlayer(self.square, self.preset.name, owner, targetName)
    self:populateLists()
end

function ManagePositionUI:addSharedPlayer(username)
    local playerObj = getSpecificPlayer(self.playerIndex)
    if not playerObj then return end
    local owner = playerObj:getUsername()
    SavePositionData.shareWithPlayer(self.square, self.preset.name, owner, username)
    self:populateLists()
end

function ManagePositionUI:onClose(button)
    self:setVisible(false)
    self:removeFromUIManager()
end

function ManagePositionUI:new(x, y, width, height, square, preset, playerIndex)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = {r = 0, g = 0, b = 0, a = 0.8}
    o.borderColor = {r = 0.4, g = 0.4, b = 0.4, a = 1}
    o.moveWithMouse = true
    o.square = square
    o.preset = preset
    o.playerIndex = playerIndex
    return o
end

-- ============================================================
-- ManagePositionAddPlayerUI: scoreboard-based player selector
-- ============================================================

ManagePositionAddPlayerUI = ISPanel:derive("ManagePositionAddPlayerUI")

function ManagePositionAddPlayerUI:initialise()
    ISPanel.initialise(self)

    local pad = 10
    local btnHgt = math.max(25, FONT_HGT_SMALL + 6)
    local btnWid = 80
    local y = pad

    y = y + FONT_HGT_MEDIUM + pad

    self.playerList = ISScrollingListBox:new(pad, y, self.width - pad * 2, (FONT_HGT_SMALL + 4) * 8)
    self.playerList:initialise()
    self.playerList:instantiate()
    self.playerList.itemheight = FONT_HGT_SMALL + 4
    self.playerList.font = UIFont.NewSmall
    self.playerList.drawBorder = true
    self:addChild(self.playerList)
    y = self.playerList:getBottom() + pad

    self.addBtn = ISButton:new(pad, y, btnWid, btnHgt, getText("UI_SLP_AddPlayer"), self, ManagePositionAddPlayerUI.onAdd)
    self.addBtn:initialise()
    self.addBtn:instantiate()
    self.addBtn:enableAcceptColor()
    self:addChild(self.addBtn)

    self.cancelBtn = ISButton:new(pad + btnWid + 4, y, btnWid, btnHgt, getText("UI_Cancel"), self, ManagePositionAddPlayerUI.onCancel)
    self.cancelBtn:initialise()
    self.cancelBtn:instantiate()
    self.cancelBtn:enableCancelColor()
    self:addChild(self.cancelBtn)
    y = y + btnHgt + pad

    self:setHeight(y)

    -- Request scoreboard data
    ManagePositionAddPlayerUI.instance = self
    scoreboardUpdate()
end

function ManagePositionAddPlayerUI:prerender()
    ISPanel.prerender(self)
    local pad = 10
    self:drawRect(0, 0, self.width, self.height, 0.9, 0, 0, 0)
    self:drawRectBorder(0, 0, self.width, self.height, 1, 0.4, 0.4, 0.4)
    self:drawText(getText("UI_SLP_SelectPlayer"), pad, 10, 1, 1, 1, 1, UIFont.Medium)
end

function ManagePositionAddPlayerUI:populateList()
    self.playerList:clear()
    if not self.scoreboard then return end
    local playerObj = getSpecificPlayer(self.parentUI.playerIndex)
    local myUsername = playerObj and playerObj:getUsername() or ""
    for i = 1, self.scoreboard.usernames:size() do
        local username = self.scoreboard.usernames:get(i - 1)
        -- Don't list yourself
        if username ~= myUsername then
            local displayName = self.scoreboard.displayNames:get(i - 1)
            self.playerList:addItem(displayName .. " (" .. username .. ")", username)
        end
    end
end

function ManagePositionAddPlayerUI:onAdd(button)
    local selected = self.playerList.selected
    if selected < 1 then return end
    local item = self.playerList.items[selected]
    if not item then return end
    self.parentUI:addSharedPlayer(item.item)
    self:setVisible(false)
    self:removeFromUIManager()
    ManagePositionAddPlayerUI.instance = nil
end

function ManagePositionAddPlayerUI:onCancel(button)
    self:setVisible(false)
    self:removeFromUIManager()
    ManagePositionAddPlayerUI.instance = nil
end

function ManagePositionAddPlayerUI:new(x, y, width, height, parentUI)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = {r = 0, g = 0, b = 0, a = 0.9}
    o.borderColor = {r = 0.4, g = 0.4, b = 0.4, a = 1}
    o.moveWithMouse = true
    o.parentUI = parentUI
    o.scoreboard = nil
    return o
end

function ManagePositionAddPlayerUI.OnScoreboardUpdate(usernames, displayNames, steamIDs)
    if ManagePositionAddPlayerUI.instance then
        ManagePositionAddPlayerUI.instance.scoreboard = {}
        ManagePositionAddPlayerUI.instance.scoreboard.usernames = usernames
        ManagePositionAddPlayerUI.instance.scoreboard.displayNames = displayNames
        ManagePositionAddPlayerUI.instance.scoreboard.steamIDs = steamIDs
        ManagePositionAddPlayerUI.instance:populateList()
    end
end

Events.OnScoreboardUpdate.Add(ManagePositionAddPlayerUI.OnScoreboardUpdate)
