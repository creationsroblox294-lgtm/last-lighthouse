# TODO: MVP (storms 1–20)

## Week 1: island + storm cycle
- [x] Rojo project setup (`src/shared`, `src/server`, `src/client`)
- [x] StormDirector: calm → warning → storm → dawn, storm count, Great Storms, special storms
- [x] HUD: storm number, phase, countdown (scale-based for mobile)
- [x] FogController: lighting and fog change per phase
- [x] Greybox island and 3-floor tower (`tools/BuildGreybox.luau`)
- [x] Rain during warning and storm
- [ ] Sounds: bell + fog horn at Warning

## Week 2: the light
- [x] LightService: fuel gauge, 3× storm drain, safe-circle radius, "is this spot lit?" check
- [x] Rotating beam (clients draw it, server sends the angle); manual aim from the lamp room console
- [x] Lights-out alarm (15 s), then the fog swarms
- [x] Fuel gauge on the HUD, safe circle drawn as a wall of light

## Week 3: creatures
- [x] EnemyService: Fog Crawlers spawn at the fog edge, burned by the light, circle its edge, hunt players outside it
- [x] The Drowned: climb out at Wreck Beach, slowed by light, smash barricades and the tower
- [x] Creature models and animations in Blender (Fog Crawler, Drowned, Tide Caller)
- [ ] Upload the Blender models to Roblox and swap them in for the greybox shapes (needs asset upload permission)

## Week 4: gathering and building
- [x] Physical items you carry one at a time; wreckage after every storm; supply crates
- [x] Chop pines, fish at tide pools and the dock (storm 5+)
- [x] Shared storage, refuel the lamp, eat fish
- [x] Floor health (ground / bunk / lamp room) with effects; hammer repairs; barricades
- [ ] Playtest a full loop with 2 players

## Week 5: content and saving
- [x] Tide Caller boss on every 10th storm (beam on its eyes; storm holds until it's beaten)
- [x] Run loss (tower falls or everyone is lost) and a fresh run
- [x] DataService: Keeper Level (XP), best storm, session locking, retries, autosave
- [ ] Badges at storms 10 and 20: create them on the Creator Hub, paste the IDs into `Config.Progress.Badges`
- [ ] Storms 1–20 tuning from playtests

## Week 6: ship
- [ ] Mobile playtest (Device Simulator), bug fixes
- [ ] Icon and thumbnails, publish

## Known limits / later
- Creatures walk straight lines with ramp waypoints, not PathfindingService. Fine for this island; revisit if the map gets more complex.
- No Lost Soul ghost or lantern revive yet (dead players wait for dawn).
- Special storms: Red Tide and Calm Night change spawns; Silent Fog and Ghost Ship are labels only for now.
