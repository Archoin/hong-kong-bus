# Driving iteration — Hong Kong Bus

## Intent

The first version worked as a vehicle controller, but much of its motion read like rotating a board on a flat surface. The driver could hold throttle through most choices, every wall touch removed nearly half the speed each frame, and hills had no physical/visual alignment. The larger city needs steering and stopping to become useful decisions without turning a three-minute earnings game into a difficult simulator.

This track therefore keeps the existing W/S/A/D, arrows and Space controls. It does **not** add an obligatory drift/boost combination. The gameplay track adds route and boarding decisions; this track makes executing those choices feel responsive and legible.

## Research and interpretation

- Cameron Petty's firsthand *San Francisco Rush* postmortem, [Game Developer, August 1998, pp.55–64](https://media.gdcvault.com/GD_Mag_Archives/GDM_August_1998.pdf), describes both the value of tactile physical cues and the risk that a realistic fast-driving model creates too steep a learning curve. Interpretation for this slice: preserve clear mass/steering feedback, but do not require simulation-level control to make an ordinary corner.
- [Godot CharacterBody3D documentation](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html) explains floor snapping, constant slope speed, contact normals, and grounded movement. These are used to keep the minibus attached to authored hills and separate wall impacts from road gradients.
- [Transport Department — public transport](https://www.td.gov.hk/en/road_safety/road_users_code/index/chapter_3_for_passengers/public_transport/index.html) and the [minibus reference photo](https://commons.wikimedia.org/wiki/File:Rmb_le9372.jpg) inform the cream body/red roof, roof destination plate, side seat lettering and windshield fare card. All geometry and lettering remain original.

## Hypotheses

1. **A glancing scrape should continue along the street.** The first controller treated every wall contact as a major crash. Projecting away the into-wall component, while retaining head-on penalties, should reduce frustrating sticky collisions.
2. **A short input rack and speed-sensitive steering should make narrow corners readable.** Low-speed steering stays tight; higher speed widens the arc. Small lateral follow lag and body roll communicate mass without making recovery slow.
3. **Precise stopping needs a stable zero-speed state.** Space stops completely at parking speed, with no sideways creep. Reverse remains available after a nose-first impact.
4. **Hills should affect the minibus's pose and physical contact.** The collision hull and visible body follow the ground plane while the yaw/camera root stays level. The same presentation API is available to road-graph-driven rivals.
5. **Skill rewards should remain contextual.** The bus exposes approach/impact telemetry for accurate docking rewards and preserved passenger tips. Routine braking is not itself punished.

## Implementation

- Bicycle-like yaw from speed, a 3.8m wheelbase and speed-sensitive steering angle; faster rack return for short keyboard taps.
- Short lateral velocity follow, stronger grip under braking, positive zero-speed snap while braking.
- Wall impact magnitude uses the velocity component into the contact normal. Head-on impacts stop; grazing contact slides and adds mild friction. `bumped` emits the actual normal-impact speed above 3.2m/s.
- Physics hull and visual pitch/roll follow floor normals. Floor snapping is 1.1m; constant ground speed avoids accidental high-speed downhill sliding.
- Wheel hubs now spin with tires, front wheel pivots steer visibly, and body pitch/roll communicates acceleration/cornering.
- Doors automatically close above 1.2m/s. Brake lamps reflect braking/parking rather than being on during all reverse movement.
- Region roof plate (`中環 · 西營盤`), side seat-count lettering, and a windshield fare card add specific minibus cues.

## API for integration

Existing `speed`, `max_speed`, `acceleration`, `enabled`, `controlled`, `visual`, `wheels`, `door_open`, `reset_at`, `apply_livery`, and `bumped` are preserved.

`telemetry()` returns `speed`, `lateral_accel`, `last_stop_approach_speed`, `last_brake_peak`, `seconds_since_impact`, `steering`, `ground_pitch`, and `ground_roll`.

`set_remote_motion(direction: Vector3, travel_speed: float, delta: float)` updates AI wheel steering/spin, brake lamps and ground pose. Call after the AI moves/turns; call with zero speed while dwelling or blocked. The caller must not also rotate the wheel array.

`set_route_display(text: String)` changes the roof destination plate if the game wants it to follow an express route.

## Round 1: repeatable handling probes

The standalone fixture `tests/driving/handling_probe.gd` creates its own collision floor, walls and hill, so its measurements do not depend on the map being rebuilt in parallel. It injects ordinary control actions. Baseline and new measurements are retained in `DRIVING_BASELINE.json` and `DRIVING_CURRENT.json`.

| Probe | V1 | Revised |
| --- | ---: | ---: |
| Speed after 2 seconds full throttle | 22.00m/s | 22.00m/s |
| Shallow wall scrape: travel in 1.5s | 12.10m | 29.96m |
| Shallow wall scrape: exit speed | 0.28m/s | 22.94m/s |
| Head-on barrier exit speed | 0.22m/s | ≈0m/s |
| 1-second steering at 8m/s | 65.58° | 78.61° |
| 1-second steering at 23m/s | 69.39° | 87.24° |
| Braking distance from 23m/s | — | 11.98m |
| Braking distance from 30m/s | — | 20.04m |
| Reverse recovery after wall, 1.25s | — | 5.18m |
| 12° hill climb height after 5s | — | 12.14m |
| Parked drift on 12° hill | — | 0m |

The revised controller's short follow lag adds a small amount of distance to braking from 22m/s (10.94m vs10.34m). This is a deliberate mass cue, but remains a tuning candidate if actual docking feels too slippery.

## Round 1: rendered corner review

`tests/driving/render_handling.gd` drives a 90° corner in a 12m-wide road with a solid inside building. The deterministic control run completed without collisions. Maximum centerline deviation was 1.375m. The bus stayed inside the road and could return to speed after the corner. Captures are `captures/driving_corner_1.png` through `driving_corner_6.png`.

The test is evidence of control feasibility and readable wheel/body motion, **not evidence that humans find the game fun**. The whole-route gameplay review and user feedback are still the decisive tests. Further review is needed on the actual non-grid streets and hill transitions once the expanded map is integrated.

## Reproduce

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --log-file /tmp/hkbus-driving-probe.log --path . --script tests/driving/handling_probe.gd
/Applications/Godot.app/Contents/MacOS/Godot --fixed-fps 60 --log-file /tmp/hkbus-driving-render.log --path . --script tests/driving/render_handling.gd
```

A 24° stress incline also passed the physical climb, descent, floor contact, and parked-drift checks (0m drift). Reproduce with the headless command above followed by `-- --hill-degrees=24`. This checks a steep continuous surface; the final city road seams remain an integration check.

## Vehicle detail review

The standalone `tests/driving/render_vehicle.gd` inspection captured front and rear three-quarter views (`captures/driving_vehicle_front.png`, `captures/driving_vehicle_rear.png`). The first view revealed that the old rear slogan overlapped the grille and waist stripe and the registration lettering exceeded its plate. The revised view places cream lettering inside the rear window and scales the registration to its plate. Chinese route lettering, side seat-count text, and the windshield fare card were visually checked.

## Keyboard-only corner follow-up

The original corner controller varied action strength, which is useful for repeatability but is more precise than a keyboard. A second run uses only full left/right taps (`--digital-steering --no-capture`) on the same 12m corner. It completed with zero collisions and maximum centerline deviation 1.867m, compared with 1.375m for variable-strength steering. This supports keyboard feasibility while exposing the expected extra correction. It still does not replace human play.

## Full-shift physical policy harness

`tools/playtest.gd` now supports `--policy=local|express|dispatch`, `--seed=N`, and `--no-capture`. It drives the actual game for the normal 180-second race through digital action presses, services passengers through the normal main-game stop logic, and never calls rescue or teleports. Local chooses mixed pickup/drop value per graph distance; express selects a concentrated destination; dispatch prioritizes visible party jobs. A short reversing maneuver can recover from a nose-first obstruction, and every recovery is recorded.

Reports include per-second positions/grounded state, route decisions, visits and dwell, individual impacts, large position discontinuities (to detect automatic game rescues), player earning breakdown, and rival cash. Captures and reports use policy/seed names to avoid overwriting other experiments. This is a repeatable physical feasibility comparison, not a claim that the automated policies are optimal or human-like. The expanded collision bake has now completed the three physical policy runs below.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --log-file /tmp/hkbus-physical-local.log --path . --script tools/playtest.gd -- --policy=local --seed=20261113 --no-capture
```

## Actual-city integration findings

The first physical route run exposed two test-controller defects: 3m waypoint acceptance caused repeated circles inside the bus turning radius, and a final stop sharply beside the bus could produce the same orbit. The harness now advances road waypoints within 6m and brakes inside a valid bay when its remaining target lies sharply sideways. Stop service still uses the real game speed and proximity rules. Wall recovery detection now uses actual displacement rather than commanded speed, which can rise briefly despite being physically blocked.

With the controller corrected, the local policy reached Western Market, Bonham Strand and Hollywood Road Park in 47 seconds, delivering 18 passengers. The next Hollywood-to-ManMo leg hit a building face at (-263.44,30.95,30.05). The map agent traced this to needle-shaped building remnants between flat-capped road buffers, then changed road clipping to round caps. That failure report is preserved in `docs/gameplay_experiments/physical_local_obstructed.json`; the revised scene subsequently passed that leg. This separates an observed geometry defect from poor autopilot behavior.

## Stable-city full-shift comparison

All runs used seed 20261113, base 19-seat bus, the normal 180-second race, digital controls, physical motion, and the normal passenger service logic. The final city had the round-cap building-clearance fix. All 181 per-second samples in each run were grounded; no position discontinuities or rescues occurred.

| Policy | Cash | Delivered / boarded | Rank | Visits / unique stops | Distance | Bumps / reverses | Dwell share |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Local mixed | $1,196 |44 /60 |2 |11 /6 |1,983m |4 /1 |14.0% |
| Express | $1,432 |48 /54 |2 |10 /7 |2,134m |1 /0 |13.9% |
| Dispatch | $967 |13 /24 |4 |7 /6 |2,337m |7 /0 |6.6% |

Dispatch completed 3 jobs with zero failures and earned $562 in dispatch bonuses. Its pure job-priority policy spent more time repositioning across the city, and delivered fewer ordinary riders. Express concentrated its loads and converted a greater share of boarded passengers into fares. This seed therefore shows useful differences in routes and earnings; it does not establish optimal balance across seeds or prove subjective fun. The physical run also confirmed all routes were drivable without teleportation. The local reverse was near a rival at Hollywood Road Park; it was not the corrected building trap.

Preserved headless reports: `docs/gameplay_experiments/physical_local_20261113.json`, `physical_express_20261113.json`, and `physical_dispatch_20261113.json`. Rendered validation follows separately; headless FPS is deliberately not reported as rendering performance.

## Traffic-aware follow-up

Inspection of the first dispatch report showed all 7 impacts were repeated contacts with the same moving tram, not remaining building obstructions. The test driver had been accelerating blindly into traffic. A three-ray forward traffic sensor now reduces the harness's target speed and suppresses reversing while deliberately following traffic. This is test-driver behavior only; human player controls remain manual. Root also made rivals yield to trams before this comparison, so these results supersede the earlier table for the traffic-aware revision.

| Policy | Cash | Delivered / boarded | Rank | Visits / unique stops | Distance | Bumps / reverses | Traffic-follow time |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Local mixed | $1,049 |39 /58 |2 |9 /5 |1,566m |2 /0 |33.8s |
| Express | $1,359 |46 /48 |3 |9 /6 |2,060m |1 /0 |10.5s |
| Dispatch | $878 |14 /27 |4 |6 /5 |1,616m |1 /0 |47.2s |

Dispatch completed 2 jobs and failed none; the traffic-aware policy avoided the repeated tram impacts but spent substantial time following slower traffic. All three remained grounded in all 181 samples with zero discontinuities. Reports are preserved with `_traffic.json` suffix under `docs/gameplay_experiments/`. The rendered run uses the subsequent actual-railway tram path and is therefore a distinct revision, not an exact visual replay of these comparisons.

## Rendered full-shift verification and camera limitation

The rendered express run completed the full 180.000 simulated seconds on the subsequent actual-railway tram-path revision: $1,432, 48 delivered, silver/rank 2, zero bumps, zero reversing recoveries, and 2,132m driven. The results screen shows $1,229 fares + $203 tips + $120 medal bonus = $1,552 banked. The preserved report is `docs/gameplay_experiments/physical_express_20261113_rendered.json`.

Valid driving captures are `captures/playtest_express_20261113_010_chase.png`, `_045_high.png`, and `_080_chase.png`; final results are `_results.png`. The 10s Western departure and 45s Hollywood departure expose severe camera occlusion, reported to root for camera correction. The 80s PMQ view clearly shows the bus, inclined street and destination guidance. These screenshots do not justify a blanket camera-quality pass.

After 80s, macOS window occlusion suspended drawing while simulation continued. The 115s and 150s captures waited for a later draw and therefore became duplicates of the results screen; those misleading files were removed. The raw engine counter reported 228 FPS median / 92 minimum, but that is **not valid rendering throughput** because background frames skipped drawing. The report explicitly sets `fps_valid=false`. Observed rendered-frame draw calls were 1,601 median / 1,763 maximum. A foreground-only performance run is needed before certifying FPS.

The harness now forces a draw at capture time instead of indefinitely awaiting `frame_post_draw`, and records focused render samples for future performance qualification. This change passed script parsing; root owns the final camera repro after the last map bake.
