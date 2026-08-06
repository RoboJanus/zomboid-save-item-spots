--[[
    SavePositionData.lua (shared)
    Data model and helpers for tile-based position presets.
    Presets are stored in IsoGridSquare modData as a serialized table.
]]

SavePositionData = {}

local PREFIX = "SLP_"
local PRESETS_KEY = PREFIX .. "presets"

--- Get the max presets per tile from sandbox options.
function SavePositionData.getMaxPresets()
    if SandboxVars and SandboxVars.SaveLastPosition and SandboxVars.SaveLastPosition.MaxPresetsPerTile then
        return SandboxVars.SaveLastPosition.MaxPresetsPerTile
    end
    return 5
end

--- Get all presets stored on a tile's modData.
--- @param square IsoGridSquare
--- @return table Array of preset tables
function SavePositionData.getPresets(square)
    if not square then return {} end
    local modData = square:getModData()
    local raw = modData[PRESETS_KEY]
    if not raw then return {} end
    -- Deserialize from stored format
    local presets = SavePositionData._deserialize(raw)
    return presets or {}
end

--- Save presets array to a tile's modData.
--- @param square IsoGridSquare
--- @param presets table Array of preset tables
--- @param transmit boolean Whether to sync to other clients (default true)
function SavePositionData.savePresets(square, presets, transmit)
    if not square then return end
    if transmit == nil then transmit = true end
    local modData = square:getModData()
    modData[PRESETS_KEY] = SavePositionData._serialize(presets)
    if transmit then
        square:transmitModdata()
    end
end

