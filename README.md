# Honey Bun Hub

A minimal black, gray, and white Roblox hub. Press **Right Shift** to show or hide the menu.

## Run and update

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-hub/main/loader.lua", false))()
```

Use **Refresh** in the menu for new versions. Refresh resets switches to their defaults and removes the previous visuals and listeners.

## Westbound

Westbound is detected automatically by universe ID. Both ESP master switches start **OFF**. Scroll the menu to find all controls.

- **Player ESP:** Cowboys blue, Outlaws red, other teams gray; separate team filters and live counts. Name, distance and health labels; tracers; 2D boxes; chams; visual root hitbox outlines; visible-only filter; distance limits.
- **World ESP:** animal type and distance; treasure chests with replicated gold amount when available. Animals and treasure chests can be switched separately, with an independent distance limit.

The hitbox option is a visual outline only and does not alter character hitboxes. Team classification uses actual team names containing Cowboy or Outlaw; other roles stay under Other teams.

Animal and chest discovery uses model names, tags, and attributes. Exact live Westbound object names have not been inspected. Models with unavailable or non-replicated gold display **Gold unknown**; amounts are never guessed. Detection is limited to 300 tracked world targets and objects streamed to the client. Gold labels refresh about once per second.

## Other games and future additions

Other games open the universal menu until game-specific support is added. To add a game:

1. Add `games/your-game.lua`, returning a table with `name`, `description`, and optionally `mount(contentFrame)`.
2. The optional mount function adds controls to the shared scrolling panel and returns an idempotent cleanup function. It should also clean up when contentFrame is destroyed.
3. Add its universe ID (`game.GameId`) and file path to the `games` table in `loader.lua`. The saved launcher stays the same.

The loader requires an environment with HttpGet and loadstring; it is not a normal Studio LocalScript.

## Validation

Lua syntax checks and simulated lifecycle tests covered respawns, team filters, switches, player removal, missing cameras, animal classification, gold labels, late tags, and cleanup. Live Westbound rendering and metadata still require in-game verification.
