# Save Item Spots - Manual Test Procedures

## Prerequisites

- Local dev server running with the mod loaded (`docker-compose -f docker-compose.dev.yml up -d`)
- PZ client connected with a character
- Mod enabled in the server's `Mods=` line
- Have a few items in inventory for placement testing (axe, lamp, mug, etc.)
- For sharing tests: a second player account or use admin commands to simulate

## Setup Notes

- Place items on surfaces/ground using PZ's standard drag-and-drop or right-click "Place Item"
- Presets are stored on tile modData — they survive relog and server restart
- Categories are stored on player modData — personal to each player
- The `SandboxVars.SaveLastPosition.MaxPresetsPerTile` defaults to 5

---

## Tests Group 1: Core Save & Restore (No Restart Required)

These tests cover the basic save/place loop. Run in sequence.

### 1.1 Save Position — Basic

1. Drop an item on the ground (e.g., a Mug)
2. Use PZ's placement tools to position it precisely on a surface
3. Right-click the item **on the ground** in the inventory panel
4. **Verify:** "Save Position" option appears in context menu
5. Select "Save Position"
6. **Verify:** A custom dialog opens with a name field and a category dropdown
7. Enter "Test Spot 1", leave category as "Uncategorized", click OK
8. **Verify:** HaloNote shows "Position saved: Test Spot 1"

### 1.2 Save Position — Duplicate Name Rejected

1. With the same item still on the ground, right-click → "Save Position"
2. Enter "Test Spot 1" again (same name as before), click OK
3. **Verify:** Error HaloNote about duplicate name appears
4. **Verify:** No duplicate preset is created (verify in 1.5)

### 1.3 Save Position — Multiple Presets on Same Tile

1. Move the item to a slightly different position on the same tile
2. Right-click → "Save Position" → name it "Test Spot 2"
3. **Verify:** Saves successfully
4. Repeat for "Test Spot 3"
5. **Verify:** Tile now has 3 saved presets

### 1.4 Place at Saved Position — From Inventory

1. Pick up the item from the ground (put it in inventory)
2. Right-click the item **in your inventory**
3. **Verify:** "Place at Saved Position" submenu appears with Category → Presets hierarchy
4. **Verify:** "Uncategorized" submenu lists "Test Spot 1", "Test Spot 2", "Test Spot 3"
5. Select Uncategorized → "Test Spot 1"
6. **Verify:** Character walks to the tile
7. **Verify:** Item is placed at the exact saved position and rotation
8. **Verify:** Item disappears from inventory
9. **Verify:** Item can be picked up again normally

### 1.5 Place at Saved Position — From Tile Context Menu

1. Pick up the item again
2. Right-click the **tile** (ground/floor) where presets are saved
3. **Verify:** "Place Saved Item" submenu appears
4. **Verify:** Submenu shows preset names, each with a sub-list of items in inventory
5. Select "Test Spot 2" → select the item
6. **Verify:** Character walks and places the item at Spot 2's position

### 1.6 Place at Saved Position — Rotation Preserved

1. Place an item on the ground and rotate it to a distinctive angle
2. Right-click → "Save Position" → name it "Rotated Spot"
3. Pick up the item, then restore it via "Place at Saved Position" → Uncategorized → "Rotated Spot"
4. **Verify:** The item's rotation matches what was saved (same angle)

### 1.7 Place at Saved Position — Different Item

1. Save a position using Item A (e.g., Axe)
2. Pick up a different Item B (e.g., Hammer) from your inventory
3. Right-click tile → "Place Saved Item" → select the Axe's preset → select the Hammer
4. **Verify:** Hammer is placed at the position saved by the Axe
5. **Verify:** May clip slightly (expected for different-sized items)

### 1.8 Save Position — Max Presets Limit

1. Save presets until you reach 5 total on one tile (or whatever MaxPresetsPerTile is set to)
2. Attempt to save a 6th preset
3. **Verify:** Error message about maximum presets reached
4. **Verify:** No 6th preset is created

### 1.9 Remove Preset — Via Item Spots Panel

1. Right-click any tile → "Item Spots"
2. Select the category containing your preset
3. Select the preset in the right panel
4. Click "Remove"
5. **Verify:** HaloNote confirms removal
6. **Verify:** Preset no longer appears in context menus

