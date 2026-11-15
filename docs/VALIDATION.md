# Validation — v0.2

Reviewed with Godot 4.6.1 and the OpenGL Compatibility renderer on this Apple M5 Pro Mac. The original v0.1 validation is retained in `tools/archive_v1/docs/VALIDATION.md`.

## Automated checks

`tests/run_checks.sh` passed with **9,120 rules/graph checks**, **320 gameplay-system checks**, and **23 scene-integration checks**. Coverage includes all 12 destinations and 132 directed stop pairs, capacity and fares, shared queues, dispatch quote/acceptance consistency, expiry and tips, settlement, physical acceleration/braking, bay service, pause, upgrades, save/load and replay. Integration rivals earned $1,073 / $1,262 / $624 across the complete shift.

`tools/capture_v2.gd` passed all eight UI checks on the final city: start, direct express selection, actual bay boarding, twelfth-stop selection, navigation/express separation, dispatch acceptance, resume and results-to-garage flow. Its results screen uses fixture scores, not a claimed driving outcome.

## Physical driving

Full 180-second local, express and dispatch runs used digital steering/throttle/brake input, physical motion and normal passenger service. They did not teleport the player or grant fares. Test-controller defects and the Hollywood building-clearance defect were corrected before comparison. Detailed evidence and revision distinctions are in [DRIVING.md](DRIVING.md) and `gameplay_experiments/physical_*.json`.

The rendered express run completed **48 deliveries, HK$1,432, silver**, with **zero collisions or recovery manoeuvres**, covering 2.13 km. Background drawing suspension made its engine FPS readings invalid as a rendering benchmark; no certified FPS claim is made.

Actual screenshots revealed occlusion at Western Market and Hollywood Road. The final generator now applies local scale before rotation, matching rendered boxes to collision shapes. The camera uses a sphere sweep plus a higher fallback. `tools/review_camera.gd` repeated 46 seconds of physical driving and captured both previously obstructed views; the bus and road are now visible in `captures/v2/camera_010_chase.png` and `camera_045_high.png`. These visual fixes leave the tested road/building collision geometry unchanged.

## Interpretation

The tests establish working systems and feasible driving routes, not subjective fun or optimal balance. Six-seed strategy simulations and three physical policies reveal different passenger completion, route choice and earnings tradeoffs. See [GAMEPLAY.md](GAMEPLAY.md) for hypotheses, rejected ideas and findings. Human review remains the next test of enjoyment and clarity.

The city uses real topology/footprints, widened roads, smoothed terrain and original stylized architecture. It is not a surveyed digital twin. Traffic and rivals use simplified yielding. The Jade Express remains a livery/stat variant of the same minibus model.

## Standalone build

Both the debug and final release app launched independently of the editor and rendered the enlarged city with the new gameplay HUD. Release `builds/Hong Kong Bus.app` reports version **0.2.0**, passed `codesign --verify --deep --strict`, and saved `v02_release_smoke.png` without script/resource errors. The release preview is copied to `captures/v2/release_smoke.png`. `git diff --check` also passed. The app is locally ad-hoc signed for review, not notarized for public distribution.
