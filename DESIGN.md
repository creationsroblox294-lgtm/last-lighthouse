The Last Lighthouse — Game Design Doc
Nov 25, 2026 · @Roblox Creations
Overview
The Last Lighthouse is a co-op survival game where 1–8 players keep an old lighthouse lit on a tiny island through 100 storms. Something lives in the fog, and it hates light.
• Hook (game description): "No keeper has ever seen the 100th storm. Keep the light burning."
• Genre: co-op survival with light-based base defense
• Players: 1–8 per server; solo is possible but hard
• Session: one run lasts as long as you survive; a full 100-storm run is about 4–5 hours across several sessions (saved per server owner)
• Platform: Roblox on PC, mobile and console, so controls must work with touch
• Why it's different: in most survival games you leave the base to explore. Here the base is a single tower, and the light it gives off is your only safe zone. Everything comes back to one question: is the lamp still burning?
Core loop
Each storm is one cycle of about 6 minutes: calm, storm, dawn. Survive 100 cycles to win.
1.  Calm (about 3 min): the sky clears and the fog pulls back. Players gather wood, scrap and oil, fish, loot wreckage that washed ashore, and repair storm damage.
2.  Warning (30 sec): a bell rings, the fog horn sounds and the fog starts rolling in. Everyone hurries back toward the light.
3.  Storm (about 2–3 min): the lamp burns fuel fast. Waves hit the walls, lightning strikes, and fog creatures attack wherever the light doesn't reach.
4.  Dawn (20 sec): the storm counter goes up by one. New wreckage drifts ashore, and sometimes a supply crate or a passing ship drops rewards.
Every 10th storm is a Great Storm with a boss. That gives the run clear checkpoints and gives players a reason to say "one more."
The loop repeats until the tower falls or the group gets through storm 100.
The light
The lamp is the heart of the game. While it burns, there's a safe circle around the tower. When the fuel runs out, the circle disappears.
• Fuel: the lamp has a fuel gauge. Driftwood burns fast and weak, oil is the main fuel, and rare whale oil burns longest. During storms, fuel drains about 3× faster.
• Safe circle: fog creatures take damage and back off inside the lit radius. The radius depends on the lens tier and shrinks as fuel gets low, so the danger is easy to see.
• The beam: a rotating beam sweeps out past the safe circle. Creatures it hits get stunned and burned. One player can climb to the lamp room and aim the beam by hand to hit a specific threat (this is the most fun job in the game).
• Lanterns: each player carries a small lantern with its own fuel. A lantern only protects you, and wind gusts can blow it out.
• Lights out: if the lamp goes dark, a 15-second alarm plays before the creatures swarm. Players can refuel and relight it in time. The run ends if the lighthouse is destroyed or everyone is lost.
• Upgrades: better lens tiers (bigger radius), a faster beam, a bigger fuel tank, outer lamp posts that push the safe zone outward, and a late-game generator as backup power.
The island and map
The map is one small island of about 300 × 300 studs, with a few rocky islets you can reach by rowboat later in the run. Keeping it small helps performance and keeps players close to the light.
Area
What's there
When it opens
Lighthouse cliff
The tower, the crafting bench and the fuel tank
Start
Wreck Beach
Wreckage washes up here after every storm, and the Drowned climb out of the water here
Start
Pine grove
Wood, rope plants and a few hidden chests
Start
Tide pools
Fish, crabs and shells
Start
Old dock
Fishing spot and the place to build the rowboat
Storm 5
Shipwreck islet
A sunken ship holding scrap, glass and whale oil
Storm 15 (needs the rowboat)
Keeper's hut islet
The previous keeper's journal pages (lore) and rare upgrades
Storm 40
The fog wall at the edge of the map creeps a little closer every 10 storms, so the island feels smaller as the run goes on.
Resources and crafting
The game has six main resources plus one rare one, gathered during the calm and crafted at the bench in the base of the tower.
Resource
Where you get it
Used for
Wood
Pine grove, driftwood on the beach
Repairs, barricades, quick lamp fuel
Scrap metal
Wreckage, shipwreck islet
Tools, lamp post frames, spike walls
Oil
Barrels in wreckage, supply crates
The main lamp fuel, lantern refills
Fish
Tide pools, the dock
Food (restores health and stamina)
Rope and cloth
Pine grove, wreckage
Rowboat, sails, bandages
Glass
Shipwreck islet, rare wreckage
Lens upgrades, lamp posts
Whale oil (rare)
Shipwreck islet, boss drops
Long-burning fuel for the hardest storms
Tools: axe, hammer (repairs), fishing rod, harpoon (the main weapon), lantern, flare gun (a short burst of light that saves a teammate stuck out in the dark).
Items are physical objects you carry, so moving fuel up the tower is real work. That gives the group simple jobs to divide up.
Building and repairing
The lighthouse is your base. It has three floors, and each floor has its own health bar.
Floor
Job
If it breaks
Ground floor
Storage, crafting bench, the door
Creatures get inside and go for the stairs
Bunk room
Respawn point and food storage
No respawning until it's repaired
Lamp room
The lamp and fuel tank
Fuel leaks and the light flickers
What you can build outside: barricades, spike walls, outer lamp posts (each one burns fuel and adds a small safe circle), rain barrels, a lightning rod (otherwise lightning hits the lamp), and a sea wall that cuts wave damage.
Repairs use a hammer plus wood or scrap. Damaged walls crack visibly and windows shatter, so players can tell at a glance where to go.
Enemies: the fog creatures
Each creature tests the light in a different way, so players can't win just by keeping the lamp full.
Creature
First appears
Behavior
How light affects it
Fog Crawlers
Storm 1
Fast swarms that circle the edge of the light, waiting for it to shrink
Burned and driven off
The Drowned
Storm 8
Slow and tough; they climb out at Wreck Beach and pound on the walls
Slowed, but they keep coming
Night Gulls
Storm 15
Flying; they dive at lanterns and steal items you're carrying
Stunned by the beam
Fog Mimics
Storm 30
Copy a teammate's voice line or lantern glow to lure players into the dark
Their disguise breaks in the light
Tide Caller (boss)
Every 10th storm
Rises out of the sea and sends waves to put the lamp out
Only weakened; the beam has to hit its eyes
The Last Keeper (final boss)
Storm 100
The lore twist: the old keeper, changed by the fog
Revealed at the end of the run
Creatures spawn at the edge of the fog and only attack where the light doesn't reach, so one rule teaches the player everything: stay in the light.
The Hollow: the one that stays
The Hollow is different from every other enemy. It shows up after storm 12, moves onto the island for good, and can appear at any moment, including during the calm. It turns the safe daytime into something players watch over their shoulders.
• Arrival: after the storm 12 dawn, players find huge tracks leading from the beach into the pine grove. From then on it lives on the island.
• Where it hides: the grove, under the dock, the shipwreck hull, and a cave it digs on the cliff side. Each appearance picks a random lair and a random time (roughly every 4–8 minutes, more often later in the run).
• Warning signs: lanterns flicker, the birds and waves go quiet, frost forms on nearby wreckage, and a low hum gets louder as it gets closer. Players who pay attention get about 5 seconds to react.
• Behavior: it hunts players who are alone or far from the tower. It grabs one and drags them toward the fog. Teammates have a few seconds to save them with a flare, a harpoon hit or a lantern thrown at it.
• Light rules: it can't be killed, only driven off. The beam or a flare sends it back to its lair. It can't enter the safe circle while the lamp is above 50% fuel, so a low lamp is doubly dangerous.
• Gets bolder: every 10 storms it gets faster, appears more often, and learns a new trick: storm 30 it can put out the outer lamp posts, storm 60 it can climb the tower's outside wall, storm 90 it can show up during a storm.
• Why it works: it makes splitting up a real risk, gives the calm phase tension, and gives players stories to tell ("it got me at the dock"). In the lore, it's tied to the final boss.
Good design rule for it: always give the player a warning, and never let it take more than one player per appearance, so it feels scary but fair.
Storm progression
The game gets harder in five stages, and each stage adds one new problem instead of just more enemies.
Storms
Stage
What's new
1–10
First Watch
Teaches the basics: Fog Crawlers, refueling, repairs. The first Tide Caller fight at storm 10
11–30
Rising Tide
The Hollow moves onto the island, the Drowned and Night Gulls show up, lightning starts, the rowboat opens up
31–60
Deep Fog
Fog Mimics, lantern-killing wind gusts, fuel gets scarce
61–90
Black Water
Waves can knock players off the cliff, two creature types at once, oil barrels wash up less often
91–100
The Last Light
Every storm is a Great Storm, ending with the final boss at storm 100
Special storms (about 1 in 8, random): Silent Fog (no sound cues), Red Tide (twice as many Drowned), Ghost Ship (a phantom ship that you can board for big loot), Calm Night (a free breather).
Scaling: enemy count scales with the number of players, but fuel drain doesn't. Bigger groups get more hands, not an easier lamp.
Roles, co-op and death
Roles are optional classes you unlock. Each one gives a small bonus without locking anyone out of any job.
Role
Bonus
How to unlock
Keeper
Lamp burns fuel 15% slower while you're in the lamp room
Free
Carpenter
Repairs 30% faster, cheaper barricades
Free
Fisher
Double fish and a chance to catch oil barrels
Reach storm 10
Diver
Swims faster and can loot the sunken ship longer
Reach storm 25
Medic
Revives teammates faster, bandages heal more
Revive 20 teammates
Signalman
Carries 3 flares and can light the outer lamp posts from a distance
Reach storm 50
When you die: you become a Lost Soul, a faint ghost who drifts in the fog. A teammate can bring you back by carrying your dropped lantern to the lamp. Otherwise you respawn in the bunk room at dawn, as long as it isn't broken. Lost Souls can still ping danger for the living, so dead players stay involved.
Solo play: possible, with a Lone Keeper badge for reaching storm 25 alone.
Progression and replay
Two kinds of progress keep players coming back: what happens inside a run, and what they keep between runs.
• Inside a run: storms survived, tower upgrades, lens tier, islets unlocked. All of it resets when the run ends.
• Between runs: Keeper Level (XP from storms survived), role unlocks, lantern and beam-color cosmetics, and the journal pages you've found.
• Badges: Storm 10, 25, 50, 75 and 100. Also Lone Keeper (storm 25 solo), Never Dark (10 storms in a row without the lamp dropping below 25%), Lifeguard (revive 50 teammates), and Full Journal (collect every lore page).
• Lore: the old keeper's journal is scattered across the islands and slowly explains what the fog is, which sets up the final boss. Hiding lore around the map gives players a reason to explore and gives YouTubers a mystery to make theories about.
• Replay: a weekly "Storm Seed" puts every server on the same special-storm schedule, with a leaderboard for how far groups get.
Monetization
Sell looks and convenience, never survival. If paying keeps the lamp lit, the challenge stops meaning anything.
• Cosmetics (main income): lantern skins, beam colors, keeper outfits, boat skins, death-ghost effects
• Private servers: so friend groups can keep a long run going on their own server
• Role early-unlock pass: unlock roles early (free players still earn every role by playing)
• Supporter pack: a one-time purchase with a cosmetic bundle and a name color
• Do not sell: fuel, revives, lens upgrades, or anything else that skips a storm
Premium Payouts also pay you for time Roblox Premium members spend in the game, which suits a game with long sessions like this one.
Tech plan
The server is in charge of everything that matters: fuel, health, spawns and loot. Clients only send requests and handle visuals. Code lives in a Rojo project so Claude Code can edit it.
Module (server)
What it does
StormDirector
Runs the calm → warning → storm → dawn timer, keeps the storm count, picks special storms
LightService
Fuel drain, safe-circle radius, beam rotation, and an "is this spot lit?" check (distance plus a raycast)
EnemyService
Spawns creatures at the fog edge, runs the Hollow's random appearances and lair picks, runs their AI (PathfindingService), applies light damage, caps how many exist at once
ResourceService
Wreckage spawns after each storm, gathering, and carrying items
BuildService
Placing and repairing structures, floor health, validation (no building inside walls)
RunSaveService
Saves the run state so a group can continue later
DataService
Player XP, roles, cosmetics and badges, with session locking and retries
Client side: HUD (fuel gauge, storm counter, teammate status), lantern effects, camera shake, fog visuals (tweening Atmosphere.Density), and touch controls.
Performance targets: no more than 40 creatures at once, StreamingEnabled on, the beam drawn on each client (the server only sends its angle), and no per-frame loops on the server outside StormDirector.
src/
  server/   StormDirector, LightService, EnemyService, ResourceService, BuildService, RunSaveService, DataService
  client/   HUDController, LanternController, FogController, InputController
  shared/   Config (storm tables, fuel rates), Types, Remotes
