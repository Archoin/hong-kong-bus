# Validation

Tested locally with Godot **4.6.1**, Blender **5.2.2**, and the OpenGL Compatibility renderer on Apple M5 Pro hardware, 13 November 2026.

## Automated checks

- **202 rules checks**: destination validity, default 19 seats, boarding capacity, unloading before boarding, exact fare accounting, shared queues, AI fares, timer expiry, no service after expiry, idempotent settlement, all medal ranks, no zero-fare bonus farming, upgraded capacity, and connectivity of every stop pair.
- **21 gameplay checks**: scene startup/countdown, injected acceleration and braking, physical movement and building collision, real bay boarding, pause, destination drop-off, complete 180-second match, productive rival earnings, banked results, duplicate-payout protection, seat/door upgrades, new bus purchase, save/load, and replay reset.
- **Six injected UI interactions**: start, map stop selection, pause/resume, results-to-garage, seat upgrade, and new-bus purchase. Screens captured and visually inspected for title, countdown, driving, full map, pause, results, garage and green-roof vehicle.
- Strict `godot-headless` startup validation: **passed**, with no unexpected script/resource errors.
- Both debug and release macOS app bundles were launched independently of the editor and rendered a viewport screenshot successfully. Local ad-hoc signature verified with `codesign --verify --deep --strict`.

The rules/gameplay runners use separate test saves. The full-match gameplay integration test accelerates simulation by calling normal gameplay methods; it also moves the bus directly between selected stops to exercise service and payout flows. This is distinct from the rendered driving test below.

## Physical-control playtest

`tools/playtest.gd` runs the whole three-minute race through injected throttle, steering, reverse and brake actions. It follows the street graph, services passengers through the normal game logic, and captures the viewport. It does **not** teleport the bus or grant fares. The seed is fixed to `20261113` for repeatability; timing can vary slightly with rendering load. The final capture run uses `--fixed-fps 60`, which preserves fixed simulation steps while allowing the run to proceed without real-time synchronization.

The final rendered run completed **41 deliveries** for **HK$1,276**, taking gold. The rivals earned **HK$966 / HK$852 / HK$1,051**. It used no rescue teleports and recorded one collision. The actual outcome is recorded in `PLAYTEST_REPORT.json`. Its screenshots are in `captures/playtest_*.png`, including `playtest_results.png`. `review_results_layout.png` is a separate UI fixture with artificial scores and must not be treated as evidence of driving results.

Issues found and corrected during these runs:

1. Headless scene baking discarded MultiMesh transform buffers. City baking now requires an active renderer, and the saved city was inspected in the real game.
2. Overlarge world stop labels obscured the road. Reduced their size and hid them in the menu preview.
3. The vehicle collision box initially let the wheels sink into the road. Corrected its vertical offset.
4. Oncoming rivals could push the player with kinematic movement. Added left-side lanes and forward yielding.
5. Mutually yielding rivals could deadlock at turns. Added deterministic intersection priority with a three-second clearance reservation; full-match tests now require every rival to earn more than HK$200.
6. Modal-map clicks could reach the underlying HUD. Modal screens now own their hit regions.
7. The idle service bar kept cycling after a queue emptied. It now stops when no service is happening.
8. The initial automated driver aimed too precisely at occupied bay centers. It now recognizes the actual game service area and can reverse-steer out of traffic without using rescue teleportation.

## Scope of review

This validates the local macOS slice and its core loops. It is not multiplayer, cross-platform certification, or a long-term economy balance study. The city is a compressed, flat interpretation of the district. The Jade Express is a livery/stat variant of the same original bus mesh. AI uses a small authored road graph and simplified right-of-way rules.
