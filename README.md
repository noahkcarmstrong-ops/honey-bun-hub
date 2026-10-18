# Honey Bun Hub

A minimal black, gray, and white Roblox hub. Press **Right Shift** to show or hide the menu.

## Run and update

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-hub/main/loader.lua", false))()
```

Use **Refresh** in the menu for new versions. Refresh resets switches to their defaults and removes the previous visuals and listeners.

## Westbound

Westbound is detected automatically by universe ID. Open the top **ESP** tab. Player, animal, and treasure chest switches start **OFF**. Extra controls are tucked under **More player options** and **More world options**.

- **Player ESP:** Cowboys blue, Outlaws red, other teams gray; a team filter and compact style presets. Name, distance and health labels; tracers; chams; visual root hitbox outlines; visible-only filter; distance limits, starting at **Unlimited**.
- **World controls:** animal type and distance; treasure chests with replicated gold amount when available. Animals and treasure chests can be switched separately, with an independent distance limit starting at **Unlimited**. **Animal types** lets you choose individual species. **Rare animal types** lists all supported rare variants even before they spawn. Opening either list preserves selections; turning rare-only on selects rare variants after None. **Rare animals only** filters to animals with readable rarity markers or legendary/Dire Wolf names; rare labels are gold and preserve the variant name. Objects must be loaded by the game to be detected.

The hitbox option is a visual outline only and does not alter character hitboxes. Team classification uses actual team names containing Cowboy or Outlaw; other roles stay under Other teams.

**Outlaw bounty** is under **More player options**. With Player ESP and Labels enabled, it adds a second line to outlaw markers. It reads an explicit `Bounty` player attribute, `leaderstats.Bounty`, or a direct `Bounty` value, updating about every 0.15 seconds. If no readable amount exists, it shows **Bounty unavailable**, never an assumed zero. These field paths still need verification in live Westbound.

Animal and chest discovery uses model names, tags, and attributes. Exact live Westbound object names have not been inspected. Only chests with a readable unlooted state or positive gold are shown. Looted or empty chests are hidden. Unavailable gold is omitted from the label; amounts are never guessed. Detection covers objects streamed to the client, with no fixed target cap. Unloaded objects cannot be detected. Loot flags refresh about every 0.1 seconds; gold amounts refresh about once per second. Player markers update every frame.

## Other games and future additions

Other games open the universal menu until game-specific support is added. To add a game:

1. Add `games/your-game.lua`, returning a table with `name`, `description`, and optionally `mount(contentFrame)`.
2. The optional mount function adds controls to the shared scrolling panel and returns an idempotent cleanup function. It should also clean up when contentFrame is destroyed.
3. Add its universe ID (`game.GameId`) and file path to the `games` table in `loader.lua`. The saved launcher stays the same.

The loader requires an environment with HttpGet and loadstring; it is not a normal Studio LocalScript.

## Validation

Lua syntax checks and simulated lifecycle tests covered respawns, team filters, switches, player removal, missing cameras, animal classification, gold labels, late tags, and cleanup. Live Westbound rendering and metadata still require in-game verification.

Run the player and bounty checks with `npx --yes --package=fengari-node-cli fengari tests/player-esp.lua`.
