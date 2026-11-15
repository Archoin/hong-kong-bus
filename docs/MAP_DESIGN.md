# Sheung Wan → western Central map design

The rebuilt map uses actual OpenStreetMap road and building geometry rather than a repeated rectangular lattice. The playable bounds are 1,120 × 660 game metres (739,200 m²), versus the previous 260 × 218 (56,680 m²): 13.04× bounding area, 11.48× land area after the sampled harbour cutout (650,909 m²; buildings included). Horizontal projection is 0.8× real local metres, centred at 114.1515 E, 22.2858 N. Streets retain their relative alignment and names; the map is a playable adaptation, not navigation data.

## Evidence and reference board

Open [the visual reference atlas](map/reference_atlas.html) for actual map geometry, linked street photographs and game comparison captures. [Geographic atlas](map/geographic_atlas.png) is generated from the same source as the playable scene.

- [Hong Kong Lands Department: Sheung Wan / Central map](https://www.landsd.gov.hk/doc/en/mapping/ehkg/MapPages/GeoPDF/HK03_SheungWan_CentralDistrict.pdf).
- [MTR Sheung Wan street map](https://www.mtr.com.hk/archive/ch/services/maps/shw.pdf).
- [HKU Hong Kong in Transition: Des Voeux Road, 9 December 2015](https://arthistory.hku.hk/HKinTransition/image_detail.php?id=25793). Inspected street photograph: continuous shop façades, AC rows, projecting Chinese signs, tram rails and overhead wires; pedestrians tightly share the shop edge.
- [HKU: Bonham Strand street market](https://arthistory.hku.hk/HKinTransition/image_detail.php?id=76634). Reference for awnings and shop spill-out.
- [Western Market exterior reference archive](https://commons.wikimedia.org/wiki/Category:Exterior_of_Western_Market). Original geometry uses red brick, cream bands and tall window groups.
- [OpenStreetMap copyright and ODbL](https://www.openstreetmap.org/copyright).
- [Open-Meteo elevation API](https://open-meteo.com/en/docs/elevation-api), Copernicus DEM GLO-90.

HKU photographs are research references, not game textures. The reference HTML links the original images; no photographs are included in exported game assets. All rendered materials and street props are original procedural geometry.

## Distinct driving areas

1. Des Voeux Road is the broad tram spine: long sightlines, wires, rails, moving double-decker trams and nearby commercial stops.
2. Bonham Strand / Wing Lok / Jervois form an irregular trading network: short blocks, curved corners, food and dried-seafood shops, multiple route choices.
3. Hollywood / Tai Ping Shan climb above the commercial belt: narrower curved roads, Man Mo Temple, the park and pedestrian-only stairs.
4. SoHo / Aberdeen / Gage add hill approaches and compressed junction decisions near PMQ.
5. The harbour edge opens the skyline: Macau Ferry Terminal, seawall, piers and Connaught viaduct distinguish the northern fast corridor.

There are 12 real-place stop destinations. Service positions sit inside the left curb lane; pedestrian queues and shelters sit beyond the road edge. Roads use a shared connected graph; pedestrian steps are absent from bus routing. Passenger clustering and express trips can use actual shortest route distances.

## Geometry and implementation

`tools/import_map.py` processes the retained OSM XML and elevation grid into `assets/map_data/district.json`. The dataset contains 2,477 graph nodes, 2,558 road segments, 822 clipped and deduplicated building footprint parts and 12 stops. Source building polygons are clipped to widened road corridors plus sidewalk clearance. Road widths are 11.5–26 game metres. Buildings use original procedural façades with physical shopfronts, awnings, air conditioners, projecting signs and occasional bamboo scaffolding.

The elevation source is a coarse surface model rather than survey-grade bare earth. It is smoothed twice, scaled and grade-limited to remove building noise and keep bus driving comfortable. The waterfront approaches are low; Hollywood/SoHo rise continuously. Road surfaces, terrain collision, vehicle placement and route heights sample the same function.

`tools/build_city.gd` bakes the scene with a rendered Godot process. Headless baking is intentionally rejected because renderer-less MultiMesh serialization loses transforms. The source dataset is loaded by `scripts/district.gd`; the static architecture is stored in `scenes/district.tscn`.

Stable APIs: `STOP_NAMES`, `STOP_SHORT`, `STOP_POS`, `STOP_COLORS`, `STOP_ZONES`, `MAP_BOUNDS`, `SPAWN_POSITION`, `SPAWN_HEADING`, `road_segments`, `road_height`, `nearest_road`, `route`, `lane_route`, `road_distance`, `stop_distance`, `stop_tangent`, `stop_curb_position`, `district_name_at`, `tram_routes`.

Tram routes are extracted from actual `railway=tram` source geometry, separately from the car graph (237 sampled points). This preserves the real Connaught/Cleverly corridor without making trams take car-routing detours. Rendered track pairs are centred at ±2.075 metres from the street centreline; moving trams use those same offsets.

## Review status

- Source geometry imported and inspected as a map atlas.
- Actual Des Voeux street photo inspected before façade design.
- New routing API integrated by the main and gameplay agents.
- Full city bake completed: 822 footprint parts, 1,400 detailed shopfront edges and 69 instanced material batches before the final rail-alignment pass. Final rail screenshots are being reviewed.


## Iteration evidence

- All 132 directed stop pairs have connected road routes. Minimum/maximum shortest stop distance in the current dataset: 96.05 / 981.61 game metres. `tools/test_map_graph.gd` verifies this and a nonempty tram spine.
- A physical driving run found a collision at Hollywood Road near (-266, 32). Flat-capped buffers around individual road segments left a needle-shaped building remnant at the bend. The importer now uses round caps and continuous union setbacks. Nearest building clearance at the failure coordinate increased from 3.04 m to 6.02 m; the driving agent then crossed the location and continued through Man Mo / Cat Street / PMQ. These were actual steering/physics runs, not teleports.
- Duplicate OSM outline/building-part geometry caused coincident façades. Overlap filtering reduced 978 footprint parts to 822 and removed their redundant collision.
- First overview showed severe façade aliasing and overbright lighting. The façade shader now divides direct light by π, antialiases window boundaries and blends fine window detail at distance.
- First bake accidentally rendered the collision boundary volumes as tall walls. Their rendering was removed; invisible boundary collision remains, with visible maintenance barriers at road exits and distant continuation buildings.
- Road markings now follow the union of drivable street polygons, avoiding yellow stripes across junctions. Road strips are sampled in ≤3 m cells. Visual ground is lowered 0.18 m while the collision surface remains unchanged, preventing coarse terrain triangles from covering asphalt on slopes.
- Man Mo Temple's orientation was corrected against its actual footprint. Its roofs now use pitched green geometry with tile ribs. Adjacent Lit Shing Kung is a low temple wing rather than an automatically assigned modern tower. [The Antiquities and Monuments Office describes the three-block compound](https://www.amo.gov.hk/en/historic-buildings/monuments/hong-kong-island/monuments_96/index.html).

## Practical limits

This is a toon driving district, not a surveyed digital twin. OSM roads include separate carriageways, so the 20.25 km sum of graph edge lengths is not a distinct-street-length measurement. Building heights use available OSM metadata and deterministic estimates where absent. PMQ and Central Market are geographic destinations, but their architecture is simplified rather than a detailed reconstruction. Road regulations and one-way restrictions are intentionally omitted for arcade route planning. The source photograph board should be opened with network access; photographs remain hosted by their owners.

### Final transform correction

Visual review exposed a transform-order defect in generated rotated boxes and beams. The generator now multiplies rotation by local scale (`rotation * Basis.from_scale(size)`) rather than scaling world axes after rotation. Collision boxes already used the intended local dimensions and rotation; this correction brings rendered walls and structural details into agreement with them. It does not change the tested road or building collision geometry.