--- Add a new preset to a tile.
--- @param square IsoGridSquare
--- @param name string Preset name chosen by player
--- @param xoff number X offset
--- @param yoff number Y offset
--- @param zoff number Z offset
--- @param xRot number X rotation
--- @param yRot number Y rotation
--- @param zRot number Z rotation
--- @param owner string Username of the player creating the preset
--- @return boolean, string Success flag and error message if failed
function SavePositionData.addPreset(square, name, xoff, yoff, zoff, xRot, yRot, zRot, owner)
    local presets = SavePositionData.getPresets(square)
    local max = SavePositionData.getMaxPresets()
    if #presets >= max then
        return false, getText("UI_SLP_Error_MaxPresets")
    end
    -- Check for duplicate name on this tile
    for _, p in ipairs(presets) do
        if p.name == name then
            return false, getText("UI_SLP_Error_DuplicateName")
        end
    end
    local preset = {
        name = name,
        xoff = xoff,
        yoff = yoff,
        zoff = zoff,
        xRot = xRot,
        yRot = yRot,
        zRot = zRot,
        owner = owner,
        shared = {},
        factions = {},
    }
    presets[#presets + 1] = preset
    SavePositionData.savePresets(square, presets, true)
    return true, nil
end

--- Remove a preset from a tile by name. Only the owner can remove.
--- @param square IsoGridSquare
--- @param name string Preset name
--- @param username string Player requesting removal
--- @return boolean Success
function SavePositionData.removePreset(square, name, username)
    local presets = SavePositionData.getPresets(square)
    for i, p in ipairs(presets) do
        if p.name == name and p.owner == username then
            table.remove(presets, i)
            SavePositionData.savePresets(square, presets, true)
            return true
        end
    end
    return false
end

--- Check if a player has access to a preset (owner, shared player, or faction member).
--- @param preset table The preset data
--- @param username string The player's username
--- @return boolean
function SavePositionData.hasAccess(preset, username)
    if not preset then return false end
    -- Owner always has access
    if preset.owner == username then return true end
    -- Check shared players list
    if preset.shared then
        for _, name in ipairs(preset.shared) do
            if name == username then return true end
        end
    end
    -- Check faction membership
    if preset.factions then
        for _, factionName in ipairs(preset.factions) do
            local faction = Faction.getFaction(factionName)
            if faction and faction:isMember(username) then
                return true
            end
        end
    end
    return false
end

--- Get all presets on a tile that a player can access.
--- @param square IsoGridSquare
--- @param username string
--- @return table Array of accessible presets
function SavePositionData.getAccessiblePresets(square, username)
    local presets = SavePositionData.getPresets(square)
    local accessible = {}
    for _, p in ipairs(presets) do
        if SavePositionData.hasAccess(p, username) then
            accessible[#accessible + 1] = p
        end
    end
    return accessible
end

--- Add a player to a preset's share list. Only owner can share.
--- @param square IsoGridSquare
--- @param presetName string
--- @param owner string Owner username (must match preset owner)
--- @param targetPlayer string Username to add
--- @return boolean
function SavePositionData.shareWithPlayer(square, presetName, owner, targetPlayer)
    local presets = SavePositionData.getPresets(square)
    for _, p in ipairs(presets) do
        if p.name == presetName and p.owner == owner then
            if not p.shared then p.shared = {} end
            -- Avoid duplicates
            for _, name in ipairs(p.shared) do
                if name == targetPlayer then return true end
            end
            p.shared[#p.shared + 1] = targetPlayer
            SavePositionData.savePresets(square, presets, true)
            return true
        end
    end
    return false
end

--- Remove a player from a preset's share list.
--- @param square IsoGridSquare
--- @param presetName string
--- @param owner string Owner username
--- @param targetPlayer string Username to remove
--- @return boolean
function SavePositionData.unsharePlayer(square, presetName, owner, targetPlayer)
    local presets = SavePositionData.getPresets(square)
    for _, p in ipairs(presets) do
        if p.name == presetName and p.owner == owner then
            if p.shared then
                for i, name in ipairs(p.shared) do
                    if name == targetPlayer then
                        table.remove(p.shared, i)
                        SavePositionData.savePresets(square, presets, true)
                        return true
                    end
                end
            end
        end
    end
    return false
end

--- Add a faction to a preset's faction share list.
--- @param square IsoGridSquare
--- @param presetName string
--- @param owner string Owner username
--- @param factionName string Faction name to add
--- @return boolean
function SavePositionData.shareWithFaction(square, presetName, owner, factionName)
    local presets = SavePositionData.getPresets(square)
    for _, p in ipairs(presets) do
        if p.name == presetName and p.owner == owner then
            if not p.factions then p.factions = {} end
            for _, f in ipairs(p.factions) do
                if f == factionName then return true end
            end
            p.factions[#p.factions + 1] = factionName
            SavePositionData.savePresets(square, presets, true)
            return true
        end
    end
    return false
end

--- Remove a faction from a preset's share list.
--- @param square IsoGridSquare
--- @param presetName string
--- @param owner string Owner username
--- @param factionName string Faction name to remove
--- @return boolean
function SavePositionData.unshareFaction(square, presetName, owner, factionName)
    local presets = SavePositionData.getPresets(square)
    for _, p in ipairs(presets) do
        if p.name == presetName and p.owner == owner then
            if p.factions then
                for i, f in ipairs(p.factions) do
                    if f == factionName then
                        table.remove(p.factions, i)
                        SavePositionData.savePresets(square, presets, true)
                        return true
                    end
                end
            end
        end
    end
    return false
end

--- "Forget" a shared preset — removes the current player from the shared list.
--- This lets a recipient hide a position without affecting others.
--- @param square IsoGridSquare
--- @param presetName string
--- @param username string The player forgetting the preset
--- @return boolean
function SavePositionData.forgetPreset(square, presetName, username)
    local presets = SavePositionData.getPresets(square)
    for _, p in ipairs(presets) do
        if p.name == presetName then
            -- Remove from shared players
            if p.shared then
                for i, name in ipairs(p.shared) do
                    if name == username then
                        table.remove(p.shared, i)
                        SavePositionData.savePresets(square, presets, true)
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- ==================== Serialization ====================
-- PZ modData stores flat key-value pairs. We serialize our presets table
-- as a semicolon-delimited string of preset entries.
-- Each preset is encoded as: name|xoff|yoff|zoff|xRot|yRot|zRot|owner|shared_csv|factions_csv

function SavePositionData._serialize(presets)
    if not presets or #presets == 0 then return nil end
    local parts = {}
    for _, p in ipairs(presets) do
        local sharedStr = ""
        if p.shared and #p.shared > 0 then
            sharedStr = SavePositionData._join(p.shared, ",")
        end
        local factionsStr = ""
        if p.factions and #p.factions > 0 then
            factionsStr = SavePositionData._join(p.factions, ",")
        end
        local entry = string.format("%s|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%s|%s|%s",
            p.name or "",
            p.xoff or 0, p.yoff or 0, p.zoff or 0,
            p.xRot or 0, p.yRot or 0, p.zRot or 0,
            p.owner or "",
            sharedStr,
            factionsStr
        )
        parts[#parts + 1] = entry
    end
    return SavePositionData._join(parts, ";")
end

function SavePositionData._deserialize(raw)
    if not raw or raw == "" then return {} end
    local presets = {}
    local entries = SavePositionData._split(raw, ";")
    for _, entry in ipairs(entries) do
        local fields = SavePositionData._split(entry, "|")
        if #fields >= 8 then
            local preset = {
                name = fields[1],
                xoff = tonumber(fields[2]) or 0,
                yoff = tonumber(fields[3]) or 0,
                zoff = tonumber(fields[4]) or 0,
                xRot = tonumber(fields[5]) or 0,
                yRot = tonumber(fields[6]) or 0,
                zRot = tonumber(fields[7]) or 0,
                owner = fields[8],
                shared = {},
                factions = {},
            }
            if fields[9] and fields[9] ~= "" then
                preset.shared = SavePositionData._split(fields[9], ",")
            end
            if fields[10] and fields[10] ~= "" then
                preset.factions = SavePositionData._split(fields[10], ",")
            end
            presets[#presets + 1] = preset
        end
    end
    return presets
end

--- Split a string by delimiter (Kahlua-compatible).
function SavePositionData._split(str, sep)
    if not str or str == "" then return {} end
    local result = {}
    local start = 1
    while true do
        local pos = str:find(sep, start, true)  -- plain find, no patterns
        if pos then
            result[#result + 1] = str:sub(start, pos - 1)
            start = pos + #sep
        else
            result[#result + 1] = str:sub(start)
            break
        end
    end
    return result
end

--- Join table entries with delimiter (Kahlua-compatible, no table.concat).
function SavePositionData._join(tbl, sep)
    local str = ""
    for i, v in ipairs(tbl) do
        if i > 1 then str = str .. sep end
        str = str .. tostring(v)
    end
    return str
end


-- ==================== Categories (per-player, stored on player modData) ====================

local CATEGORIES_KEY = PREFIX .. "categories"
local PRESET_CATEGORIES_KEY = PREFIX .. "preset_categories"
local DEFAULT_CATEGORY = "Uncategorized"

--- Get all categories for a player. Always includes "Uncategorized".
--- @param player IsoPlayer
--- @return table Array of category name strings
function SavePositionData.getCategories(player)
    local modData = player:getModData()
    local raw = modData[CATEGORIES_KEY]
    local categories = {DEFAULT_CATEGORY}
    if raw and raw ~= "" then
        local parsed = SavePositionData._split(raw, ";")
        for _, cat in ipairs(parsed) do
            if cat ~= DEFAULT_CATEGORY and cat ~= "" then
                categories[#categories + 1] = cat
            end
        end
    end
    return categories
end

--- Add a category for a player.
--- @param player IsoPlayer
--- @param categoryName string
--- @return boolean, string Success and error message
function SavePositionData.addCategory(player, categoryName)
    if not categoryName or categoryName == "" then
        return false, getText("UI_SLP_Error_Generic")
    end
    if categoryName == DEFAULT_CATEGORY then
        return false, getText("UI_SLP_Error_DuplicateCategory")
    end
    local categories = SavePositionData.getCategories(player)
    for _, cat in ipairs(categories) do
        if cat == categoryName then
            return false, getText("UI_SLP_Error_DuplicateCategory")
        end
    end
    categories[#categories + 1] = categoryName
    -- Save (exclude Uncategorized from storage, it's always implicit)
    local toStore = {}
    for _, cat in ipairs(categories) do
        if cat ~= DEFAULT_CATEGORY then
            toStore[#toStore + 1] = cat
        end
    end
    player:getModData()[CATEGORIES_KEY] = SavePositionData._join(toStore, ";")
    player:transmitModData()
    return true, nil
end

--- Remove a category for a player. Deletes all presets assigned to it.
--- Cannot delete "Uncategorized".
--- @param player IsoPlayer
--- @param categoryName string
--- @return boolean
function SavePositionData.removeCategory(player, categoryName)
    if categoryName == DEFAULT_CATEGORY then return false end
    local categories = SavePositionData.getCategories(player)
    local found = false
    local toStore = {}
    for _, cat in ipairs(categories) do
        if cat == categoryName then
            found = true
        elseif cat ~= DEFAULT_CATEGORY then
            toStore[#toStore + 1] = cat
        end
    end
    if not found then return false end
    player:getModData()[CATEGORIES_KEY] = SavePositionData._join(toStore, ";")
    -- Remove all preset-to-category mappings for this category
    SavePositionData._removePresetsInCategory(player, categoryName)
    player:transmitModData()
    return true
end

--- Get the category assigned to a preset (by tile coords + preset name).
--- Returns DEFAULT_CATEGORY if not assigned.
--- @param player IsoPlayer
--- @param sqX number
--- @param sqY number
--- @param sqZ number
--- @param presetName string
--- @return string Category name
function SavePositionData.getPresetCategory(player, sqX, sqY, sqZ, presetName)
    local modData = player:getModData()
    local raw = modData[PRESET_CATEGORIES_KEY]
    if not raw or raw == "" then return DEFAULT_CATEGORY end
    local key = SavePositionData._presetCategoryKey(sqX, sqY, sqZ, presetName)
    local entries = SavePositionData._split(raw, ";")
    for _, entry in ipairs(entries) do
        local parts = SavePositionData._split(entry, "=")
        if #parts == 2 and parts[1] == key then
            return parts[2]
        end
    end
    return DEFAULT_CATEGORY
end

--- Assign a preset to a category.
--- @param player IsoPlayer
--- @param sqX number
--- @param sqY number
--- @param sqZ number
--- @param presetName string
--- @param categoryName string
function SavePositionData.setPresetCategory(player, sqX, sqY, sqZ, presetName, categoryName)
    local modData = player:getModData()
    local raw = modData[PRESET_CATEGORIES_KEY] or ""
    local key = SavePositionData._presetCategoryKey(sqX, sqY, sqZ, presetName)
    local entries = SavePositionData._split(raw, ";")
    local newEntries = {}
    local found = false
    for _, entry in ipairs(entries) do
        local parts = SavePositionData._split(entry, "=")
        if #parts == 2 and parts[1] == key then
            -- Replace existing
            if categoryName ~= DEFAULT_CATEGORY then
                newEntries[#newEntries + 1] = key .. "=" .. categoryName
            end
            found = true
        else
            if entry ~= "" then
                newEntries[#newEntries + 1] = entry
            end
        end
    end
    if not found and categoryName ~= DEFAULT_CATEGORY then
        newEntries[#newEntries + 1] = key .. "=" .. categoryName
    end
    modData[PRESET_CATEGORIES_KEY] = SavePositionData._join(newEntries, ";")
    player:transmitModData()
end

--- Get all presets assigned to a specific category for a player.
--- Returns table of {sqX, sqY, sqZ, presetName} entries.
function SavePositionData.getPresetsInCategory(player, categoryName)
    local modData = player:getModData()
    local raw = modData[PRESET_CATEGORIES_KEY] or ""
    local results = {}
    if categoryName == DEFAULT_CATEGORY then
        -- "Uncategorized" means all presets NOT assigned to any category
        -- We need the caller to determine this by checking all accessible presets
        return nil -- signal to caller to handle differently
    end
    local entries = SavePositionData._split(raw, ";")
    for _, entry in ipairs(entries) do
        local parts = SavePositionData._split(entry, "=")
        if #parts == 2 and parts[2] == categoryName then
            local keyParts = SavePositionData._split(parts[1], ",")
            if #keyParts == 4 then
                results[#results + 1] = {
                    sqX = tonumber(keyParts[1]),
                    sqY = tonumber(keyParts[2]),
                    sqZ = tonumber(keyParts[3]),
                    presetName = keyParts[4],
                }
            end
        end
    end
    return results
end

--- Remove all preset-category mappings for a given category.
function SavePositionData._removePresetsInCategory(player, categoryName)
    local modData = player:getModData()
    local raw = modData[PRESET_CATEGORIES_KEY] or ""
    local entries = SavePositionData._split(raw, ";")
    local newEntries = {}
    for _, entry in ipairs(entries) do
        local parts = SavePositionData._split(entry, "=")
        if #parts == 2 and parts[2] ~= categoryName then
            newEntries[#newEntries + 1] = entry
        end
    end
    modData[PRESET_CATEGORIES_KEY] = SavePositionData._join(newEntries, ";")
end

--- Build a unique key for a preset's category mapping.
function SavePositionData._presetCategoryKey(sqX, sqY, sqZ, presetName)
    return string.format("%.0f,%.0f,%.0f,%s", sqX, sqY, sqZ, presetName)
end