---

## Tests Group 2: Edge Cases (No Restart Required)

### 2.1 Unreachable Tile

1. Save a position on a tile, then block the path to it (e.g., close a door, build a wall)
2. Try to place an item at that saved position
3. **Verify:** Character attempts to pathfind
4. **Verify:** Action fails gracefully (no crash, no item lost from inventory)

### 2.2 Item Too Heavy for Tile

1. Save a position on a tile that already has ~50kg of items on it
2. Try to place another heavy item at the saved position
3. **Verify:** Observe behavior (may allow placement — known issue on admin accounts)

### 2.3 Filter Equipped Items (Default: On)

1. Equip an item (e.g., hold an axe in primary hand)
2. Right-click a tile with saved presets → "Place Saved Item"
3. **Verify:** Equipped items do NOT appear in the item selection submenu (FilterEquippedItems defaults to true)

### 2.4 Context Menu on Item Without Position Data

1. Right-click an item **in your inventory** that has no nearby saved presets
2. **Verify:** "Place at Saved Position" does NOT appear (no presets in range)

### 2.5 Item Spots on Tile Without Presets

1. Right-click a random tile that has never had positions saved
2. **Verify:** "Item Spots" option DOES appear (always available)
3. **Verify:** No "Place Saved Item" or "Forget Position" options appear

### 2.6 Preset Name Length Limit

1. Try to save a preset with a name longer than 32 characters
2. **Verify:** Error message about name being too long

---

## Tests Group 3: Persistence (Relog Required)

### 3.1 Presets Persist After Relog

1. Save a preset on a tile, note its name
2. Disconnect and reconnect to the server
3. Right-click the same tile
4. **Verify:** The preset is still there with correct name and position data

### 3.2 Categories Persist After Relog

1. Create a category and assign a preset to it
2. Disconnect and reconnect
3. Open the Item Spots panel
4. **Verify:** The category and assignment still exist

---

## Tests Group 4: Persistence & Sandbox Options (Server Restart Required)

Before restarting, change `SandboxVars.SaveLastPosition.MaxPresetsPerTile` to 2 in the server's `KLICKALACK_SandboxVars.lua`, then restart.

### 4.1 Presets Survive Server Restart

1. Save several presets on different tiles before the restart
2. Restart the server: `docker-compose -f docker-compose.dev.yml restart pz-dev`
3. Reconnect and check the tiles
4. **Verify:** All presets are still present with correct data

### 4.2 Placed Items Retain Position After Restart

1. Place an item at a saved position before the restart
2. Restart the server
3. Reconnect and check the item
4. **Verify:** Item is still at the exact saved position and rotation

### 4.3 Max Presets Per Tile — Custom Value

1. After restart, confirm the limit is now 2
2. Save 2 presets on a fresh tile (should succeed)
3. Attempt to save a 3rd preset on the same tile
4. **Verify:** Error about max presets, limited to 2

---

## Tests Group 5: Categories (No Restart Required)

### 5.1 Save Dialog — Category Dropdown

1. Place an item on the ground and right-click → "Save Position"
2. **Verify:** A custom dialog opens with both a name field and a category dropdown
3. **Verify:** Dropdown contains "Uncategorized" and "New Category..."
4. Enter a name and leave category as "Uncategorized", click OK
5. **Verify:** Preset is saved successfully

### 5.2 Save Dialog — Create New Category

1. Place another item, right-click → "Save Position"
2. Select "New Category..." from the category dropdown
3. **Verify:** A text box appears asking for the category name
4. Enter "Living Room" and confirm
5. **Verify:** "Living Room" now appears selected in the dropdown
6. Enter a preset name and click OK
7. **Verify:** Preset is saved and assigned to "Living Room"

### 5.3 Context Menu — Category Submenu Structure

1. Right-click an item in inventory
2. **Verify:** "Place at Saved Position" shows Category → Presets hierarchy
3. **Verify:** "Uncategorized" contains old presets
4. **Verify:** "Living Room" contains the preset from test 5.2

### 5.4 Existing Presets Default to Uncategorized

1. Check presets saved before categories were implemented
2. **Verify:** They all appear under "Uncategorized" in the context menu

