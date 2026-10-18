# Westbound farming research

Research date: 2026-10-18

## What is verified from first-party sources

The official Roblox experience page identifies Westbound as experience/place `2474168535` by Moondrop Studios. Its current description says players can become outlaws or bounty hunters, or hunt and mine for wealth. It does not document reward amounts, robbery cooldowns, remotes, model names, bag limits, or a guaranteed money rate. [Official Westbound page](https://www.roblox.com/games/2474168535/Westbound?_escaped_fragment_=%2Fabout)

That means the prior claim of a guaranteed `$100,000/min` is not supported by the official public documentation. No public first-party source found here gives a current rate or confirms that old exploit routes still work.

## Inspectable implementation evidence (unofficial)

Two publicly readable, user-uploaded scripts independently expose the same apparent client-visible object contract. They are evidence of how old scripts attempted the route, not proof that the route is current or safe:

- `Players.LocalPlayer.States.Bag` is compared with `Players.LocalPlayer.Stats.BagSizeLevel.CurrentAmount`; when full, the scripts teleport to `CFrame.new(1636.62537, 104.349976, -1736.184)`.
- They search `Workspace:GetChildren()` for models named `CashRegister` and `Safe`.
- A register route looks for `Open`, `Union`, and `Active`, then fires `ReplicatedStorage.GeneralEvents.Rob` with action `"Register"` and a table containing those instances plus `Active=true`.
- A safe route requires an `Amount` value greater than zero, uses the model’s `Safe` part, and either fires `GeneralEvents.Rob` with `"Safe", item` when `Open.Value` is true or invokes `OpenSafe:FireServer("Completed")` first.

The raw implementation is readable here: [open-source auto farm raw script](https://rawscripts.net/raw/Westbound-Auto-farm-40000), published through [its ScriptBlox entry](https://scriptblox.com/script/Westbound-Auto-farm-40000). A second upload shows the same register/safe names and calls: [raw 10k route](https://rawscripts.net/raw/Westbound-100k-per-10-mins-29580), [ScriptBlox entry](https://scriptblox.com/script/Westbound-100k-per-10-mins-29580).

These scripts contain no reliable server validation, cooldown discovery, or proof that the remote calls succeed. They also mutate the character and repeatedly teleport it. They should be treated as historical clues for inspection, not as a farming implementation to copy blindly.

## Cash registers, banks, and rates

The current official page confirms only the broad activities. A community wiki describes cash registers as store objects with roughly `$10–$50` rewards and a temporary empty period, and describes bank safes as requiring interaction and a wait after robbery. Those pages are secondary and were not accessible for direct verification during this research, so their amounts and cooldowns remain unverified. Search result: [Cash Register community page](https://roblox-westbound.fandom.com/wiki/Cash_Register); [Bank community page](https://roblox-westbound.fandom.com/wiki/Bank).

The strongest rate claim found is a user-upload title advertising “10k every 1 min 20 secs.” The same page’s description contradicts itself by saying both “10k every 10 minutes” and “10k every 1 minute 20 seconds,” while comments are user enthusiasm rather than measurements. That is approximately `$7,500/min` under the faster wording, not `$100,000/min`, and it is not evidence of a current rate. [Claim page](https://scriptblox.com/script/Westbound-100k-per-10-mins-29580).

## Recommendation for a Farm tab

The evidence supports a small diagnostic and route-planning tab first:

1. Detect and list live `CashRegister` and `Safe` models, their `Open`/`Active`/`Amount` values, and the player’s bag amount versus capacity.
2. Show when the server has actually changed those values after a normal in-game interaction.
3. Keep register and safe routes separate, with a stop/return-to-camp control when the bag is full.
4. Add measured earnings per minute only after a connected live client records before/after money and the observed cooldown.

Until that live measurement exists, the project should label the `$100k/min` claim as unverified and avoid presenting any fixed payout or cooldown as fact.

## Cash-in implementation follow-up

The user confirmed ROUTE 3 collected money into the bag in their live session. Their report included active/inactive registers, a 70-capacity bag, three confirmed bag increases, and no cash/deposit/bag proximity prompts. It did not identify any camp object or current cash-in coordinate.

ROUTE 4 tries explicit outlaw-camp names/attributes among loaded objects as candidates, ordered by distance. Those names are heuristics awaiting live verification. The historical coordinate above is a fallback candidate, with streaming requests and the same grounded landing checks used by robbery routing. Neither a model name nor reaching the coordinate counts as success: the bag must reach zero before the farm resumes. Partial deposits keep the route waiting; failed candidates time out and are not retried during the same full-bag return. This confirms an empty bag, not an independently measured wallet payout. No current source establishes all camp locations or whole-map target discovery.

## Live map report and region discovery

A later ROUTE 4 report showed only one loaded Safe, no eligible targets, zero attempts, and zero teleports. The report omitted the Safe part/OpenSafe remote, so the exact rejection reason cannot be inferred from it. It did show twelve shop models spanning four outlaw areas: OutlawGeneralStore1-4, OutlawGunsmith1-4, and OutlawStableOwner1-4, directly under Workspace.Shops. GeneralStore1 at approximately (1632.2,104.4,-1730.1) is near the historical camp coordinate; that proximity is evidence of a camp-area anchor, not proof of the exact deposit trigger.

ROUTE 5 uses direct shop model/part positions as region discovery anchors when no usable robbery target is loaded. It requests streaming and scans again; any later movement still requires the existing ground/clearance checks. OutlawGeneralStore numbered variants are additional camp-area candidates. Deposit success still requires an empty bag. Reports now include explicit target rejection reasons and missing Safe/OpenSafe structural details rather than treating all idle states as cooldown waits.
