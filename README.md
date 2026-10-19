# Honey Bun Hub

A minimal black, gray, and white Roblox hub. Press **Right Shift** to show or hide the menu.

## Run and update

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-hub/main/loader.lua", false))()
```

Use **Refresh** in the menu for new versions. Refresh and re-running the loader restore your last player, animal, and chest settings, including filters, individual animal choices, distances, and expanded option lists. The previous visuals and listeners are removed before rebuilding. Settings are backed up on the persistent PlayerGui, so restoring does not require executions to share global variables. Closing Roblox clears them. The first update from an older version starts saving settings once this version is loaded.

## Westbound

Westbound is detected automatically by universe ID. Open the top **ESP** tab. Player, animal, and treasure chest switches start **OFF** on first use, then restore your saved selections. Animal controls have their own section; extra player controls and world diagnostics are tucked under **More player options** and **More world options**.

- **Player ESP:** Cowboys blue, Outlaws red, other teams gray; a team filter and compact style presets. Name, distance and health labels; tracers; chams; visual root hitbox outlines; visible-only filter; distance limits, starting at **Unlimited**.
- **World controls:** animal type and distance; treasure chests with replicated gold amount when available. Animals and treasure chests can be switched separately, with an independent distance limit starting at **Unlimited**. **Animal types** lets you choose individual species. **Rare animal types** lists all supported rare variants even before they spawn. Opening either list preserves selections; turning rare-only on selects rare variants after None. **Rare animals only** filters to animals with readable rarity markers or legendary/Dire Wolf names; rare labels are gold and preserve the variant name. Objects must be loaded by the game to be detected.

The hitbox option is a visual outline only and does not alter character hitboxes. Team classification uses actual team names containing Cowboy or Outlaw; other roles stay under Other teams.

**Animal chams** highlights selected animals through scenery: green for ordinary animals and gold for rare ones. Turn on **Animal ESP**, then **Animal chams**. Chams use the same animal selections, rare-only filter, and distance setting as animal labels. They start off and disappear when the animal is filtered out, removed, or the hub is refreshed. **Choose animals** and **Choose rare animals** expand grouped lists with explicit ON/OFF selections; opening a list keeps your selections.

**Outlaw bounty** is under **More player options**. With Player ESP and Labels enabled, it adds a second line to outlaw markers. It reads an explicit `Bounty` player attribute, `leaderstats.Bounty`, or a direct `Bounty` value, updating about every 0.15 seconds. If no readable amount exists, it shows **Bounty unavailable**, never an assumed zero. These field paths still need verification in live Westbound.

Animal and chest discovery uses model names, tags, and attributes. Exact live Westbound object names have not been inspected. Only chests with a readable unlooted state or positive gold are shown. Looted or empty chests are hidden. Unavailable gold is omitted from the label; amounts are never guessed. Detection covers objects streamed to the client, with no fixed target cap. Unloaded objects cannot be detected. Loot flags refresh about every 0.1 seconds; gold amounts refresh about once per second. Player markers update every frame.

## Farm (experimental)

The **FARM** tab beside **ESP** contains a register/safe route based on a historical Westbound implementation. Its live compatibility and payout rate still require verification. No `$100k/min` rate or removal of server cooldowns is promised; research and sources are in [docs/farming-research.md](docs/farming-research.md).

1. Choose registers, safes, or both, then press **Start**.
2. The route chooses the nearest loaded register or safe and teleports beside it only if ground and standing clearance checks pass.
3. When the bag fills, the route returns to a camp and waits for the bag to reach zero before continuing. **Stop**, Refresh, damage, and death still cancel the run.

**ROUTE 7** uses teleport routing with checked landings. Targets nested in folders are detected. Each distant target needs nearby loaded, anchored, nearly level ground, no water, and space for a standing character. The route clears movement velocity before and after moving, pauses for landing, and stops if the player takes damage or remains airborne. A grounded character pushed out of reach causes that target to back off while the route continues. HealthChanged/Died signals cancel actions immediately, with heartbeat checks as a fallback. Failures back off for 15, 30, 60, then at most 120 seconds per target. Collection failures no longer stop the entire route after three attempts. Inactive registers are skipped. Successful targets are skipped for 30 seconds; this is a local retry delay, not a detected server cooldown. Safes accept either the Safe or SafePart body and must replicate an open state before the collection request. Distant targets request streaming before landing checks.

These checks reduce observable risks but cannot prevent a server from killing a teleporting player. No live survival, whole-map coverage, or payout rate has been verified. When no target is available, the route uses the actual direct children of `Workspace.Shops` and previously seen target locations as region anchors, remembers them even after their objects unload, groups locations within 150 studs, requests streaming when supported, and rescans. Region discovery never teleports the character to a shop. After the request completes or times out, it rescans and searches another region if no usable target appeared. Only actual robbery targets or camp-return candidates can initiate movement. Regions rotate with a 30-second revisit delay. Stop, Refresh, damage, and character changes cancel pending region movement. This improves discovery beyond the current area but does not guarantee that every target on the map becomes available. For cash-in, it tries the nearest loaded model/part explicitly named OutlawCamp (including numbered variants), OutlawCampCashIn, OutlawCashIn, or Camp with an Outlaw Team/Faction attribute. These identifiers are candidate heuristics, not verified current map metadata. If those candidates are absent or fail, it tries the historical camp coordinate documented in the research. It requests streaming there when supported and checks ground before moving. Only an empty bag resumes farming; a partial deposit does not. Each camp gets one attempt per full bag, with a ten-second confirmation window, then the next candidate is tried. If no camp can empty the bag, the farm stops with a diagnostic message. Cash-in behavior still needs live verification. The manual **Set cash-in spot** control remains removed.

The farm tracks actual bag increases and cycles through targets until stopped or a safety/data/cash-in check fails. **Copy farm report** saves the last movement and damage/death record on PlayerGui, so these details survive respawning and hub Refresh for the current game session. It includes move purpose, destination, distance, health, observed velocity, and elapsed time from the last movement. It also includes explicit rejection reasons, Safe/OpenSafe types, relevant safe descendants, region request counts, target details, and any loaded prompts mentioning cash, deposit, or bag; those prompts are diagnostic clues, not verified destinations. The selected mode is remembered for the current session; running always resets to stopped on reload.

## Other games and future additions

Other games open the universal menu until game-specific support is added. To add a game:

1. Add `games/your-game.lua`, returning a table with `name`, `description`, and optionally `mount(contentFrame)`.
2. The optional mount function adds controls to the shared scrolling panel and returns an idempotent cleanup function. It should also clean up when contentFrame is destroyed.
3. Add its universe ID (`game.GameId`) and file path to the `games` table in `loader.lua`. The saved launcher stays the same.

The loader requires an environment with HttpGet and loadstring; it is not a normal Studio LocalScript.

## Validation

Lua syntax checks and simulated lifecycle tests covered respawns, team filters, switches, player removal, missing cameras, animal classification, gold labels, late tags, and cleanup. Live Westbound rendering and metadata still require in-game verification.

Run the player and bounty checks with `npx --yes --package=fengari-node-cli fengari tests/player-esp.lua`.
