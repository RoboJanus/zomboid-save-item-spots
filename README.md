# Save Item Spots - Project Zomboid Server Mod

A mod that lets players save item positions on tiles, then restore any item to that exact position and rotation later. Supports sharing saved positions with other players and factions.

## Features

- Save the position and rotation of any placed world item as a named preset
- Restore any item from your inventory to a saved position with one click
- Multiple presets per tile (configurable, default 5)
- Share positions with specific players or entire factions
- Multiplayer compatible — position data syncs via tile modData
- Persists through server restarts and save/load cycles
- Works with any world inventory item (decorative items, tools, etc.)

## How It Works

### Save a Position

1. Place an item on the ground/surface where you want it
2. Adjust its position using PZ's placement tools until it looks right
3. Right-click the item on the ground → **Save Position**
4. Enter a name for the preset (e.g., "Lamp on shelf", "Axe by door")

### Restore an Item

**From inventory:**
- Right-click an item in your inventory → **Place at Saved Position** → select a preset
- Your character walks to the tile and places the item at the exact saved offsets and rotation

**From tile:**
- Right-click a tile that has saved presets → **Place Saved Item** → select a preset → select an item from your inventory

### Sharing

- Positions are private by default (only the creator can see them)
- Right-click a tile → **Manage Positions** → select a preset → **Share...**
- Add player usernames or faction names to the share list
- Shared players/faction members see the presets in their context menus
- Recipients can **Forget** a shared position to hide it from their view

## Installation

1. Subscribe on Steam Workshop
2. Add `\savelastposition` to your server's `Mods=` line
3. Add the Workshop ID to `WorkshopItems=`
4. Restart the server

## Configuration

### Sandbox Options

| Option | Default | Description |
|--------|---------|-------------|
| Max Presets Per Tile | 5 | Maximum number of saved positions per tile (1-20) |
| Show Coordinates in Preset Names | true | Show tile coordinates next to preset names in context menus |
| Filter Equipped Items | true | Hide equipped items from the "Place Saved Item" list |

## Scope & Limitations

- Works with **world inventory items** (items on the ground/surfaces) only
- Does **NOT** work with moveables/furniture (shelves, tables, fridges, etc.)
- Items of different sizes may clip slightly when placed at a position saved by a different-sized item
- The mod has no concept of item dimensions — multiple presets may be needed on a tile for items of different lengths, widths, and orientations
- Standard PZ pathfinding is used — if the path is blocked, placement will fail gracefully
- The "Place at Saved Position" scan from inventory searches a 50-tile radius — distant presets may not appear

## TODO

- Test sharing functionality (faction checkbox, player selector, forget)
  - Also add sharing with safehouse members
- Do not display "Place Saved Item" presets that already have an item placed at them
- Force close context menu after removing a preset
- Make showing tile coordinates in preset names a configurable sandbox option
- Move "Filter Equipped Items" from sandbox option to per-player Mod Option (escape menu)
- Optional JSON API integration: export saved presets & categories via endpoint (requires JSON API mod)
  - Also add import endpoint to restore exported presets & categories
- Preset Management Panel: Add a "Presets" button to the client-side circle menu (alongside faction/safehouse buttons). Opens a full management UI where players can:
  - View all their saved and shared presets
  - Create/delete categories (with a mandatory "Uncategorized" category that cannot be deleted)
  - Assign presets to categories
  - When creating a preset (naming dialog), allow selecting or creating a category
  - Deleting a category with presets shows a warning and deletes all presets within it
  - Category deletion only available from the management window, not the context menu
  - Context menu changes: "Place at Saved Position" → Category submenu → Presets within that category

## Known Issues

- **Inconsistent placement offset**: In rare cases, an item may be placed at an incorrect position (center or edge of tile instead of saved offset). Removing and re-saving the preset resolves the issue. If you can find a way to consistently reproduce this, please report it on the Workshop page or GitHub with details about the item, tile, and steps.
- **Tile weight limit not enforced**: Placing items at a saved position does not check the tile's 50kg weight limit. Items can be placed on overweight tiles. This matches PZ's behavior for admin-placed items but could be exploited in some scenarios.

## Multiplayer

- Position presets are stored on tile modData, which syncs to all clients in the chunk
- Any player with access can place items at a shared preset
- Position data persists through trades, drops, and server restarts

## Compatibility

- Project Zomboid Build 42.20+
- Multiplayer dedicated servers and singleplayer
- No dependencies
- Does not conflict with other mods

## License

See LICENSE file.

## Source Code

[GitHub](https://github.com/RoboJanus/zomboid-save-position)
