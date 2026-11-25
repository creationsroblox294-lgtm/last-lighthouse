# TODO: MVP (storms 1–20)

## Week 1: island + storm cycle
- [x] Rojo project setup (`src/shared`, `src/server`, `src/client`)
- [x] StormDirector: calm → warning → storm → dawn, storm count, Great Storms, special storms
- [x] HUD: storm number, phase, countdown (scale-based for mobile)
- [x] FogController: lighting and fog change per phase
- [x] Greybox island and 3-floor tower (`tools/BuildGreybox.luau`)
- [ ] Sounds: bell + fog horn at Warning
- [ ] Rain and wind effects during Storm

## Week 2: the light
- [ ] LightService: fuel gauge, drain (3× during storms), safe-circle radius, "is this spot lit?" check
- [ ] Rotating beam (drawn on clients, server sends the angle); manual aim from the lamp room
- [ ] Lights-out alarm (15 s)
- [ ] Fuel gauge on the HUD
- [ ] Lamp room look and fog visuals

## Week 3: creatures
- [ ] Creature models and animations (Blender)
- [ ] EnemyService: Fog Crawlers spawning at the fog edge, light damage

## Week 4: gathering and building
- [ ] Wreckage spawns, gathering, carrying items
- [ ] Crafting bench, repairs, barricades
- [ ] Full loop works with 2 players

## Week 5: content and saving
- [ ] The Drowned, Tide Caller boss (storm 10)
- [ ] Storms 1–20 tuning, badges at storms 10 and 20
- [ ] DataService (session locking, retries), RunSaveService

## Week 6: ship
- [ ] Mobile controls, bug fixes, playtests
- [ ] Icon and thumbnails, publish