MVP and roadmap
Ship a 20-storm version in about 6 weeks, then add the rest in updates. A short game that's fun beats a 100-storm game that's still unfinished.
The MVP includes: the main island, the lamp with fuel and the safe circle, Fog Crawlers and the Drowned, 4 resources (wood, scrap, oil, fish), repairs and barricades, storms 1–20 with one Tide Caller fight, badges at storms 10 and 20, and data saving.
Week
Builder (maps and art)
Scripter (code)
Done when
1
Greybox island and tower
Rojo setup, StormDirector timer
You can play through calm → storm → dawn
2
Lamp room, fog and lighting look
LightService: fuel, safe circle, beam
The lamp burns out if no one refuels it
3
Creature models and animations
EnemyService: Fog Crawlers plus light damage
Leaving the light gets you hurt
4
Wreckage props, crafting bench
Gathering, carrying, crafting, repairs
A full loop works with 2 players
5
Final island art, HUD art
The Drowned, Tide Caller, storms 1–20 tuning, badges, DataService
Storm 20 is beatable but tense
6
Icon and thumbnails
Bug fixes, mobile controls, playtests
Published
After launch: Update 1 adds the rowboat, the shipwreck islet and Night Gulls (storms to 40). Update 2 adds roles, Fog Mimics and the journal (storms to 70). Update 3 adds the Keeper's hut and the final boss (the full 100).
[ ] Decide on the art style (low-poly vs. realistic)
[ ] Make a greybox and playtest the lamp-fuel loop before building anything else