### 5.5 Item Spots Panel — Open

1. Right-click any tile in the world
2. **Verify:** "Item Spots" option appears
3. Click it
4. **Verify:** A management panel opens showing categories on the left and presets on the right

### 5.6 Item Spots Panel — View Presets by Category

1. In the panel, click "Uncategorized" in the category list
2. **Verify:** Right panel shows all uncategorized presets
3. Click "Living Room"
4. **Verify:** Right panel shows only presets assigned to Living Room

### 5.7 Item Spots Panel — Create Category

1. Click "New Category..." in the panel
2. Enter "Bedroom" and confirm
3. **Verify:** "Bedroom" appears in the category list

### 5.8 Item Spots Panel — Move Preset to Category

1. Select a preset in the right panel
2. Click "Move to Category"
3. **Verify:** A category selector appears
4. Select "Bedroom" and confirm
5. **Verify:** Preset moves out of the current category list
6. Click "Bedroom" in categories
7. **Verify:** Preset now appears there

### 5.9 Item Spots Panel — Delete Category

1. Select "Bedroom" in the category list
2. Click "Delete Category"
3. **Verify:** Warning dialog appears: "Delete category 'Bedroom'? All presets in this category will be deleted."
4. Click OK
5. **Verify:** "Bedroom" disappears from category list
6. **Verify:** Presets that were in Bedroom are also deleted

### 5.10 Item Spots Panel — Cannot Delete Uncategorized

1. Select "Uncategorized" in the category list
2. Click "Delete Category"
3. **Verify:** Error message "Cannot delete the Uncategorized category."

### 5.11 Item Spots Panel — Delete Preset

1. Select a preset in the right panel
2. Click "Remove"
3. **Verify:** Preset is removed from the list
4. Right-click the tile where the preset was
5. **Verify:** Preset no longer appears in context menus

---

## Tests Group 6: Sharing UI (Two Players Required)

### 6.1 Manage Sharing — Open Panel

1. Right-click a tile with your own preset → "Item Spots"
2. Select the preset, open sharing (via context menu "Share..." on the preset's tile)
3. **Verify:** Sharing panel opens with faction checkbox and shared players list

### 6.2 Manage Sharing — Faction Checkbox

1. Be in a faction
2. Open the Share panel for your preset
3. **Verify:** Panel shows a checkbox "Share with my faction (FactionName)"
4. Check the box
5. **Verify:** Faction members can now see the preset

### 6.3 Manage Sharing — No Faction

1. As a player NOT in a faction, open the Share panel
2. **Verify:** Instead of a checkbox, shows "Not in a faction."

### 6.4 Manage Sharing — Add Player

1. Click "Add" in the Shared Players section
2. **Verify:** A player list selector opens showing connected players
3. Select a player and click "Add"
4. **Verify:** Player appears in the Shared Players list

### 6.5 Manage Sharing — Remove Player

1. Select a player in the Shared Players list
2. Click "Remove"
3. **Verify:** Player is removed from the list

### 6.6 Shared Player Sees Preset (Two Players)

1. Player A saves a preset and shares it with Player B
2. Player B right-clicks the same tile
3. **Verify:** Player B sees "Place Saved Item" with Player A's shared preset listed
4. **Verify:** Player B can place an item at the shared preset
5. **Verify:** Shared preset appears in Player B's "Uncategorized" category

### 6.7 Forget Shared Preset

1. As Player B (recipient of a shared preset), right-click the tile
2. **Verify:** "Forget Position" submenu appears with shared presets listed
3. Select a preset to forget
4. **Verify:** HaloNote confirms
5. Right-click the tile again
6. **Verify:** The forgotten preset no longer appears for Player B
7. **Verify:** Player A still sees and owns the preset (unaffected)

---

## Known Limitations

- Works with world inventory items only, NOT moveables/furniture
- Different-sized items may clip when placed at the same preset position
- The 50-tile radius scan for "Place at Saved Position" from inventory may miss distant presets
- In singleplayer, `transmitModdata()` is a no-op (data still saves locally via modData persistence)
- FilterEquippedItems sandbox option (default true) hides equipped items from "Place Saved Item" list
