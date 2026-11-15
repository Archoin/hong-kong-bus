# Iteration 2 integration log

This iteration responds to two first-slice failures: a repetitive service loop and an invented tiny grid that did not resemble Hong Kong. Gameplay and district design are tracked in `../GAMEPLAY.md` and `../MAP_DESIGN.md`; this file records integration/review findings, including unresolved issues.

## Pass 1 — richer choices, readable commitments

- Actual Sheung Wan–western Central road graph replaces six-stop assumptions throughout the controller, HUD, rivals and route guide. A short road-level arrow trail distinguishes a suggested driving route from the player's choice of destination.
- Express service has a separate destination from the navigation pin. Inspecting another stop cannot silently change boarding rules. On approach within 48 m, the three largest destination groups appear as direct "run express" actions. E at the pinned pickup chooses the dominant destination.
- Unloading begins immediately, then a 0.65-second doors-opening grace precedes automatic boarding. This creates a moment to choose without returning to the old long dwell times.
- Dispatch acceptance pins pickup; completion of party boarding pins delivery unless the player explicitly takes over navigation. Reserved riders always board before ordinary express/local passengers.
- Results separate journey fares, tips, booking bonuses and medal bonuses. Docking feedback only promises money for actual delivered riders.
- Different passenger silhouettes identify commuters (briefcase), sightseers (hat and camera) and parties (matching gold caps/luggage). Original low-poly double-deck trams follow the actual Des Voeux tram corridor.

## Evidence and limits

The gameplay agent's fixed-seed route simulations are schedule experiments, not physical or human playtests. They show a tradeoff worth testing: express completes a higher fraction of boarded journeys, mixed loads deliver more passengers, and dispatch earns comparable money via fewer, explicit jobs. No arbitrary express fare multiplier was added.

This initial pass was followed by the physical, rendered and UI reviews recorded below. The background-window FPS measurement was rejected; no performance benchmark is claimed.

## Reference for the moving tram silhouette

[Hong Kong Tramways — Our Story](https://www.hktramways.com/en/our-story/) documents the double-deck tradition and surviving historic design. The in-game model is original stylized geometry with fictional advertising; no photographs or downloaded meshes are shipped as tram assets.

## Final integration review

Rules and scene integration passed on the expanded map: 9,120 graph/game rules, 320 gameplay-system checks and 23 scene-flow checks. The final UI review covers direct express selection, all 12 map destinations, preserving the express filter when navigation changes, booking acceptance and replay/garage navigation.

The full rendered express shift completed 48 deliveries for $1,432, silver, with no collisions or recovery manoeuvres. Background rendering suspension made its engine-FPS figures unsuitable as a performance benchmark. Forced viewport drawing now makes screenshot capture independent of background window drawing.

Actual driving screenshots exposed camera occlusion at Western Market and Hollywood Road. Review found a city-builder transform defect: scaling an already rotated Basis scaled world axes, so rendered landmark boxes and beams did not match their correctly rotated collision shapes. The builder now composes rotation with local scale. Camera clearance also uses a sphere sweep and an overhead fallback rather than collapsing a single ray into the bus. These changes are followed by a repeatable 46-second physical corner regression in `tools/review_camera.gd`.

Further UI fixes: dispatch-party boarding explicitly names its destination, the full map retains the countdown, navigation and express destinations are separately labelled, booking offers show their acceptance deadline and total distance, and the manifest exposes potential tips. Gameplay decisions and limitations remain documented in `../GAMEPLAY.md`.

The corrected 46-second camera regression completed and both affected views were visually checked. Eight final UI assertions passed across nine captured screens. Landmark foundations now extend below the smoothed slope to avoid visibly floating lower corners; the tested collision geometry remains unchanged.
