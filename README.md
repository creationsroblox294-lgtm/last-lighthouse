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

### Island v2 (bigger island, taller tower, dock, fishing)
- Tower raised by 32.4 studs: a stone shaft with two extra spiral flights and landings sits
  between the bunk room and the lamp room (`LampRoom.Shaft`); lamp is now at y 107.4.
  Dark slate / oxblood exterior.
- Island radius ~310 around (0, 170) — grows south, the lighthouse cliff stays on the north
  coast. Wreck Beach moved to the north-west shore, Tide Pools to the east shore.
  ~165 realistic trees spread across it; the creek runs all the way to the south-west coast.
- `Map.OldDock` is now a new dock just west of the cliff with a Blender rowboat
  (asset 102575389973686). Fishing from its end still works (storm unlock attribute).
- Fish (Blender, asset 126593409966690; clips Swim / Flee / Flop) swim in `Map.FishingWaters`
  schools. Hold E near one to catch a **raw fish**, cook it at the lighthouse **fireplace**,
  then store it or eat it in the bunk room. Tide pools also give raw fish now.

### Island v3 (tower on the ground, cartoon forest)
- The cliff and ramp are gone: the lighthouse stands on flat grass at (55, 7, -80). It is one
  flight taller (`LampRoom.Shaft2`, built by the `extraFlight` stage); lamp at y 94.4.
  Floors: 7.0 / 23.0 / 39.2 / 55.4 / 71.6, gallery deck 87.8. `Config.World.CliffTopY` is
  set to 1000 so enemy routing never uses the old ramp.
- Interior decluttered (barrels, coat rack, crafting bench, side table, extra chairs, bunk
  desk removed) and every station has a floating label: Store items, Take fuel, Cook fish,
  Eat, Pour fuel, Aim the beam.
- Forest restyled like 99 Nights in the Forest: blocky layered pines with buttress roots,
  a few blocky leafy trees and cube bushes, built by `tools/CartoonForest.luau`
  (`ServerStorage.CartoonForest`). The old realistic trees are kept in
  `ServerStorage.OldForestBackup` if you want them back. Monsters are unchanged.
- Brighter days: Calm/Dawn/Won looks raise Brightness and add `Exposure`
  (ExposureCompensation), with thinner fog. Lighting style is Soft; grass is shorter and
  a softer green.

### Island v4 (tower in the middle, wild coast, forage, tree animals)
- The lighthouse stands in a clearing in the middle of the island at (-10, 8, 150).
  `Config.Light.BeamRange` is 320 so the beam still reaches the sea; the Tide Caller
  rises north of the island at (40, 0, -150).
- Coastline: `tools/IslandShape.luau` adds peninsulas, bays and wobble (wreck beach, tide
  pools and the dock keep their shore).
- Darker pines/bushes; more trees on the new land.
- Forage (`Map.Forage`, `ForageService`): carrot patches, berry bushes, apple trees,
  mushrooms, pumpkins. Hold E to pick and eat (heals, regrows after 90 s). Flowers, rocks
  and fallen logs in `Map.Meadow`. Built by `tools/Vegetation.luau`.
- Tree animals (`TreeAnimalService` + `TreeAnimalController`): snakes, spiders and bats
  hide in pines near players away from the lighthouse. The tree rustles and a red ring
  marks where it lands; step out to dodge. If it lands on you it latches on (damage,
  slowed, shaky screen) until you tap Space/screen enough times. Studio test: set the
  `DebugAnimalsFast` attribute on Workspace. Models: `ReplicatedStorage.CreatureModels.
  Snake / Spider / Bat` with clips Hang, Drop, Latch, Land, Flee (block stand-ins are used
  if a model is missing).
- Blender assets (LastLighthouse_Creatures_HD.blend, collections SnakeHD / SpiderHD /
  BatHD / ForageHD), uploaded models: Snake 122994055079062, Spider 76600594312536,
  Bat 97310903063178, Forage plants 86526358719988 (textures: snake 97894312809995,
  spider 111102523044360, bat 75105393405429, forage 86609593311351). Anim data is uploaded
  as a binary .rbxm holding one ModuleScript (Open Cloud refuses .rbxmx).
- Three floors + lamp room: ground (8), bunk room (24), floor 3 (56.4, small store room with
  barrels, crates, bench and a hanging lantern), lamp room (88.8). The in-between landings
  at 40.2 and 72.6 are gone.
- Ladders instead of stairs (one per floor) built by `ServerStorage.LadderBuilder`: wooden
  ladder against the wall, hatch in the floor above that is open on both faces of the
  ladder, side handrails. The invisible TrussPart `ClimbSurface` drives `LadderController`:
  climb from either side, at the top you hop sideways onto the floor beside the hatch; walk
  into a hatch from above to grab the ladder and hold S to go down.
- More fish: 21 schools all round the coast (`Map.FishingWaters`); a school part can carry
  `Tint` (Color3) and `Scale` attributes, so schools differ in colour and size (~105 fish). Water is clear
  (Terrain.WaterTransparency 0.92) so they show from the shore.
- Forage visuals are Blender meshes (carrot, apple, red/blue berries, red/brown mushrooms,
  pumpkin) kept in `ServerStorage.ForageMeshes`.
