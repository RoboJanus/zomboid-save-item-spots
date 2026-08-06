--[[
    PlaceItemServer.lua (server)
    Handles the "placeItem" client command to place an item at saved offsets/rotation.
    The server performs the actual AddWorldInventoryItem to ensure proper MP sync.
]]

if isClient() then return end

local MODULE_NAME = "SaveLastPosition"

local function onClientCommand(module, command, player, args)
    if module ~= MODULE_NAME then return end

    if command == "placeItem" then
        if not args then return end
        local itemId = args.itemId
        local sqX = args.sqX
        local sqY = args.sqY
        local sqZ = args.sqZ
        local xoff = args.xoff or 0
        local yoff = args.yoff or 0
        local zoff = args.zoff or 0

        -- PZ may treat (0,0) as "use default placement" rather than tile origin.
        -- Use a tiny epsilon to force explicit positioning when offset is zero.
        if xoff == 0 then xoff = 0.0001 end
        if yoff == 0 then yoff = 0.0001 end
        local xRot = args.xRot or 0
        local yRot = args.yRot or 0
        local zRot = args.zRot or 0

        if not itemId or not sqX or not sqY or not sqZ then return end

        -- Find the item in the player's inventory
        local inventory = player:getInventory()
        local item = inventory:getItemById(itemId)
        if not item then
            print("[SaveLastPosition] Server: item not found in player inventory, id=" .. tostring(itemId))
            return
        end

        -- Get the target square
        local square = getCell():getGridSquare(sqX, sqY, sqZ)
        if not square then
            print("[SaveLastPosition] Server: square not found at " .. sqX .. "," .. sqY .. "," .. sqZ)
            return
        end

        -- Place the item on the tile
        local worldItem = square:AddWorldInventoryItem(item, xoff, yoff, zoff, false)
        if worldItem then
            worldItem:setWorldZRotation(zRot)
            worldItem:setWorldXRotation(xRot)
            worldItem:setWorldYRotation(yRot)
            if worldItem:getWorldItem() then
                worldItem:getWorldItem():setIgnoreRemoveSandbox(true)
                worldItem:getWorldItem():setExtendedPlacement(false)
                worldItem:getWorldItem():transmitCompleteItemToClients()
            end
        end

        -- Remove from player inventory
        inventory:Remove(item)
        sendRemoveItemFromContainer(inventory, item)

        print("[SaveLastPosition] Server: placed item " .. item:getDisplayName() .. " at " .. sqX .. "," .. sqY .. "," .. sqZ)
    end
end

Events.OnClientCommand.Add(onClientCommand)
