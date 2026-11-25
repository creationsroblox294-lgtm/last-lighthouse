# The Last Lighthouse

Co-op Roblox survival game: keep the lighthouse lit through 100 storms. Full design: [DESIGN.md](DESIGN.md). Progress: [TODO.md](TODO.md).

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

## Playtesting a full cycle quickly

In Studio, select **Workspace**, and in Properties tick the **DebugFastCycle** attribute. Every phase then lasts 10 seconds. Untick it to get the real timings (calm 3 min, warning 30 s, storm 2–3 min, dawn 20 s).

## Rebuilding the greybox map

`tools/BuildGreybox.luau` rebuilds `Workspace.Map` from scratch. Open **View → Command Bar**, paste the whole file in, and press Enter. It replaces the existing map, so don't run it once you've hand-edited the island.
