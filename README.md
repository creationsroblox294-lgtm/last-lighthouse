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

Creatures are sculpted, textured, rigged and animated in Blender (`LastLighthouse_Creatures_HD.blend` in `~/the-last-lighthouse-assets` on the Mac that made them), then uploaded to Roblox:

- **Model** (FBX, skinned mesh with bones) goes in `ReplicatedStorage.CreatureModels.<Kind>`, with a `SurfaceAppearance` holding the baked colour, normal and roughness maps.
- **Animation data** goes in `ReplicatedStorage.CreatureAnimData.<Kind>`: a ModuleScript Blender writes with every animated bone's frame per sample. `Shared/CreatureRig` turns it into `Bone.Transform`s once, and `Client/CreatureController` plays it. The server only sets `Anim` / `AnimSpeed` attributes on each creature.

Done so far: **Fog Crawler** (idle, crawl, lunge, flinch, death). The Drowned and the Tide Caller are next; until then they use greybox shapes.

Players ragdoll on death (`Server/Ragdoll`). Ladders in the tower use `Client/LadderController` for a smooth hop on and off at the top.

### Creature roster (all sculpted, textured, rigged and animated in Blender)

Models live in `ReplicatedStorage.CreatureModels.<Kind>`, baked bone animation in
`ReplicatedStorage.CreatureAnimData.<Kind>`; `CreatureController` plays them from the
`Anim` / `AnimSpeed` / `AnimRestart` attributes the server sets.

| Creature | In game | Clips | Model asset |
|---|---|---|---|
| Fog Crawler | yes (EnemyService) | Idle, Crawl, Lunge, Flinch, Death | 106333388555947 |
| Drowned | yes (EnemyService) | Emerge, Idle, Shamble, Pound, Stagger, Death | 137757214236315 |
| Hollow | yes (HollowService, after storm 12) | Emerge, Idle, Stalk, Run, Grab, Drag, Recoil | 101924572788940 |
| Tide Caller | yes (TideCaller, every 10th storm) | Rise, Idle, Slam, Recoil, Sink | 110352371021365 |
| Night Gull | model ready (later update) | Fly, Glide, Dive, Screech, Death | 112129942210312 |
| Fog Mimic | model ready (later update) | Idle, Walk, Reveal, Lunge, Death | 123143348501152 |
| Last Keeper | model ready (later update) | Idle, Walk, Swing, Summon, Death | 107210136670553 |

Blender source: `~/the-last-lighthouse-assets/LastLighthouse_Creatures_HD.blend`.

### The Hollow (between storms, from storm 13)
Stalks the most isolated player outside the light, grabs and drags them to the fog edge.
Free a victim with 3 harpoon hits, the **Flare** tool, the lighthouse beam, struggling
(tap Space / the screen), or by dragging into the light while the lamp is above half fuel.
Studio: set `workspace.DebugHollowNow = true` to make it appear a few seconds into any calm.

### Map builders
`tools/BuildLighthouse.luau` (octagonal tower, spiral stairs, furnished rooms),
`tools/LighthouseFloorCollision.luau` (stairwell collision), `tools/BuildIsland.luau`
(hills, creek, haze). Realistic trees come from Creator Store packs (Letaij oak, Qalus
foliage pack, Stridity tree pack) stored in `ServerStorage.TreeLibrary`.
