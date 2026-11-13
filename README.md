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
| 1–6 | Pin a stop and show its suggested route |
| M / Tab | Expand or close the live map |
| Mouse | Select a map stop or use menus |
| H | Horn and unsolicited driver wisdom |
| C | Toggle normal/high chase camera |
| R | Recover to the nearest street; costs three seconds |
| Esc | Pause/resume; from garage, return to menu |
| Enter | Start/replay a shift or resume from pause |
| F8 | Toggle all audio |

The expanded map stays live. **Esc pauses the race.** Default camera is third-person chase. Keep left, brake before turns, and use the central cross streets to avoid long trips around the perimeter.

## Included

- One interconnected city district with six stops, waterfront, ferry, Western Market, temple forecourt, shop awnings, bilingual signs, scaffolding and skyline.
- Original Blender-built cream/red minibus, custom three-band toon shader, opening side door, brake lights, moving wheels, chassis lean, collision and rescue.
- Random passenger queues, persistent per-passenger destinations, 19-seat default capacity, timed boarding, unloading before boarding, and distance-based fares.
- Three competing AI minibuses: Auntie Turbo, Uncle Siu and Dim Sum Dave. They use the **same queues and fare rules**, select routes based on demand, drive on the left and yield to buses ahead.
- Live ranking, money counter, onboard destination manifest, world stop markers, minimap and selectable route planning map.
- Three-minute clock, countdown, pause, medals, results, replay and persistent garage.
- Three upgrade lines (capacity, acceleration/top speed, boarding speed) and a purchasable/equippable Jade Express variant with 23 base seats and a quicker engine. Upgrades transfer between both buses.
- Original synthesized engine, horn, bells, boarding and fare sounds, plus an original instrumental loop.

The district is deliberately compressed and fictionalized, not a street-accurate reconstruction. The Jade Express shares the base body mesh with a different livery and specifications. This slice is local single-player with AI; it does not implement multiplayer, a campaign, scheduled traffic simulation, or a full vehicle collection.

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
- `scenes/district.tscn`: baked, editable city scene; static geometry is batched into MultiMeshes.
- `assets/models/minibus.glb`: ready-to-play model.
- `tools/source/minibus.blend`: original Blender source.
- `tools/build_bus.py`, `tools/build_city.gd`, `tools/build_audio.py`: reproducible asset generators.
- `tests/`: rules and end-to-end gameplay checks.
- `tools/playtest.gd`: physical-control automated race and viewport captures.
- `tools/capture_screens.gd`: UI interaction and screen layout checks.

## Validation and rebuilding

```sh
./tests/run_checks.sh

# A complete rendered race using injected driving controls, not teleportation:
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/playtest.gd

# The same driving simulation, accelerated without rendering:
/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script tools/playtest.gd

# Screen captures and menu clicks:
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/capture_screens.gd

# Regenerate the city. IMPORTANT: keep rendering enabled; headless Godot
# cannot serialize the MultiMesh transform buffers used by this generator.
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/build_city.gd

# Regenerate the original bus and audio:
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/build_bus.py
python3 tools/build_audio.py

# Export the local macOS app (matching Godot 4.6.1 templates required):
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release macOS 'builds/Hong Kong Bus.app'
```

Review captures are under `captures/`. `playtest_results.png` and `playtest_report.json` are actual autonomous-play outcomes. `review_results_layout.png` uses fixture scores solely to inspect the results layout. Captures, build products and Godot caches are excluded from source control.

The macOS build is locally ad-hoc signed for review, not notarized for public distribution. See [research and asset notes](docs/RESEARCH.md) and [validation notes](docs/VALIDATION.md).
