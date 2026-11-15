# Hong Kong Bus — gameplay notebook

This is the working gameplay design, hypothesis and playtest record for the second iteration (14 November 2026). It is intentionally separate from visual/map research. Passing a test proves a rule works; it does not prove the game is fun.

## Diagnosis of the first slice

The player's repeated action was “fill with arbitrary destinations, drive to a large count, wait, repeat.” Individual riders were interchangeable. A full bus was an inconvenience rather than a route decision. All queues were alike; there were no changing opportunities worth abandoning a plan for. Long loading waits provided little agency. The larger district would amplify these problems if destinations stayed uniformly random: much of a three-minute shift would be spent hauling riders who could not realistically be delivered.

## Research and interpretation

- [SEGA's Crazy Taxi product page](https://store.steampowered.com/app/71230/Crazy_Taxi/) emphasizes earning fares through expressive, fast driving and a varied physical city. Our inference: repeated pickup/drop-off can remain engaging when vehicle execution and the road create decisions. We are not copying its missions or assets.
- [Dinosaur Polo Club's Mini Metro page](https://dinopoloclub.com/games/mini-metro/) describes changing a network as demand grows while allocating limited resources. Our inference: seat capacity becomes interesting when a player can deliberately align demand with a route, rather than simply accepting a random manifest.
- [Team17's Overcooked page](https://www.team17.com/games/overcooked) describes completing orders before impatient customers leave. Our inference: an explicit, optional order can turn a vague money goal into a short, readable commitment. We retain ordinary fares when a dispatch bonus is missed, so one mistake does not invalidate the shift.

## The revised decision loop

1. Look at the nearby queue's destination breakdown and two dispatch offers.
2. Choose a mixed local run, an express destination, or one dispatch commitment.
3. Drive a route that balances current drop-offs, free seats and the time left.
4. Brake into the bay accurately. Riders alight first; then boarding takes roughly two to five seconds for a useful load.
5. Reconsider when demand changes, a commuter tip is running out, or a dispatch finishes.

### Express versus mixed boarding

`E` toggles the bus between mixed boarding and express boarding for the pinned stop. Express skips unrelated passengers but never blocks alighting. This trades passenger volume for a coherent, quick-to-complete route. An accepted dispatch party boards first because it is an explicit commitment. Public passengers reserved by another driver cannot be stolen and do not block the queue.

Normal queues contain a local cluster rather than uniformly random destinations: approximately 58% choose the current nearby favored stop, another 28% choose among the closest three, and 14% may want a longer journey. The favored local destination rotates every 45 seconds. All actual passenger destinations are fixed at spawn time.

### Dispatch board

Two offers are visible, one leaning toward a nearer run and the other toward a longer express opportunity. A driver explicitly accepts one job at a time. Acceptance reserves and spawns a group of three to five passengers at the pickup stop. Complete the whole group before the deadline to earn the bonus; partial or late delivery still earns the ordinary per-passenger fare.

Offer expiry is an absolute elapsed race time, initially 34 seconds after creation. A contract deadline is computed on acceptance from the driver's actual position, graph distance to pickup, graph distance to destination, service allowance and a 20-second margin. The planning speed is 14 m/s. Both `deadline` and `offer_expires` use elapsed seconds since the race began. Snapshot APIs also expose `time_left` and `offer_time_left` so the UI does not have to convert units.

Parties are protected from other drivers after acceptance, but offers are shared. A rival may take an offer the player has not accepted. Waiting members of an expired job become public passengers again. No new offer is generated in the final 38 seconds; acceptance refuses jobs with insufficient shift time.

### Passenger and driving feedback

- Regular riders pay the shown base fare.
- Commuters offer a small tip for a direct, timely journey. The deadline starts when they board and uses road distance; their base fare survives lateness.
- Sightseers offer a small comfort tip without a deadline.
- Impacts reduce the tip integrity of riders already onboard, never the base fare. Ordinary useful braking is not punished.
- A precise, clean stop adds HK$4 per rider delivered at that stop; a neat stop adds HK$2. Visiting empty bays never generates money. No abstract global combo multiplier is used.

## Integration contract

`service(driver_id, stop_id, express_dest=-1)` remains compatible with the first slice. The returned event retains `kind`, `fare`, `rider`, and adds `base_fare`, `tip`, `dispatch_bonus`, `contract_completed`. `fare` is the actual cash delta, including any final-party bonus.

- `dispatch_offers(driver_id=0)` returns up to two available snapshots.
- `quote_contract(driver_id, offer_id, from_position=Vector3.INF)` is read-only and returns `available`, `approach_distance`, `total_distance`, `budget_seconds`, `can_finish`, `reason`. Distances are graph metres, budget is seconds. `available` means eligible to claim, while `can_finish` additionally requires the budget to fit the shift with two seconds remaining. Capacity does not reject an offer because partial party boarding is supported.
- `accept_contract(driver_id, offer_id, from_position=Vector3.INF)` delegates eligibility and deadline calculation to that exact quote, then accepts one job and spawns its party. Supply the actual bus position. Infeasible quotes explain the refusal before selection.
- `active_contract(driver_id=0)` and `dispatch_hint(driver_id=0)` expose progress and the current pickup/drop-off target.
- `pop_events(driver_id=0)` drains lightweight notifications such as acceptance, party aboard, completion, expiry, and lost tips.
- `stop_brief(stop_id, driver_id=0, express_dest=-1)` exposes destination counts and boardable counts.
- `boardable_count(...)` lets the service UI stop correctly when no express-matching riders remain.
- `record_stop(driver_id, stop_id, precision, clean=true)` records one docking grade; `depart_stop(driver_id)` clears it.
- `apply_bump(driver_id, severity)` reduces onboard tip integrity in the range 0–1.
- `onboard_tip_value()` and `earliest_tip_deadline()` expose the optional tip opportunity.
- Driver records expose `fare_total`, `tip_total`, `dispatch_total`, `contracts_completed`, `contracts_failed`, `precise_stops`, `impacts`, `stops_served` and `boarded` for results and review.

Parent integration owns main/HUD/AI. The bus handling agent supplies approach speed, impact age, braking and steering telemetry. The district agent supplies real road distances and dynamic stop arrays. Gameplay code must not assume six stops or an orthogonal street grid.

## Hypotheses and evaluation plan

| Hypothesis | Evidence to gather | Failure sign |
| --- | --- | --- |
| Express gives meaningful control over the manifest | Compare always-fill and selective policies on identical seeds; delivered/boarded ratio, destination diversity, cash and dwell fraction | Express is strictly worse everywhere, or strictly dominates with no tradeoff |
| Optional dispatch creates a different route commitment | Compare ordinary greedy and dispatch-aware policies; jobs accepted/completed, route changes, service stops and travel time | Jobs are impossible, unnoticed, or merely free cash on the same route |
| Shorter dwell improves pacing | Measure fraction of shift spent boarding/alighting and typical dwell | Waiting still dominates or players cannot understand the boarding state |
| Larger map supports local shifts | Measure route distance, completion ratio, variety of visited areas, and whether offers have feasible graph budgets | Random cross-map cargo cannot be delivered before timeout |
| Driving rewards are understandable | Inspect real runs for precise-stop and lost-tip feedback | Normal braking gets punished, rewards can be farmed, or feedback obscures driving |

## Iteration log

### Round 1 — implementation candidate

Implemented local clustered queues, selective express boarding, explicit shared dispatch offers, passenger tips and docking/impact hooks. Next: rules tests and policy simulation on the real enlarged graph, followed by rendered integrated playtests. No claim of improved fun yet.


### Round 1 — macro policy experiment on the original six-stop map

Six fixed seeds were simulated with the real road-distance API and three greedy rivals. Movement is abstracted as graph travel time at 18 m/s for the player, 14 m/s for rivals, plus a 1.5-second trip overhead. This evaluates scheduling and pacing; it omits physical collisions and human reaction time. Results in `gameplay_experiments/policy_comparison_6stops.json` are retained as an early checkpoint, not the final balance verdict.

The first candidate gave always-fill about HK$1,991 and 70 deliveries with 19.8% of the shift in service; pure express about HK$1,370 and 48 deliveries with 14.3% in service; dispatch about HK$1,712 and 34 deliveries with 10.6% in service and 4.7 completed jobs. Pure express improved delivered/boarded ratio (0.974 versus 0.935) but lost on earnings for all six seeds. Dispatch beat always-fill on one seed. **Interpretation:** a small, densely connected map lets the greedy bus resolve a mixed manifest cheaply. Express is not yet a universally attractive choice and must be reviewed on the larger network; it should remain a situational tool rather than a hidden requirement.

An experiment-quality issue was found: dispatch generation originally consumed the same random stream as public demand. Accepting a job could therefore change later ordinary passenger spawns. Dispatch now has its own seeded random generator, preserving an identical exogenous public-demand stream across policy comparisons. Later experiment files supersede the first checkpoint's exact values.

### Ideas deliberately not added in Round 1

- A global cash multiplier was rejected: it would inflate scores without changing which route is sensible.
- Boost that consumes passenger comfort was deferred: it introduces another resource before the basic express/dispatch choice has been made readable.
- Removing base fares when a passenger is late was rejected: on a much bigger map it would turn imperfect planning into unpaid cargo and encourage resets.
- Button-mashing to board faster was rejected: it adds busywork to the waiting problem. Faster default service and destination selection give the player a useful decision instead.

### Round 2 — twelve-stop district and driving-speed sensitivity

The enlarged Sheung Wan–western Central graph now has twelve stops across 1,120 × 660 metres. The same six paired seeds were run at 18, 14 and 10 m/s player cruise speed; rivals remain at 14 m/s. Every run includes the 0.65-second door-opening grace, 0.25-second boarding and 0.17-second alighting. These are **abstract graph-time runs**, not physical driving or human playtests. They do not establish fun.

| Player cruise | Mixed cash / deliveries | Express cash / deliveries | Dispatch cash / deliveries | Dispatch jobs |
| --- | --- | --- | --- | --- |
| 18 m/s | $1,465 / 47.5 | $1,421 / 46.5 | $1,667 / 31.0 | 4.00 |
| 14 m/s | $1,312 / 43.2 | $1,152 / 37.5 | $1,308 / 21.0 | 3.50 |
| 10 m/s | $1,056 / 36.3 | $911 / 30.8 | $943 / 17.8 | 2.17 |

Reports: `gameplay_experiments/policy_comparison_12stops_18mps.json`, `..._14mps.json`, `..._10mps.json`. The reproducible runner is `tests/simulate_gameplay.gd -- --cruise=14`.

Express delivered roughly 93–94% of riders boarded, versus 70–79% for mixed loads. Dispatch delivered about 85%. Service occupied approximately 7–16% of the full shift across these policies and speeds. Mixed runs visited 5.8–7.5 distinct stops on average, express 6.0–6.7, dispatch 4.7–5.7. The larger map supports a local subset of stops per shift. Dispatch rewards driving efficiency and loses its earnings advantage at slower speeds, while still offering about two completed jobs at 10 m/s. **Decision: retain current fares and dispatch rewards.** Express is a situational manifest-control tool, not a guaranteed earnings upgrade; physical controls and legibility should be tested before balancing it with an artificial bonus.

A second harness error was corrected before these final numbers: after accepting a new dispatch whose pickup was the current stop, the scheduling agent could depart without collecting the party. It now stays to board that party, updates its express destination, and avoids unrelated boarding at a non-pickup stop while collecting. Earlier slower-speed dispatch results understated the policy because of this agent bug. The independent physical runner was notified and includes the same guard.

### First 45 seconds and final-minute review

This is a code and scheduling-log review pending rendered physical playtests. At 14 m/s on seed 41, mixed and express policies make three departures within the opening 39 seconds. The dispatch policy accepts at 0 seconds, departs with its party around 4 seconds, and accepts its next job at 19 seconds. There are already frequent route decisions; adding another resource or surprise event would risk hiding the existing choices.

The opening experience should expose, in priority order: current pickup/destination and route, boarding mode and matching queue count, then the optional dispatch alternatives. The separate express destination avoids accidentally selecting the current pickup as a drop-off. Showing queue mix on approach, selecting express directly from a destination row, and the door-opening grace give players a chance to choose before the queue disappears into the bus. The grace alone is too short to teach the system; approach visibility and the initial instructions matter.

Recommended readability work for the integration owner:

- Show travel cost or feasibility on dispatch offers before acceptance, in addition to the bonus. Dim a job that cannot fit the remaining shift and explain why. A clickable offer that only reports failure after selection wastes attention.
- Give reserved parties a consistent gold ticket or briefcase marker shared by their waiting group and active-job panel. Give commuters a secondary small clock cue; ordinary riders need no extra marker. This matters more than a cosmetic horn-wave response.
- Preserve active pickup versus delivery phase and partial-party progress. A full bus should clearly say it must unload before the rest of its reserved group can board.
- In the final 30 seconds, foreground current onboard drop-off counts. A brief “Last fares—deliver onboard riders” cue is sufficient; do not add a new scoring rule. Existing no-new-offers cutoff at 38 seconds and acceptance feasibility checks already prevent late compulsory commitments.

The abstract express agent sometimes boards at 177 seconds despite being unable to finish another trip. That is an intentionally simple policy limitation, not evidence that normal fares need changing. A human should be able to identify this bad choice from remaining time and route length. The results breakdown should explain unearned optional bonuses without confiscating valid base fares.

The dispatch quote API was added after the readability review. Rules validation now passes 320 checks, including quote/accept deadline agreement, unavailable versus too-late states, and proving that merely quoting does not claim or spawn a party.

### Round 3 — rendered UI review (staged positions, not a driving benchmark)

Reviewed `captures/v2/03_approach.png`, `04_boarding.png`, `05_city_map.png`, `06_dispatch.png` and `08_results_fixture.png`. The capture harness uses actual game methods and UI input but stages vehicle positions and the results ledger. These images establish layout and visible state, not accessibility through driving or improved fun.

The map now makes the district's street network and a selected route readable. Boarding shows a coherent manifest, the destination mix can be selected directly, gold reserved-party markers are visible in the world, and the results clearly reconcile base fares, tips, bookings and medal bonus into banked cash. Those are useful foundations for human review.

Priority issues sent to the integration owner:

1. **Reserved-party override must be explicit.** In the dispatch capture, the active job says pickup Western, 1/4 aboard, and the manifest gains an MTR passenger, while the large boarding status still says “EXPRESS BOARDING → BONHAM.” The rules are valid but the presentation looks contradictory. While the reserved party boards, use a status such as “DISPATCH PARTY → MTR • 1/4 aboard”; retain the smaller express sign for later public boarding.
2. **Keep the clock visible on the city map.** Time runs while the map is open, but the timer is hidden and only a small footer warns about it. This makes route planning deceptively expensive. A visible remaining-time display is sufficient; do not silently change pause semantics.
3. **Distinguish the express sign from the navigation pin.** The map's plain “E EXPRESS” button omits the actual express destination. Because these are deliberately separate states, show the current destination and the toggle action clearly.
4. **Explain automatic service at first approach.** “Choose a stop on the map” is less immediately useful than “Brake inside the bay to board automatically” when the player is already approaching a pickup. Change the queue heading from “APPROACHING” to “AT” during actual service.
5. **Use player-facing deadline language.** Offer text such as “40s time budget” can be mistaken for predicted trip duration. “40s deadline after accepting” makes the commitment clearer. The map list's “0 aboard” would be clearer as “0 to drop”; update the map legend if the player marker is gold rather than white.

The approach image's bus against a wall is a staging-fixture issue identified by the parent and driving agent; it should not be cited as evidence of normal spawning or handling. The results image's zero distance is likewise fixture data, not a gameplay result. Physical policy reports remain necessary before judging route pressure, stop accessibility and actual control effort.
