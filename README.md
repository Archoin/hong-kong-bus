# Hong Kong Bus

**Small bus. Big hustle.** A playable Godot 4.6.1 vertical slice: a three-minute earnings race through a stylized Sheung Wan–Central district.

## Play

Open **`builds/Hong Kong Bus.app`** for the standalone macOS review build. Or import `project.godot` in Godot 4.6.1 and press **F5** to run the main scene. No Blender installation or network connection is needed to play.

The first shift starts with the red-roof minibus and 19 seats. Drive forward into the Western Market bay, brake, and wait while passengers board. Deliver them to the numbered destinations on the map. **Money is earned when they get off.** The richest driver wins; gold/silver/bronze bonuses are HK$200/120/60. Completed fares plus the medal bonus go into your garage wallet.

| Control | Action |
| --- | --- |
| W / Up | Accelerate |
| S / Down | Brake, then reverse |
| A / D or Left / Right | Steer |
| Space | Strong brake; stop in a bay to board/alight automatically |
| 1–9 / comma / period | Pin stops 1–9 / cycle through all 12 stops |
| E | Toggle local/express boarding; the express destination stays separate from the navigation pin |
| F / G | Accept a displayed group booking; while booked, return navigation to its target |
| M / Tab | Expand or close the live map |
| Mouse | Select a map stop or use menus |
| H | Horn and unsolicited driver wisdom |
| C | Toggle normal/high chase camera |
| R | Recover to the nearest street; costs three seconds |
| Esc | Pause/resume; from garage, return to menu |
| Enter | Start/replay a shift or resume from pause |
| F8 | Toggle all audio |

The expanded map stays live and shows the remaining time. **Esc closes the map; press it again to pause.** Default camera is third-person chase. Keep left and brake before turns. The gold road arrows suggest a route to your chosen stop; you can drive any connected street.

On approach, click a destination group in the queue panel to run an express trip. Local service fills from mixed destinations; express takes only matching public riders. Alighting and your reserved dispatch party always take priority. Group bookings pay an extra bonus only when the whole group arrives before its deadline; ordinary fares survive a missed booking deadline. Commuter and comfort tips reward timely, clean trips. Neat docking adds a small per-delivered-rider tip. In the last seconds, focus on passengers already aboard.

## Included

- One 1,120 × 660 m Sheung Wan–western Central district with **12 stops**, using actual OpenStreetMap street topology and building footprints. Its bounding area is **13×** the original map (roughly 10× useful land). Hills, waterfront, Western Market, Man Mo Temple, PMQ/Central destinations, shopfronts, signs, AC units, scaffolding and tram wires give routes distinct landmarks.
- Original Blender-built cream/red minibus, custom three-band toon shader, opening side door, brake lights, moving wheels, chassis lean, collision and rescue.
- Clustered random passenger queues, persistent destinations, 19-seat default capacity, faster service, local/express boarding, timed group dispatch, comfort/commuter tips, and precise-stop rewards.
- Moving original double-deck trams on the actual Des Voeux corridor; they stop for the player, while rivals yield to trams.
- Three competing AI minibuses: Auntie Turbo, Uncle Siu and Dim Sum Dave. They use the **same queues and fare rules**, select routes based on demand, drive on the left and yield to buses ahead.
- Live ranking, money counter, onboard destination manifest, world stop markers, minimap and selectable route planning map.
- Three-minute clock, countdown, pause, medals, results, replay and persistent garage.
- Three upgrade lines (capacity, acceleration/top speed, boarding speed) and a purchasable/equippable Jade Express variant with 23 base seats and a quicker engine. Upgrades transfer between both buses.
- Original synthesized engine, horn, bells, boarding and fare sounds, plus an original instrumental loop.

Street alignment and footprint shapes come from geographic data, but roads are widened, horizontal distances compressed, and terrain smoothed for arcade driving. Architecture is stylized original geometry, not a photogrammetric reconstruction; traffic directions and bus stop placement are adapted for free routing. The Jade Express shares the base body mesh with a different livery and specifications. This slice is local single-player with AI; it does not implement multiplayer, a campaign, scheduled traffic simulation, or a full vehicle collection.

## Saves

Garage progress is stored by Godot at `user://garage.cfg`. On this Mac that is normally:

`~/Library/Application Support/Godot/app_userdata/Hong Kong Bus/garage.cfg`

Only completed races are banked. Abandoning a shift does not pay out. Tied earnings share the relevant medal; zero-fare races receive no medal bonus. Test runners use separate save files and remove them afterward.

## Project structure

- `scripts/race.gd`: passenger, capacity, fare, clock and ranking rules.
- `scripts/district.gd`: stop data and road-graph routing.
- `scripts/main.gd`: match flow, services, camera, garage and save state.
- `scripts/bus.gd`: arcade vehicle handling and bus presentation.
- `scripts/rival.gd`: demand-driven AI, left-side lanes and yielding.
- `scripts/stop_visual.gd`: queues and stop indicators.
- `scripts/hud.gd`: responsive drawn UI and input hit regions.
- `scripts/route_guide.gd`, `scripts/ambient_trams.gd`: road guidance and moving tram scenery.
- `assets/map_data/district.json`: source-derived street/footprint/elevation dataset.
- `docs/GAMEPLAY.md`: design hypotheses, experiments, rejected ideas and iteration reviews.
- `docs/MAP_DESIGN.md`, `docs/map/reference_atlas.html`: region selection, references and reconstruction limits.
- `scenes/district.tscn`: baked, editable city scene; static geometry is batched into MultiMeshes.
- `assets/models/minibus.glb`: ready-to-play model.
- `tools/source/minibus.blend`: original Blender source.
- `tools/build_bus.py`, `tools/build_city.gd`, `tools/build_audio.py`: reproducible asset generators.
- `tests/`: rules and end-to-end gameplay checks.
- `tools/playtest.gd`: physical-control automated race and viewport captures.
- `tools/capture_v2.gd`: current UI interaction and screen layout checks.

## Validation and rebuilding

```sh
./tests/run_checks.sh

# A complete rendered race using injected driving controls, not teleportation:
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/playtest.gd -- --policy=express --seed=20261113

# The same driving simulation, accelerated without rendering:
/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script tools/playtest.gd -- --policy=express --seed=20261113

# Screen captures and menu clicks:
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/capture_v2.gd

# Regenerate the city. IMPORTANT: keep rendering enabled; headless Godot
# cannot serialize the MultiMesh transform buffers used by this generator.
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/build_city.gd

# Regenerate the original bus and audio:
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/build_bus.py
python3 tools/build_audio.py

# Export the local macOS app (matching Godot 4.6.1 templates required):
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release macOS 'builds/Hong Kong Bus.app'
```

Review captures are under `captures/`. Current physical-run reports are named `playtest_<policy>_<seed>_report.json`; archived v0.1 reports are not evidence for the expanded city. `captures/v2/08_results_fixture.png` uses artificial scores only for layout review. Physical driving uses injected digital controls without teleporting or granting fares; strategy simulations abstract travel time and cannot establish human fun. Captures, build products and Godot caches are excluded from source control.

The macOS build is locally ad-hoc signed for review, not notarized for public distribution. See [research and asset notes](docs/RESEARCH.md) and [validation notes](docs/VALIDATION.md).

## Geographic attribution

Map data © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright), [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/). Terrain: Copernicus DEM via [Open-Meteo Elevation API](https://open-meteo.com/en/docs/elevation-api), adapted for gameplay. Original source data and the importer are retained under `tools/map_source/` and `tools/import_map.py`. Reference street photographs are linked in the atlas; they are not shipped as game textures.