- Intro cutscene (`IntroController`, ~34 s, skippable) runs live in the engine and stars the
  player's own avatar: a clone of your character rows the boat at a saturated sunset, braces
  as the storm rolls in (rain, lightning, tossing boat), is thrown out as a physics ragdoll
  when the giant wave flips the boat, then lies on the south beach at dawn, pushes up and
  stands, and the camera flies over the forest to the lighthouse. The R15 clips (Row, Brace,
  GetUp in `Config.Intro.Animations`) were made with Studio's animation generator; each frame
  the actor's lowest body part is kept on its floor (boat or sand), so the poses rest on real
  surfaces. The camera eases between shots instead of cutting. While it plays the server
  points the player's `ReplicationFocus` at `Config.Intro.FilmSet` (anchoring the real
  character) so the far-off sea and beach stream in.
  `FogController.Hold` pauses the phase look while it plays. Turn it off with
  `Config.Intro.Enabled = false`. The boat is `ReplicatedStorage.IntroAssets.Rowboat` (a copy
  of the dock boat, so streaming can't leave it empty). Studio-only test hooks: workspace
  attributes `IntroSkipTo` (start N seconds in) and `IntroHoldAt` (freeze at N seconds).
- The ocean (terrain water, surface y = 0, 24 deep) now reaches about 1400 studs from the
  tower in every direction, so there is no visible edge from the lamp room or the intro. The Blender render of the same story stays in
  Cutscene_Intro.blend / IntroCutscene.mp4.

## Island v5 (2x) and sprint
- The island is twice as wide (heights unchanged), scaled around the lighthouse by
  `tools/MapScale.luau` (ServerStorage.MapScale): terrain re-sampled with bilinear
  occupancy and made solid under the surface, objects spread out and re-seated on the
  ground, the dock moved as one piece, and 2 extra copies of each tree / bush / flower /
  rock / forage plant scattered nearby (~4,000 items). Ocean (terrain water) reaches ~2600
  studs around the tower. Config positions that depend on the layout were scaled to match
  (IslandCenter/Radius, IntroBeach, BossPosition, Hollow lairs, fish schools, spawn radius,
  beam range); Calm/Dawn fog is lighter so the tower stays visible from the shore.
- Hold Shift (L3 on a gamepad, the Run button on touch) to sprint: x1.65 speed for about
  7 seconds of stamina, server-owned (`SprintService`, `Movement`). All walk-speed changes
  (carrying, tree-animal latch) go through `Movement.SetBase`, so sprint never stacks on a
  slow. A stamina bar shows when it isn't full and the camera widens a little while running.

## Minimap
- `MinimapController`: a round minimap in the bottom-left (north up, your arrow turns with
  the camera, teammates as blue dots). The lighthouse marker stays pinned to the rim when
  it's out of range, so it always points the way. Click it, press M (Select on a gamepad)
  or tap it to open the full island map with you, teammates (named) and the lighthouse.
- The map image (`assets/IslandMap.png`, Decal 112944993978047 → image 104506668850944) is
  a stitched top-down render of the island: six Studio screen captures from 1000 studs up
  (FOV 45), combined by `tools/stitch_map.py`, which also repaints the sea as one gradient.
  It covers the world square in `Config.Minimap` (X -1050..1050, Z -900..1200). Re-run the
  captures and the script if the island changes.

## Storm types
- `src/shared/StormTypes.luau` lists all 30 storms in five tiers (Blessed, Mild, Moderate,
  Severe, Catastrophic) with their barometer forecast, gameplay knobs (DrainMultiplier,
  RefuelPerSecond, HealPerSecond, EnemyMultiplier), sky look and particle textures.
  `StormDirector` rolls one per night by tier odds (storms 1-3: only Blessed or Mild; Great
  Storms stay ordinary). Only `Built = true` types roll; anything else plays as Ordinary.
- HUD shows `STORM n · ???` during the calm (plus a barometer hint) and reveals the name at
  the warning. Studio: Workspace attribute `DebugStormType` forces a type.
- Storm-specific server events: `src/server/Storms/<StormId>.luau` (Start/Stop), fired to
  clients through the `StormEvent` remote.
- Visuals: `src/client/StormFX/<StormId>.luau` (helpers in `StormFX/Common.luau`), played by
  `StormFXController` during the storm phase. Server-side player effects (healing etc.) are
  in `StormEffectsService`.
- Textures are rendered in Blender (`~/LastLighthouseAssets/storms/Storms_FX.blend` on the
  MacBook `akhils-macbook-pro-local`) and uploaded as decals from DemonBoy101122.

| Storm | Tier | What it does | Textures |
|---|---|---|---|
| Golden Rain | Blessed | lamp burns at calm rate and gains ~0.3 fuel/s, heals players under open sky, 60% creatures; gold rain, glints, falling stars, embers, splashes/ripples, gold sky | drop, splash, sparkle, ripple, mote |
| Starfall | Blessed | meteors every 1.3-2.6 s (22% chance of a 3-6 volley), warning ring, 20 dmg if hit, leave star shards (+8 lamp fuel each, max 12), lamp burns 2x; violet starry night, shooting stars, flash + shockwave + shake on impact | meteor, flash, star; StarShard model (ReplicatedStorage.StormAssets) |
| Bountiful Tide | Blessed | glowing waves crash on the beach nearest a player every 2.5-4.5 s (35% chance of a second wave right behind), shove anyone in the surf inland, wash up 2-4 oil/scrap/wood and a treasure chest 35% of the time (max 4, hold to open: loot straight into storage), lamp burns 1.6x, 40% fewer creatures; hot-pink sunset, turquoise bioluminescent sea, teal/pink lanterns rising, curling glass waves with foam + gold, crash spray + flash + shake, gold fountain from opened chests | foam (+ Golden Rain sparkle/mote); TreasureChest model (ReplicatedStorage.StormAssets) |
| Aurora Night | Blessed | creatures spawn at half health (EnemyHealthMultiplier 0.5) and 30% fewer; aurora wisps float near players every 1.6-3 s (max 10): touch one for +4 lamp fuel, +15 health and an aurora pulse that deals 35 to creatures within 26 studs; lamp burns 1.5x; deep starry night, 7 rippling aurora curtains (Beams, green hem to violet/pink), twinkling stars, light breathing green/violet, glowing wisps, ring + star burst on pickup | curtain (beam-rotated), wisp, twinkle |
| Fish Rain | Blessed | a fish falls near a player every 0.9-1.8 s with a landing marker (20% chance a school of 4-6 lands at once) and becomes a real Fish item; 10% are golden (take for +3 fish in storage, +6 lamp fuel, max 6); lamp burns 1.6x, 35% fewer creatures; slate storm sky with a rainbow arch, a giant twisting waterspout out at sea (Workspace attribute FishRainSpout), heavy silver rain, tumbling glinting fish, splash + ripple on landing, gold bursts | Fish model (ReplicatedStorage.StormAssets); rainbow, spray, glint (+ Golden Rain drop/splash) |
| Lucky Lightning | Blessed | a bolt every 1.4-2.8 s near a player after a 1.1 s crackle warning: 60% split a pine tree (tree falls, regrows later, 2-4 Wood items), others hit open ground (15 dmg + knockback within 7 studs); every strike deals 80 to creatures within 14 studs; 10% hit the lighthouse for +10 lamp fuel; lamp burns 1.7x, 25% fewer creatures; dry violet dusk, heat lightning and far forks, drifting lucky clovers and sparks, forked flickering bolts with screen flash, light and shake, wood chips/embers/clovers from trees, golden supercharge ring on the lamp | spark, clover, glow (+ Starfall flash, Golden Rain mote) |
| Drizzle | Mild | puddles spread around players every 2.5-4.5 s (max 16, Workspace.DrizzlePuddles); every 7-13 s a puddle near a player stirs for 2.6 s (glows sickly green, bubbles, rumbles) and a Fog Crawler climbs out; lamp burns 2.4x, 15% fewer creatures; hushed silver afternoon, fine slanted drizzle, low rolling haze, rain rings everywhere, black-water burst | bubble, haze (+ Golden Rain drop/splash/ripple) |
| Sea Breeze | Mild | steady wind (Workspace attribute WindDir) with a gust every 6-11 s: 1.3 s roar, then 2.6 s shoving anyone in the open downwind (pushed on each client, since players own their physics); 25% are rogue gusts that knock you flat; shelter overhead keeps you safe; lamp burns 2.5x, 15% fewer creatures; bright blustery day, racing wind lines, whirling leaves, streaming grass/clouds (GlobalWind), whitecaps, camera sway and FOV punch | leaf, streak |
| Morning Mist | Mild | every 5-9 s a hooded figure appears in the mist 25-50 studs from a player, turns to watch you and dissolves if you come within 18 studs; 30% are real and a Fog Mimic steps out instead; lamp burns 2.5x, 20% fewer creatures; pink-and-gold dawn, knee-deep sunlit mist, dew glints, sun rays, colour drains for a moment when a figure appears | Phantom model (ReplicatedStorage.StormAssets) (+ Drizzle haze, Fish Rain glint, Golden Rain mote) |
| Hailstorm | Mild | 2 damage every 1.5 s to anyone without cover overhead; every 7-12 s a giant hailstone lands near a player after a 2.8 s growing shadow (28 dmg + knocked down within 9 studs) and leaves an ice chunk that melts over 18 s; lamp burns 2.6x, 20% fewer creatures; steel-blue sky, pouring bouncing hail, frost creeping over the screen edges while exposed, ice trail, frost ring and shard burst on impact | Hailstone model (ReplicatedStorage.StormAssets); pellet, frost (+ Golden Rain splash) |
| Squall | Mild | every 12-18 s a wall of rain 140-200 studs thick forms 750 studs out at sea and sweeps across the island at 28-38 studs/s; rolling over the lighthouse drains 6 lamp fuel; anyone it catches gets a Fog Crawler spawned 22 studs behind them; lamp burns 2.4x, 20% fewer creatures; sullen grey-green light rain, scrolling rain-curtain walls you can watch approach, inside: blinding downpour, darkening, blur and shake | sheet (+ Golden Rain drop/splash) |
| Rolling Thunder | Mild | every 5-9 s a crackling static ring marks the spot a random player is standing on; 1.6 s later a bolt hits it (25 dmg + knocked down within 6 studs) and sets it burning for 10 s (4 dmg per half second to players and creatures standing in it); thunder rolls every 5-10 s (a chain of cloud flashes and a rolling rumble); lamp burns 2.6x, 20% fewer creatures; bruised purple-orange dusk, light rain, your own body crackles and the view flickers blue when you are targeted, scorched burning circles with flames, embers and smoke | flame, smoke (+ Lucky Lightning spark, Golden Rain drop/mote) |
| Gale | Moderate | constant wind (Workspace attribute WindDir): out in the open each client nudges its own character downwind (1.8 studs/s idle, walking upwind about a third slower); every 2.5-5 s a plank or branch is flung at a player from 140 studs upwind over 2.2 s (14 dmg + knocked down within 5 studs); every 4 s an exposed player carrying something has a 30% chance to have it torn away and dropped 18-32 studs downwind; lamp burns 3x; howling slate-green sky, sideways rain, wind lines and torn leaves, GlobalWind 120, huge whitecaps, shuddering camera | Plank, Branch models (ReplicatedStorage.StormAssets) (+ Sea Breeze leaf/streak, Golden Rain drop) |
| Thunderhead | Moderate | a bolt every 0.9-2.2 s near a player after a 1 s static ring (20 dmg + knockdown within 6 studs, 40 to creatures); anyone carrying Scrap is a lightning rod (55% of bolts aim straight at them, ring glows red, the scrap hums); every 18-26 s a barrage: the cloud lights up for 2.5 s then 6-9 bolts ring every player; 4% of bolts hit the lighthouse (-4 fuel); lamp burns 3x, 10% fewer creatures; a towering anvil supercell (700 studs across) over the island flickering with internal lightning, dark blue-violet sky, driving rain | Thunderhead model (ReplicatedStorage.StormAssets) (+ Lucky Lightning spark, Golden Rain drop/mote) |
| High Tide | Moderate | the sea rises up to 6.5 studs over 30 s (Workspace attribute FloodLevel), flooding the beaches and low ground (about a quarter of the island) and draining over 12 s after the storm; wading slows you by up to 40% and the current drags you seaward at 2.5 studs/s; every 6-10 s a Drowned rises out of the flood 12-28 studs from a player standing in it; lamp burns 3x, 10% fewer creatures; heaving grey-green sea, heavy rain, glassy foam-streaked flood sheet, splashes and rings around your legs, murky blur when your head goes under, dark boiling burst where a Drowned comes up | (Bountiful Tide foam, Golden Rain drop/splash/ripple, Drizzle bubble) |
| Silent Fog | Moderate | every 6-10 s, for each player outside the lamp light (max 2 each), a pair of eyes opens in the fog 24-34 studs away (sent only to that player); look straight at them (client sends StormAct "WatcherSeen", server checks it is that player's own watcher) and they sink away; ignore them for 7 s and a Fog Crawler lunges out of that spot; lamp burns 3x, 20% fewer creatures; pale, windless, smothering fog at every height, desaturated, a heartbeat vignette that thumps faster as an unseen watcher gets ready to lunge, eyes flare red when they do | vignette (+ Drizzle haze, Aurora wisp) |
| Freezing Rain | Moderate | out in the open (nothing overhead, outside the lamp light) players chill over 35 s (player attribute "Chill"), and once chilled through take 2 damage a second until they get under cover or into the light (warm again in 8 s); every 18-26 s the lamp ices over (Workspace "LampIced") and burns 1 extra fuel a second until someone holds the "Chip the ice off" prompt on the lamp; lamp burns 3x, 10% fewer creatures; blue-grey sleet with ice pellets, glittering glaze on the ground, slippery footing outdoors (momentum lags, you skid), frost creeping over the screen, steaming breath and shivering camera as you chill, a jagged icicle crust grows over the lamp and shatters when chipped | IceCrust model (Blender) + Hailstorm pellet/frost, Fish Rain glint, Rolling Thunder smoke, Golden Rain drop |
| Sandstorm Surge | Moderate | a steady wind (Workspace "WindDir"); standing on sand costs 3 health a second; every 24-34 s (first after 8 s) a surge (StormEvent "SandSurge") starts 800 studs out within 35° of the wind and crosses the island at 55-70 studs/s: anyone out in the open when it passes takes 12 damage and is bowled over (StormEvent "SurgeHit"); passing the lighthouse costs 4 lamp fuel; once it has crossed, 2-3 scrap or oil items are uncovered on the beaches (attribute "Unearthed"); lamp burns 3x, 20% fewer creatures | ochre sky, sand streaming low along the ground, streaks, dust drifts; a 380-stud wall of boiling dust (3 parallax layers rolling against each other, billows at its foot) that you can watch racing in; the ground shakes as it closes; inside it everything goes dark brown, blurred and roaring; grit scouring the screen on the beach; glints and a warm light on uncovered items | sand wall, grit (Blender) + Sea Breeze streak, Drizzle haze, Fish Rain glint, Rolling Thunder smoke |
| Ghost Ship | Moderate | a ghost ship circles the island 720 studs out, one lap every 200 s (StormEvent "ShipState"); its searchlight sweeps 48° either side of the island centre, and anyone it catches outside the lamp light with nothing overhead is marked (StormEvent "Marked"); getting into the light clears the mark; every 15-22 s its bell tolls (StormEvent "ShipBell"): 2 Fog Crawlers rise right behind each marked player and 2 wade ashore on the beach nearest the ship (StormEvent "CrewRise"); every 38-52 s it dissolves and reappears elsewhere, 40% of the time just 610 studs out (StormEvent "ShipBlink"); lamp burns 3x, 40% fewer creatures | still green night, low ghost-mist and glowing motes; a glowing see-through three-master with tattered sails (Blender), rolling on an invisible swell in green mist, traced in ghost-light beams so it reads from far off, with a stern lantern throwing a sweeping searchlight; a pounding green vignette when marked; the bell sends a ring of green light racing across the sea and every light shudders; green pillars of fire where the crew rise; mist bursts when the ship blinks | GhostShip model + bell ring (Blender) + Aurora wisp, Drizzle haze, Silent Fog vignette, Lucky Lightning glow |
| Wild Swarm | Moderate | the tree animals are frenzied (TreeAnimalService.SetFrenzy): snakes, spiders and bats drop every 5-9 s instead of 25-50 s, from trees up to 45 studs away; every 16-24 s (first after 6 s) a bat swarm (StormEvent "BatSwarm") erupts from a random pine and flies 900 studs at 48-60 studs/s, roughly toward the lighthouse: anyone within 34 studs of it out in the open takes 10 damage and is mobbed (StormEvent "BatsHit"); passing over the lighthouse costs 4 lamp fuel (StormEvent "BatsLamp"); lamp burns 3x, 30% fewer creatures | blood-red dusk, falling leaves, the pine canopies near you thrash in bursts as if something is moving through them, pairs of glowing eyes open, blink and vanish in the branches; flapping bat flipbook swarms streaming over the canopy; bats in your face, a red vignette and shaking when mobbed; a whirl of wings around the lamp | bat flipbook, eyes (Blender) + Sea Breeze leaf, Drizzle haze, Silent Fog vignette |
| Red Tide | Severe | the sea burns: swimming or wading costs 7 health a second and stains you (player attribute "Stained": 3 a second for 5 s after you get out); every 12-18 s two Drowned climb out at the water's edge nearest each player within 200 studs of the shore (StormEvent "DrownedRise"); every 14-22 s (first after 8 s) the tide surges at the shore nearest a player (75%) or anywhere (StormEvent "RedSurge"): 2.2 s of swelling, then a wave runs 55 studs up an 80-stud stretch of beach, 14 damage and stained if it catches you; lamp burns 3.3x | a glossy blood-red sea with swirling bloom and low red mist, a crimson sky, the lighthouse beam turned red; red flood, bubbling algae and a pulsing red vignette while you burn; the sea boils red where the surge gathers and where the Drowned come up; a red wedge of a wave sliding up the sand with froth | algae (Blender) + Drizzle haze, Bountiful Tide foam, Silent Fog vignette |
| Hurricane | Severe | the wind (Workspace "WindDir" / "WindStrength") swings 4° a second round the compass and leans hard on anyone in the open; debris is flung at exposed players every 3-5.5 s (StormEvent "Debris", 13 damage and knocked down if still where it was aimed); 42% of the way through, the eye arrives ("HurricaneEyeAt" / "HurricaneEyeEnd" / "HurricaneTrack"): the wind dies and the rain stops for 14-22 s (at most 18% of the storm); then the back wall hits with the wind reversed and 30% stronger (StormEvent "BackWall"): 12 damage and thrown down if exposed, 6 lamp fuel; lamp burns 3.6x, 40% fewer creatures | rain driven flat and swinging with the wind, spray streaks, low scud, leaves; overhead a vast turning cloud spiral (Blender) whose eye tracks in over the island; in the eye a towering ring of streaming cloud with blue sky and sun shafts above, warm and quiet; the back wall slams in grey with a burst of rain and heavy shaking | spiral (Blender) + Golden Rain drop, Sea Breeze streak/leaf, Drizzle haze, Squall sheet |
| Blackout Storm | Severe | 4 s in, lightning strikes the lamp (StormEvent "LampStrike"): the safe circle shrinks to 30% (LightService.SetRadiusScale, Workspace "Blackout") without touching the fuel, until someone holds "Relight the lamp" (3 s) on the lamp (StormEvent "Relit"); 30-45 s after each relight it strikes again; up to 3 ball lightning orbs (Workspace.Runtime.BallLightning, a new one every 5-9 s, 150-260 studs out) drift at 9 studs/s towards the nearest player outside the light, burst if they reach the light or after 30 s, and zap anyone they touch for 16 (StormEvent "Zapped"); lamp burns 3.3x | a dry violet night, sheet lightning flickering the whole island with distant bolts, static sparks in the air and St Elmo's fire on the lantern gallery; a blinding bolt into the lantern with sparks and glass; the beam dies to an occasional cough and the night darkens while choked; crackling blue-white plasma orbs (Blender) that light the ground and spit little arcs; a white-out, bolt and stumble when zapped | plasma (Blender) + Lucky Lightning spark/glow |
| Ember Storm | Severe | a hot wind (Workspace "WindDir"); every 9-15 s (first after 5 s) dry lightning sets a pine alight (StormEvent "TreeStrike", tree attribute "Burning"), preferring trees near players and never within 30 studs of the lighthouse; every 3.5 s each burning tree has a 35% chance to light its best neighbour within 32 studs, mostly downwind (max 14 burning); standing within 11 studs of one costs 4 health a second (player attribute "Scorched"); hold "Beat out the fire" (2.5 s) on the trunk to put it out (StormEvent "FireOut"); after 28 s it burns down (felled, regrows later) and drops wood (StormEvent "BurntDown"); every 5-9 s sparks land as a 6-stud spot fire near players out of the light (StormEvent "Embers", 5 a second for 7 s); lamp burns 3.3x, 20% fewer creatures | a smoky orange sky, embers (Blender) and ash streaming on the wind, a high smoke haze; burning trees roar with flame off the whole canopy, pour black smoke, throw sparks downwind and light the ground, their needles charring black; steam puffs when beaten out, ash bursts when they fall; spot fires with falling embers; an orange swimming vignette and heat blur when scorched | ember (Blender) + Rolling Thunder flame/smoke, Drizzle haze, Silent Fog vignette |
| Whiteout | Severe | out in the open (nothing overhead, outside the lamp light) players chill over 22 s (player attribute "Chill"; warm again in 6 s) and then take 3 a second; every 20-30 s (first after 10 s) the snow closes in for 7 s (Workspace "WhiteoutUntil"), and for every player outside the light a line of clawed tracks walks in from 45 studs away (StormEvent "Tracks", a print every 0.32 s) and a Fog Crawler steps out where they stop, 6 studs short; lamp burns 3.4x, 30% fewer creatures | a blizzard: snow (Blender) driving sideways, close flurries, drift streaming along the ground; the island's grass, sand, earth and rock turn white for the storm and melt back after; frost over the screen, steaming breath and shivering as you chill; the world goes white to arm's length when it closes in; clawed footprints (Blender) pressing into the snow one by one with little puffs, walking straight at you | snowflake, footprint (Blender) + Hailstorm frost, Rolling Thunder smoke, Drizzle haze |
| Maelstrom | Catastrophic | a whirlpool opens 1250 studs offshore in a random direction and creeps in to 820 over 70 s (Workspace "MaelstromAt", "MaelstromRadius" 420); inside its reach each client is dragged round and in (gently on land, hard in the water) and the throat (45 studs) does 30 a second; every 8-13 s it lashes a player outside the light within 600 studs (StormEvent "Lash", 1.4 s warning, 18 damage and flung towards it); lamp burns 3.8x (+1.5 fuel/s once it is closest), 20% fewer creatures | the sea is cut away on the client (terrain carve that follows it, restored after) and a dark glass funnel (Blender) turns down to a black throat breathing mist; a huge foam whirl (Blender) wheels round its lip with spray boiling off the rim; planks and logs ride the walls down and vanish; a foam ring boils under the target, then a column of sea (Blender) bursts out of the ground with a screen shake; a deep-water vignette while it has hold of you | funnel mesh, whirl, column (Blender) + Bountiful Tide foam, Fish Rain spray, Drizzle haze, Silent Fog vignette |
| Waterspout | Catastrophic | every 11-17 s (first after 4 s) a spout drops 950 studs out (up to 3 at once) and weaves in across the island at 15-22 studs/s (StormEvent "Spouts" every 0.5 s); anyone beside one (16 studs) with no roof overhead is snatched up and flung out (StormEvent "SpoutGrab", 15 + 10 damage, 7 s grace); one that passes a player within 160 studs may turn and come for them (45%); crossing the lighthouse costs 8 lamp fuel; over land each drops up to 5 Fish items; lamp burns 3.6x, 30% fewer creatures | a green-black squall with driving rain; each spout is a twisting column (Blender funnel + wall streaks, inner core spinning the other way) that drops down out of a churning wall cloud, leans as it moves, and wobbles; a skirt of spray at its foot (leaves and dirt once ashore), wreckage whirling up it, fish glinting; spray across the screen and trembling when one is close; whirled up the column and thrown out when grabbed | funnel mesh, wall (Blender) + Hurricane drop/leaf, Fish Rain splash/spray/glint, Drizzle haze, Rolling Thunder smoke |
| Eclipse Storm | Catastrophic | the moon starts crossing the sun 6 s in (Workspace "EclipseContact" / "EclipseTotal" / "EclipseTotalEnd" / "EclipseClear", server times); totality runs from 30% to 80% of the storm: the lamp gutters to 72% radius, Fog Crawlers rise 40 studs from anyone outside the light every 6-9 s, and everyone outside the light grows a shadow that rises where they were 2.5 s ago and walks their trail at 13 studs/s (walking is 16, carrying 12; StormEvent "Shadows"), draining 12 a second when it reaches them; the light burns it away (StormEvent "ShadowBurn", 6 s before another); the diamond ring burns them all (StormEvent "DiamondRing"); lamp burns 3.5x, 10% more creatures | a clear afternoon; a black moon slides over a billboard sun (the real sun hidden) and the light thins; at totality night slams down: the corona (Blender) blazes round the black disc, stars come out, the horizon glows sunset-orange all the way round, and red and yellow eyes open in the dark; the shadow is a black clone of the player with a red outline and red eyes, copying their moves from a moment ago, trailing black wisps, and bursts into embers in the light; the edges of the screen pulse black as it closes in; a blinding white flash for the diamond ring | corona, sun (Blender) + Wild Swarm eyes, Fish Rain glint, Rolling Thunder smoke, Ember Storm ember, Silent Fog vignette |
| The Deluge | Catastrophic | a flood (Workspace "DelugeLevel") climbs in surges every 7-11 s (StormEvent "DelugeSurge") to 25 studs by 72% of the storm, over the whole island and the lighthouse ground floor, then drains from 86%; heads under water lose breath over 12 s (player attribute "Breath"), then drown at 10 a second; every 9-14 s something drags a swimmer outside the light under for 2.6 s (StormEvent "Undertow", 7 a second); Drowned rise 28 studs from swimmers every 8-12 s; lamp burns 3.7x, 20% fewer creatures | a grey wall of rain with falling veils; the flood is a murky churning sheet (Blender) with foam streaming out to sea, pocked by rain, carrying planks, barrels, crates and logs; you float at the surface (buoyed on the client) and the current pulls you out at 3 studs/s, wading at 11; under it the screen goes green-brown and blurred, bubbles stream off you and a row of bubbles shows your breath; the undertow boils the water and drags you down into the dark | flood water (Blender) + Hurricane drop/streak, Golden Rain ripple/splash, Drizzle bubble, Silent Fog vignette |
| Cursed Storm | Catastrophic | an eye opens in the sky (Workspace "CursedEye") and every 11-15 s (first after 6 s) a new curse falls, shuffled so none repeats back to back (StormEvent "Curse"): Hands (8 s: standing still outside the light for 1.5 s costs 9 a second, StormEvent "Grabbed"), Float (gravity 26 for 7 s), Choke (lamp radius 40% for 9 s), Doubles (2 Fog Mimics beside each player in the open), Keeper (once a storm: the Last Keeper comes ashore), Gaze (the eye fixes on one player for 7 s; still in the open with nothing overhead and they take 25 and 3 Fog Crawlers come; StormEvent "GazeHit"); lamp burns 3.8x, 20% more creatures | a bruised violet-green dusk; a vast turning sigil (Blender) over the island, ash drifting up, green lightning with no thunder; a giant eye (Blender sclera, slit iris and lid) hangs over the sea, blinks, and its pupil follows you; each curse is announced in dripping letters; black clawed hands (Blender) claw out of the ground around you, slowing you and blacking the edges when they catch you; leaves lift off the ground as gravity fails; the lamp beam turns sickly green; the gaze is a green shaft of light that pins its victim and narrows as it closes | sclera, iris, lid, hand, sigil (Blender) + Ember Storm ember, Hurricane leaf, Silent Fog vignette |

## UI art (ForgeGUI)
- Navy-driftwood-and-brass UI pieces generated on forgegui.com, cut out and cleaned by
  `tools/forge_cutout.py` (watermark corner mirrored, stray green tinted navy), uploaded as
  decals. Sources in `assets/ui/`, image ids and 9-slice rects in `Config.UI`.
- `UISkin` (client) applies them: `UISkin.panel(frame)` hangs a 9-sliced brass frame around
  a panel, `UISkin.bar(back, fill)` puts a bar's fill inside the brass slot (callers keep
  setting `fill.Size`), `UISkin.imageButton(id)`.
- Used on: the storm, lamp and storage panels and every HUD bar (tinted by storm phase),
  the stamina bar, the minimap's porthole ring, the big map's frame / title plaque / brass X,
  the intro's name plate title and parchment caption scroll.

## Flowing storms (shared upgrade)
- `StormFX/Common`: eased (smoothstep) fade in/out over 8 s; a gusting wind (`ctx.gust`,
  `Common.gustAt`) sways all falling and floating particles; clouds and colour grade follow the
  same ramp; lightning (`Common.boltSegment`) is soft camera-facing beams instead of neon blocks
  (Thunderhead, Rolling Thunder, Lucky Lightning, Blackout, Ember). Soft textures in `assets/fx`
  (`Common.TEX`).
- `StormFXController`: the storm's look starts rolling in during the Warning (30%) and is rebuilt
  at full strength when the storm begins; fades out at dawn.
- `WeatherController`: plain rain uses streaks, eases in/out, sways; the wave shake is smooth noise.
- `FogController`: the clock only runs forward, so dawn rolls through the night instead of jumping;
  longer phase blends (`Config.LookTweenSeconds`).
- `StormReactionController` (new): characters lean into the wind, hunch in storms, shiver and
  hug themselves in the cold, cover their heads under hail and flinch at nearby lightning. It
  adds to `Transform` after the Animator (works with Motor6D and AnimationConstraint joints).
- Creatures fade in out of a puff of fog and dissolve into fog when they die; animation
  cross-fades are longer and eased.

## UI art, batch 2 (ForgeGUI)
- `assets/ui2`: item icons (wood, scrap, oil, fish, whale oil, lamp), a button with hover and
  pressed looks, round / key-cap / pill buttons, three banners (plain, warning, good news), five
  storm-severity badges and the victory / defeat emblems. Cut out by `tools/forge_cutout2.py`
  (removes baked-in checkerboards, tints stray magenta to amber). Ids in `Config.UI`.
- Used for: storage icons + counts, the carried item's icon, skinned HUD and intro buttons
  (`UISkin.button`), message toasts and the alarm banner on banners (`UISkin.banner`), the
  storm's severity badge on the storm panel, and the emblem on the won / lost screens.

## Backpack

Everything you gather goes into a backpack you wear (a leather pack model on your back).

- Holds 20 items (`Config.Resources.BackpackSize`). The fuller it is, the slower you walk (down to `CarryWalkSpeed` when full).
- Every item you get pops out as a tiny 3D piece, arcs onto your back, and a "+1" with the item's icon pops up by the backpack button.
- **B** (or ButtonY) opens the backpack window: a fullness bar and one cell per item. Click a cell to drop one.
- **Storage chest A: "Empty backpack"** stores all wood, scrap, oil and fish in one go. Raw fish (cook it first) and whale oil (straight into the lamp) stay in the pack.
- **Storage chest B: "Take fuel"** takes up to 5 (`TakeFuel`) at a time: oil first, then wood.
- **Lamp: "Pour fuel"** pours whale oil, then oil (wood only if you carry no oil) until the tank is full.
- **Fireplace: "Cook fish"** cooks every raw fish you carry. "Eat fish" eats from the pack first, then storage.
- Dying or leaving spills the whole pack on the ground.
- Server-owned contents; clients see them as `Pack_<Kind>`, `PackTotal`, `PackSize` attributes and the `Gained` remote.
- Icons (ForgeGUI, batch 3) are in `assets/ui3`.

Testing note: Studio's execute_luau runs in its own script VM, so `require(ResourceService)` there gets a separate copy. Test through real gameplay (fire the `Punch` remote, trigger prompts from the client) instead.

## Tool models (Blender)

The Harpoon, Hammer and Flare gun are modelled in Blender
(`~/the-last-lighthouse-assets/tools3d/LastLighthouse_Tools.blend`, FBX exports in `assets/tools3d`).
Each tool is a few MeshParts named `<Tool>_<Role>`, modelled with the tip along +Z and the hand grip at the origin.
They live in `ServerStorage.ToolModels.<Tool>`, and `CombatService` builds the tools from them:

- `LOOKS` gives each role its Roblox material and colour: Wood, Metal, Rope and Leather (Fabric), Plastic, Grip, Dark.
- `HOLD` sets each tool's scale, grip point and roll. The hammer head is turned upright, face down.
- If a model is missing, the old block tool is used instead.
- The client preloads the meshes on spawn so nothing pops in on the first equip.

| Tool | Model asset |
|---|---|
| Harpoon (ash shaft, rope grips, barbed leaf head) | 116672645311335 |
| Hammer (claw hammer, leather-wrapped grip) | 138355564212074 |
| Flare gun (orange flare pistol) | 113042351024430 |

## Harbor lobby and parties (up to 4)

Players now load into a **harbor at dusk** (`Workspace.Lobby`, built by `tools/BuildLobby.luau` at x≈3200, far from the island).
One place, two modes (`Shared/GameMode`):

| Server | Mode | What runs |
|---|---|---|
| Public server | Lobby | `Server/LobbyService` + `Client/LobbyController` only. The island (`Map`) is parked in `ServerStorage.Parked`. |
| Reserved server (one per party) | Game | Everything as before. `Lobby` is parked. |
| Studio | Lobby, then Game | A boat casting off switches this server into the game, because teleports don't work in Studio. Set Workspace attribute `ForceMode = "Game"` (or `"Lobby"`) to skip straight to one. |

**Parties.** Four rowboats are moored at the dock.
- Step onto an empty boat and you **create its party**: a picker asks for Solo, 2, 3 or 4 sailors (`ChooseParty` remote). While you choose, the boat is reserved, and anyone else is put back on the dock with "(name) is setting up this boat".
- Then up to that many can board. Each boat's sign shows "Party of 3 · 2/3 aboard · Room for 1 more!" with one lamp per seat.
- When the party is full, a `FullCountdown` (5s) starts. If someone steps off, it stops.
- The leader can change the size ("Party size" button), but not below how many are aboard. If the leader steps off, the next one aboard leads. An empty boat resets to free.
- Then the boat casts off: the party is seated and the boat rows out to sea with them in it, and their screens fade. The server reserves a private server and teleports the party together (`TeleportData = { party, boat }`).
- If the teleport fails, everyone is put back on the dock.
- On the party's server, when the run ends (won or lost), `StormDirector.OnRunEnded` sends everyone back to the harbor after `ReturnDelay`.

**Harbor life (all client-side in `LobbyController`).**
- The sky and sea: sunset over the sea past the end of the dock, with a custom atmosphere, bloom, sun rays and darker, reflective water.
- Things on the water: boats rocking at their moorings, buoys bobbing with blinking lights, fish leaping out of the water with splashes.
- Lights and props: lanterns swinging and flickering, the ship's bell swaying.
- Gulls circling, flapping and gliding.
- The distant lighthouse beam sweeping.
- Chimney smoke, fireflies, sea mist, splashes at the pilings, a campfire with embers.
- Grass that sways in the wind, plus trees from `TreeLibrary`.
- Sounds: waves and distant gulls.
- Each boat has a sign showing who's aboard and the countdown.

Testing teleports needs the published game (2+ accounts, or one account to try a solo boat).

## Flare shot and upright hammer
- **Flare gun:** `Client/FlareController` runs the whole shot, and every client sees it (`FlareFired(at, shooter)`).
  1. The gun raises and kicks back (recoil on the hand grip), with a muzzle flash, smoke, sparks and a camera shake for the shooter.
  2. A red round climbs steeply, trailing smoke.
  3. It pops, a parachute opens, and the flare burns red for 12s, swinging and drifting down while lighting the ground (with shadows).
- **Hammer:** now held upright, head on top with the striking face forward (`CombatService` `HOLD.Hammer.pitch = 90`).

## Party intro cutscene and the wave
- **Everyone's in it, in sync.**
  - `IntroService` waits for the whole party to arrive (the harbor's `TeleportData.party` says how many, 20s at most), waits for avatars to load, then publishes `ReplicatedStorage.IntroCast` (user ids, sorted) and `IntroStartAt` (server time, +2.5s).
  - Every client plays the same film from that moment, with the same seed: same boat rocking, same lightning, same fling directions.
  - Until then the screen says "Waiting for your crew...". Someone who isn't in the cast (a late joiner) gets a solo film.
- **In the boat:** all 2–4 party members sit on their own bench, rowing slightly out of step, then bracing. All of them go over the side when the wave flips the boat.
- **On the beach:** they wash up side by side, 4.2 studs apart across the beach, and stir one after another. Each client's camera follows its own player. After the film, `IntroService` puts each real character exactly where their actor lay.
- Characters are streamed to every client (`ModelStreamingMode.Persistent`) so the film can clone them.
- **The wave** is a skinned mesh animated in Blender (`assets/wave/LastLighthouse_Wave.blend`).
  - Rig: 4 bone chains across a 400-stud sheet, 11 bones each from the back foot over the crest and lip to the front foot. The "Break" action (4 s) goes swell → steep face → pitching lip → barrel → collapse, each chain slightly out of phase so the break peels along the wave.
  - Model asset 94908490924561 → `ReplicatedStorage.IntroAssets.Wave` (MeshPart `Body`, DoubleSided, SurfaceAppearance colour 91213604711302 / normal 94514185979467 / roughness 117317891259615; UVs tile 4× across).
  - Bone paths: `Shared/WaveAnimData` (sampled at 10 fps from Blender, Catmull-Rom in between). `Client/IntroWaveMesh` moves each bone along its path and turns it with the surface slope every frame. The wave rolls toward the boat at 24 studs/s, so the lip lands on it at the flip.
  - Spray tears off the lip bones as it pitches, and whitewater blows out of the foot as it collapses.
  - The old strip-built wave (`Client/IntroWave`) is the fallback if the asset is missing.

## Crafting table
- **Where:** a heavy plank workbench on the lighthouse ground floor, against the east wall under the window. It has a vise holding a half-made harpoon head, a lantern, a saw, a mallet, a plane, scrap plates and nails, plus rope, scrap and a keg on the shelf. Built by `tools/BuildCraftingTable.luau` as `Map.Lighthouse.GroundFloor.CraftingTable`.
- **How:** walk up and press the "Craft" prompt to open the crafting window (`Client/CraftingController`).
  - Recipe cards show their cost in green or red against the crew's storage.
  - The window works with touch, mouse and gamepad, scales down on phones, and closes with X, Esc, B or walking away.
  - The server (`Server/CraftingService`) checks the distance, prerequisites and storage again, then spends the materials.
- **Recipes** (`Config.Crafting`, materials from the shared storage, everything lasts for the run):

  | Recipe | For | Cost | Effect |
  |---|---|---|---|
  | Barbed Harpoon | you | 3 wood, 1 scrap | harpoon 25 → 38 damage, dark steel head (affordable in the first minute) |
  | Whaler's Harpoon | you | 6 scrap, 1 oil (after Barbed) | 50 damage, +6 range, shiny brass head |
  | Iron Hammer | you | 3 scrap, 1 wood | repairs ×2 per swing |
  | Flare Bandolier | you | 2 oil, 2 scrap | flare reload 40s → 25s, brass-trimmed gun |
  | Polished Lens | whole crew | 6 scrap, 3 oil | light radius 55 → 70 |
  | Great Fresnel Lens | whole crew | 12 scrap, 6 oil, 4 wood (after Polished) | light radius 85 |

- **Everyone sees it:** upgraded tools are tinted (`CombatService.Dress`), and crafting announces "X crafted a Whaler's Harpoon!" to the whole server.
- Personal upgrades are player attributes (`HarpoonTier`, `HammerTier`, `FlareTier`). Crew upgrades are in `State.Crafting`. Everything resets with `StormDirector.RunReset`.

## Core loop: play → earn → upgrade → unlock → flex → repeat
Persistent progress that brings players back (`Server/KeeperService`, `Client/KeeperController`, `Config.Keeper`, saved by `DataService`, profile version 2).

- **Earn Brass** on game servers. Brass is paid the moment it's earned and autosaved, so quitting mid-run loses nothing.

  | Action | Brass |
  |---|---|
  | Surviving storm *n* | 15 + 2n |
  | Each creature your harpoon finishes | 4 |
  | Each repair swing | 1 (max 40 per run) |
  | Each craft | 5 |
  | Winning the run | 250 |
  | First storm survived each day | +50 daily bonus |

- **Upgrade (perks that stay):**
  - Thick Oilskin Coat: +15 max health per tier, 3 tiers.
  - Deep Pockets: +3 backpack space per tier, 3 tiers.
  - Ship's Stores: +2 wood and +1 scrap to crew storage at each run start, per tier, 2 tiers.
  - Old Salt: +10% Brass per tier, 3 tiers.
- **Unlock and flex:**
  - **Lanterns:** glowing belt lanterns that everyone sees in the dark: Ship's 100, Sea-Glass 450, Storm-Violet 1000, Gilded (sparks) 2500.
  - **Titles:** shown on a nameplate with your Keeper level.
    - Bought: Lamplighter 150, Keeper of the Light 3000.
    - Earned only: Deckhand at level 3, Storm Chaser at storm 10, Wave Breaker for a won run.
  - Buying a lantern or title is announced to the whole server.
- **Where:** the HUD's Brass counter and **Locker** button work anywhere. In the harbor there's also the Keeper's Locker stall beside the path to the dock (`tools/BuildKeepersLocker.luau`): a striped awning, the four lanterns lit on a shelf, a coat, and a chest of brass.
- **How it fits together:**
  - `Server/Rewards` lets gameplay services report kills, repairs and crafts without a require loop.
  - `StormDirector.RunFinished` reports wins.
  - DataService and KeeperService now run on lobby servers too.
- **Studio testing:** set the workspace attribute `KeeperGiveBrass` to a number to pay everyone (Studio only).

## Visual pass: type, props, polish
- **Typography (`Client/Typography`)** gives every screen one type system:
  - Merriweather Heavy (a nautical serif) for headings and big numbers.
  - Builder Sans Bold for buttons and labels, Builder Sans Medium for body text.
  - It maps the old Gotham/FredokaOne text as it appears, in menus and on in-world signs and nameplates.
- **Brass coin** icon (`assets/ui/BrassCoin.png`, decal 73592926731933): a lighthouse stamped in brass, replacing the old "B" circle.
- **Ship lantern** (`assets/props/ShipLantern.fbx`, asset 89765255194301, template `ReplicatedStorage.Assets.ShipLantern`) is a brass lantern modelled in Blender with a glass globe, wire cage and flame. It replaced every blocky lantern:
  - the dock and path posts (they still swing and flicker)
  - the four boats
  - the Keeper's Locker shelf (one colour each) and its hanging lanterns
  - the crafting table
  - the island's Old Dock and floor-3 lanterns
  - the belt lanterns
- **Ship bell** (`assets/props/ShipBell.fbx`, asset 113361678155578) replaced the orange blob in the harbour's bell frame.
- **Swapping it all in:** `tools/PropsPass.luau` does all of the swaps after the builders.
- **Keeper's Locker stall:** the awning now slopes the right way, and the sign hangs under it on chains.
- **Windows:** the crafting and Locker windows dim the world behind them, and the Locker's open tab is highlighted.
- **Nameplates** are smaller and hidden from their own player.
- **Fixes:**
  - Players no longer get a second set of tools.
  - The intro's wave stays hidden until it rises.
