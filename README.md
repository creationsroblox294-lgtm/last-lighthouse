# The Last Lighthouse

Co-op Roblox survival game: keep the lighthouse lit through the storms. Full design: [DESIGN.md](DESIGN.md). Progress: [TODO.md](TODO.md).

The MVP (storms 1–20) is playable: storm cycle, the lamp and its beam, gathering and carrying, storage, refuelling, repairs and barricades, Fog Crawlers, the Drowned, the Tide Caller boss, death and respawn, losing a run, and saved Keeper Levels.

## How the project is split

- **Map and models** are in the Roblox place (Team Create, place ID `105296957287807`). Build them in Studio.
- **Code** is in this repo under `src/`, synced into Studio with [Rojo](https://rojo.space).

| Folder | Goes to in Studio |
|---|---|
| `src/shared` | `ReplicatedStorage.Shared` |
| `src/server` | `ServerScriptService.Server` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` |

## Setup (each teammate, once)

1. Install Rojo (for example with [Aftman](https://github.com/LPGhatguy/aftman) or from the Rojo releases page) and the Rojo plugin in Studio.
2. `git clone https://github.com/creationsroblox294-lgtm/last-lighthouse`
3. In the repo folder: `rojo serve`
4. In Studio, open the place, open the Rojo plugin and click **Connect**.

**Rule:** only one person runs `rojo serve` into the Team Create place at a time, or you'll overwrite each other's scripts. Everyone else keeps building.

## How to play

- **Gather in the calm:** chop pines (hold E), catch fish at the tide pools (the dock opens at storm 5), and pick up wreckage on Wreck Beach (it washes up after every storm). You carry one item at a time.
- **Storage** (ground floor crates): *Store item* puts what you carry into the shared storage. *Take fuel* gives you an oil barrel (or wood) to carry.
- **The lamp** (lamp room, up the ladders): *Pour fuel* refuels it. Fuel burns 3× faster in storms. If it runs dry, you have 15 seconds before the fog swarms.
- **Beam control** (lamp room console): aim the beam with your camera. The beam stuns and burns creatures and is the only thing that hurts the Tide Caller (aim at its eyes).
- **Tools:** the Harpoon auto-aims at the nearest creature in front of you. The Hammer repairs the floor you're on, or a barricade (costs 1 wood or scrap from storage).
- **Barricades:** two spots (top of the ramp, in front of the door), 3 wood each.
- **Tower floors:** ground floor broken → damage moves upstairs; bunk room broken → no respawns; lamp room broken → fuel leaks. All three broken → run lost.
- **Death:** in a storm you're lost in the fog until dawn. If everyone is down during a storm, the run is lost.

## Testing in Studio

Select **Workspace** and use these attributes in the Properties window (Studio only, ignored in live games):

| Attribute | What it does |
|---|---|
| `DebugFastCycle` | Phases last 10 s, storms 45 s |
| `DebugStartStorm` | Start the run at this storm (10 = Tide Caller) |
| `DebugDrainMultiplier` | Multiplies lamp fuel drain (try 40 to test lights out) |

Saving progress needs **Game Settings → Security → Enable Studio Access to API Services**. Without it, the game runs normally but doesn't save.

## Rebuilding the greybox map

`tools/BuildGreybox.luau` rebuilds `Workspace.Map` and the island terrain from scratch. Open **View → Command Bar**, paste the whole file in, and press Enter. It replaces the existing map, so don't run it once you've hand-edited the island.

## Creature models (Blender)

The creatures are built and animated in Blender (`LastLighthouse_Creatures.blend`, with `FogCrawler.fbx`, `Drowned.fbx` and `TideCaller.fbx` exported next to it, on the Mac that made them, in `~/the-last-lighthouse-assets`). In the game they're still greybox shapes until those models are uploaded to Roblox.
