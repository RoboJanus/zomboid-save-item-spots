--[[
    PlaceAtPositionAction.lua (client)
    A lightweight timed action that sends a command to the server to place an item
    at saved preset offsets and rotation. The server performs the actual placement
    to ensure proper multiplayer sync.
]]

require "TimedActions/ISBaseTimedAction"

PlaceAtPositionClientAction = ISBaseTimedAction:derive("PlaceAtPositionClientAction")

function PlaceAtPositionClientAction:isValid()
    if isClient() then
        return self.character:getInventory():containsID(self.item:getID())
    else
        return self.character:getInventory():contains(self.item)
    end
end

function PlaceAtPositionClientAction:isValidStart()
    local playerSq = self.character:getCurrentSquare()
    if not playerSq then return false end
    local square = getCell():getGridSquare(self.sqX, self.sqY, self.sqZ)
    if not square then return false end
    if not square:isAdjacentTo(playerSq) and square ~= playerSq then
        return false
    end
    return true
end

function PlaceAtPositionClientAction:update()
    self.item:setJobDelta(self:getJobDelta())
end

function PlaceAtPositionClientAction:start()
    if isClient() and self.item then
        self.item = self.character:getInventory():getItemById(self.item:getID())
    end
    if not self.item then
        self:forceStop()
        return
    end
    self.item:setJobType(getText("UI_SLP_JobType_Placing"))
    self.item:setJobDelta(0.0)
    local sound = self.item:getPlaceOneSound() or "PutItemInBag"
    if not self.character:getEmitter():isPlaying(sound) then
        self.sound = self.character:playSound(sound)
    end
end

function PlaceAtPositionClientAction:stop()
    self.item:setJobDelta(0.0)
    if self.sound then
        self.character:stopOrTriggerSound(self.sound)
    end
    ISBaseTimedAction.stop(self)
end

function PlaceAtPositionClientAction:perform()
    if self.sound then
        self.character:stopOrTriggerSound(self.sound)
    end
    self.item:setJobDelta(0.0)

    -- Send command to server to perform the actual placement
    sendClientCommand(self.character, "SaveLastPosition", "placeItem", {
        itemId = self.item:getID(),
        sqX = self.sqX,
        sqY = self.sqY,
        sqZ = self.sqZ,
        xoff = self.preset.xoff,
        yoff = self.preset.yoff,
        zoff = self.preset.zoff,
        xRot = self.preset.xRot,
        yRot = self.preset.yRot,
        zRot = self.preset.zRot,
    })

    if self.item:getContainer() then self.item:getContainer():setDrawDirty(true) end
    ISInventoryPage.renderDirty = true
    ISBaseTimedAction.perform(self)
end

function PlaceAtPositionClientAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    local maxTime = 50
    local w = self.item:getActualWeight()
    if w > 3 then w = 3 end
    maxTime = maxTime * w * 0.1
    if self.character:hasTrait(CharacterTrait.DEXTROUS) then
        maxTime = maxTime * 0.5
    end
    if self.character:hasTrait(CharacterTrait.ALL_THUMBS) or self.character:isWearingAwkwardGloves() then
        maxTime = maxTime * 2.0
    end
    return math.max(maxTime, 20)
end

function PlaceAtPositionClientAction:new(character, item, square, preset)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.item = item
    o.sqX = square:getX()
    o.sqY = square:getY()
    o.sqZ = square:getZ()
    o.preset = preset
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    return o
end
