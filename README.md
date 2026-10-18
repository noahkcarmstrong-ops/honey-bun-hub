# Honey Bun Hub

A minimal black, gray, and white Roblox hub. Press **Right Shift** to show or hide the menu.

## Run

Paste this once and save it. Rerun the same line after updates:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-hub/main/loader.lua", false))()
```

## Games

- **Westbound:** detected automatically, with its own file.
- **Other games:** the universal menu opens. Game-specific features require adding support.

This currently provides the menu only. No gameplay features have been added. The loader requires an environment that supports HttpGet and loadstring; it is not a normal Roblox Studio LocalScript.

## Adding a game

1. Add `games/your-game.lua`. It should return a table with `name` and `description` strings. Keep game-specific code in that file.
2. Add the game's universe ID (`game.GameId`) and file path to the `games` table in `loader.lua`. Universe IDs cover all places within the same game.
3. Run the same saved loader. No replacement launcher is needed.

Example game file:

```lua
return {
    name = "YOUR GAME",
    description = "Your game is ready.",
}
```

Rerunning removes the previous menu and disconnects its Right Shift listener. A module download failure falls back to the universal menu. GitHub may briefly cache older files after an update.
