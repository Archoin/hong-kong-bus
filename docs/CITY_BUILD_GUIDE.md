# City Build Guide — for Codex Astra

**Audience:** Codex Astra (the coding agent building the city). **Owner:** the game's designer.
**Status:** v2, 2026-11-16. Replaces the "generate everything in GDScript" approach in [MAP_DESIGN.md](MAP_DESIGN.md) for *visual* city content. Roads, routing and collision stay as they are.
**Background and evidence** (screenshot-vs-photo comparison, other people's approaches, reusable tools/content, reference photos) is in [CITY_RESEARCH.md](CITY_RESEARCH.md). You do not need it to build; use it when a decision here needs justification or when you look for references.

> **Goal:** the city reads as *Sheung Wan, Hong Kong* from the bus driver's seat: dense, vertical, layered, cluttered, colourful. Building geometry comes from the **Lands Department 3D data**; detail, props and street blocks are authored in **Blender**, exported as **GLB**, and assembled in **Godot** around the existing, tested road network.

---

## 1. Owner decisions (2026-11-16)

| Topic | Decision |
|---|---|
| Building geometry | **Use the Lands Department meshes directly** (repo, Git LFS). **Simplify only if performance becomes an issue.** |
| Renderer | **Not `gl_compatibility`.** Move to Forward+ (§9.1). |
| Scope | **Static buildings and street blocks only.** No ambient traffic, parked vehicles or pedestrians this milestone. Existing trams, rival buses and stop queues stay. |
| Art direction | **Undecided.** Working default: stylised toon with real proportions and real clutter. Phase 0 shows two looks (A flat toon, B painterly) and the owner picks. Keep geometry and look separable (§7). |
| Heroes | **More heroes**, tiered (§6). |
| Night | **Yes, a night variant is planned.** Build night-ready from the start (§9). |
| Git LFS | **Yes.** Already set up (`.gitattributes`); new binaries (`.blend`, block `.glb`, atlases, raw data zips) go to LFS. |

## 2. Rules

1. **Gameplay data stays in Godot.** `assets/map_data/district.json`, `scripts/district.gd` (`road_height`, `nearest_road`, `route`, stops…) and road collision are the source of truth. Do not change road geometry, stop positions or the 0.8× horizontal projection to suit art. If art needs a different road, ask the owner.
2. **Do not extend `tools/build_city.gd`'s building code.** Keep its `terrain()`, `roads()`, markings, rails and stop furniture; its `building()` output is replaced by blocks and then removed. It remains the fallback only for areas without a Lands Department sheet yet.
3. **Source of building geometry = Lands Department meshes** (§3). Detail on top (§5) and landmark work (§6) are authored in Blender. Every export is reproducible by a script (`blender --background --python …`, like `tools/build_bus.py`); sources live under `tools/source/city/`, outputs under `assets/city/`.
4. **1 unit = 1 m, Y up in Godot, floor height 3.0 m.** Mind the axis mapping (§8.2).
5. **Never commit a giant generated `.tscn`.** `scenes/district.tscn` is 41 MB of inline meshes. The new city is a small scene that *instances* GLBs by path.
6. **Forward+, not Compatibility** (§9.1). Forward+ features (SSAO, SSIL, SDFGI, volumetric fog, glow, TAA/FSR2…) are allowed, but each needs a before/after capture and a frame-time measurement. Draw-call discipline still applies.
7. **Prove the pipeline on ONE block first** (Phase 0). Stop and show the owner side-by-side screenshots before continuing.
8. **Evidence, not opinion.** Compare every iteration against real reference photos ([CITY_RESEARCH.md](CITY_RESEARCH.md) §B) using fixed camera shots (§10). "Looks better" is not evidence.
9. **Originals or CC0 only for textures; no photos, no real logos or shop names.** Reference images are for looking at. Never use Google/Cesium data. Log every third-party item in `docs/ASSET_LICENSES.md`.
10. **Don't be abusive to public services** (§3 etiquette). Download each Lands Department sheet once and commit it.
11. **Every asset must be rebuildable from committed scripts and sources.** No hand-only steps.

---

## 3. Data: Lands Department 3D meshes

**What we have.** Sheet `11-SW-8A` (non-textured glTF) is in the repo: `tools/map_source/landsd/raw/11-SW-8A_GLTF0.zip` (Git LFS; run `git lfs pull` after cloning). `python3 -I tools/city/landsd_index.py 11-SW-8A` extracts it to the git-ignored `tools/map_source/landsd/extracted/11-SW-8A/` and writes `assets/map_data/landsd_11-SW-8A_index.json` (id, game x/z, ground, height, tris, file). Provenance, SHA-256 and the download route are in `tools/map_source/landsd/SOURCE.md`; licence and attribution in `docs/ASSET_LICENSES.md`.

**Coverage.** `11-SW-8A` covers the western half of the game map (game x −418…64, z −300…80): Western Market, Bonham Strand, Dried Seafood Street, much of the waterfront. The eastern half and the Hollywood / Man Mo / PMQ hills are in neighbouring 1:1000 sheets (expect roughly 3–5 sheets in total). Get each one **when the phase that needs it starts**.

**What the sheet contains.** 762 buildings, one glTF each (`BUILDING/<id>/<id>.gltf`), 376k triangles in total (median 249, max 19.6k; 23 buildings above 2,000). Heights: 493 below 30 m, 112 at 30–60 m, 130 at 60–100 m, 27 above 100 m. Real podium/tower steps, set-backs, pitched roofs, colonnades, some recessed windows. **Untextured, one material, vertex colour, no facade detail** (no balconies, AC units, signs, shopfronts). Also `INFRASTRUCTURE` (11) and `TERRAIN(TB)` (half the data): ignore both. Each building's root node matrix is in **HK1980 Grid** metres: translation = (Easting, ground height, −Northing); mesh local axes are x east, y north, z up. The conversion in `landsd_index.py` was validated against OSM footprints (median offset ≈0.5–1 m).

**Preview** of the raw data: `captures/landsd/westernmkt_top.png`, `westernmkt_oblique.png`.

**Why it matters.** A crude comparison with our current OSM-based building heights showed almost no correlation (r ≈ 0.05; 62 % differ by more than 10 m; surveyed median 25 m vs. our 33 m). Our skyline is too tall. Redo the comparison by polygon overlap as part of Phase 0 and replace our heights/volumes with the surveyed meshes.

### Required conversion (geometry stays as is)

1. **Material.** Each glTF has one default material and `COLOR_0`. Assign our atlas/toon material (§9) to every mesh. Add UVs only where the atlas needs them (box-projected walls with per-floor repeat); that is an attribute change, not simplification.
2. **Scale.** Real heights, but our horizontal projection is **0.8×**: scale x/z by 0.8, keep y (as `landsd_index.py` and the preview did).
3. **Ground.** Surveyed ground differs from our smoothed terrain (`D.road_height`). Snap each building's base to game terrain and add a foundation skirt (§8.2). Do not edit the walls.
4. **Road clearance.** Roads are widened, so some meshes will intrude into road corridors. **Do not move or shrink roads.** Test each building against the road corridor (as `tools/import_map.py` does). For the few that intrude, trim only the intruding part (Blender boolean/bisect) or, if cheaper, nudge the whole building out. Reuse the Hollywood regression (−266, 32) and the physical driving run (§10).
5. **Ignore** `INFRASTRUCTURE` and `TERRAIN(TB)`.
6. **Group into street blocks** (§4). Merging meshes per block for draw-call reasons is encouraged, preserving each building's geometry.

### Performance-driven simplification (only if needed)

Trigger: a profiler capture shows a block over budget (§8.4) or a frame-time spike traced to a mesh. Remedies in order: (a) visibility ranges and occluders, (b) LOD1 (Godot automatic mesh LOD or Blender decimate on distant versions), (c) merge per block, (d) decimate or rebuild the specific heavy buildings (the 23 above ~2,000 tris: podium complexes, multi-storey car parks). Record the measurement that justified each change in `docs/VALIDATION.md`. **Do not pre-emptively simplify.**

### Fetching more sheets (etiquette)

- **Route:** `https://download.map.gov.hk/api/3d-zip/GLTF0/<SHEETNO>.zip` (`GLTF0` = non-textured glTF). Sheet numbers/polygons come from LandsD's sheet index (mirror: [Dorian1729/3D-Visualisation-Map](https://github.com/Dorian1729/3D-Visualisation-Map)); the URLs in that index carry a public key. Intersect our game bounds (with ~200 m margin) with the polygons to list the sheets needed. Do **not** use the 3D Tiles API (needs a key from `3dmap@landsd.gov.hk`).
- **Dry-run first:** print the sheet list and sizes; tell the owner if the total exceeds ~500 MB.
- **One sheet at a time**, one request each, descriptive `User-Agent` naming the project (no personal details), pause between requests, resume with `curl -C -` (the server is slow, ≈70 KB/s, but supports `Range`), back off on 429/5xx, never loop or poll, never re-download a file whose checksum matches.
- **Commit** the zip under `tools/map_source/landsd/raw/` (LFS) and update `SOURCE.md` and `docs/ASSET_LICENSES.md`.
- **Attribution** is required: "3D building data: © Lands Department, HKSAR Government, via DATA.GOV.HK" (confirm the wording on the dataset page). Add it to the README geographic-attribution section and the in-game credits when derived data ships. Do not strip attribution notices. The terms include an indemnity clause and a fair-usage policy; the owner has reviewed and cleared use.

---

## 4. Architecture and pipeline

```
 tools/map_source/landsd/raw/<sheet>.zip ─▶ tools/city/landsd_index.py ─▶ assets/map_data/landsd_<sheet>_index.json
 assets/map_data/district.json (roads, terrain, OSM footprints for areas without a sheet)
                                   │
 tools/city/export_blocks.py  (Python, no Blender): assigns buildings to street blocks, writes per-block JSON + height grid
                                   ▼
 tools/source/city/kit.blend ─▶ tools/city/build_blocks.py  (Blender --background)
 (detail kit, props, heroes)     - imports each building's glTF, applies the §3 conversion
                                 - adds the detail layer (§5), pavements, props
                                 - writes assets/city/blocks/block_<gx>_<gz>.glb (+ optional _lod1)
                                 - writes assets/city/city_index.json (centres, bounds, hero list)
                                   ▼
 tools/city/assemble_city.gd  (Godot, rendering on): instances blocks into scenes/city/district_blocks.tscn,
 adds visibility ranges, occluders, collision, lights
                                   ▼
 scripts/district.gd, roads, stops, trams, buses (unchanged)
```

| Layer | Owns | Where |
|---|---|---|
| Gameplay-critical | Roads, markings, rails, stop bays, routing, collision, terrain function `D.road_height()` | Godot (existing `tools/build_city.gd`, `scripts/district.gd`) |
| Visual city | Buildings (LandsD meshes + detail layer), heroes, pavements/kerbs, signs, guardrails, lamp posts, planters, scaffolding | Blender → GLB |
| Dynamic | Trams, buses, queues (unchanged) | Godot |
| Atmosphere | Sky, fog, light, harbour, far skyline/hills | Godot `WorldEnvironment` + a few far-LOD Blender meshes |

**Street block** = a group of adjacent buildings bounded by roads, plus the surrounding pavement. Build by connected components of footprints after buffering ~2 m; split any block wider than ~120 m on a grid. Target **~60–120 block files** for the whole map. Name by 100 m grid index of the centroid, `block_<gx>_<gz>.glb`, so names are stable across re-exports. Heroes are separate files (`assets/city/heroes/*.glb`) that replace their filler building. Blocks, not single buildings, are the unit for visibility ranges, occluders and LOD, and are easy to hand-polish in Blender.

**Areas without a sheet yet.** Until a sheet is committed, that area keeps the existing generated buildings (rule 2) or uses the footprint-based fallback generator. Do not spend effort polishing the fallback; get the sheet instead.

---

## 5. Detail layer (on top of the meshes)

The Lands Department meshes give silhouette and height. The detail below is what makes it Hong Kong. Build it as separate meshes placed on the building's road-facing walls, ground footprint and roof, **not** by editing the LandsD geometry. Derive each building's footprint from its lowest vertices (or from the matching OSM footprint) and its road-facing edges with `D.nearest_road`.

**Priority list**

1. Roof clutter on ≥ 70 % of roofs: water tank, rooftop hut, antenna, sign frame.
2. Layered shopfronts on road-facing ground floors: shutter / glass / fascia sign / canopy / spill-out goods; **minimum clear pavement 1.8 m**.
3. Balconies, **AC units in irregular clusters** on ledges and racks (never a neat grid), window grilles/cages, pipes.
4. Blade signs and lightboxes across the street, real bilingual lettering; project ≤ 2 m over the carriageway, start ≥ 4.5 m above ground (bus roof is ~3 m; the chase camera must not clip them).
5. Lot variety: where a facade is long, break it into **4–8 m lots** with different paint, balcony type and signage (seeded from the building id so it is deterministic).
6. Pavement: brick-paver strip, kerb 12–15 cm, tactile strip, manholes; lamp posts every ~25 m, pedestrian guardrails near crossings and stops, traffic lights, road/street-name signs, hydrants, bins, bollards, planters and trees.
7. Bamboo scaffolding with green/black netting on ~1 in 15 buildings.

**Facade families** (assign by height and location; each with ≥ 6 colour variants and 3 window/balcony arrangements):

| Family | Heights | Where | Signature |
|---|---|---|---|
| Tong lau / old tenement | 4–7 floors | Hollywood Rd, Bonham, Wing Lok, Cat Street | Cantilevered balconies, shutters, narrow lots, rooftop huts, exposed stairs |
| Post-war mid-rise | 8–18 floors | Des Voeux, Queen's Rd, Bonham | Ribbon windows/grids, tile podium, AC clusters, tanks, big shop fascia |
| Commercial podium + tower | 20–45 floors | Waterfront, Central edge | Tile/curtain-wall podium, spandrel bands, plant rooms |
| Heritage / civic | 2–6 floors | Western Market, PMQ, Central Market, Man Mo | Hero (§6) |

Floor height 3.0 m, bay widths 2.4 / 3.0 / 3.6 m, ground floor 3.6–4.2 m. Use Geometry Nodes or plain `bpy`, whichever is easier to keep **seeded and deterministic** (same inputs → byte-identical GLBs). Apply modifiers and realize instances before export.

---

## 6. Heroes

Start from the **Lands Department mesh** of each building wherever a sheet covers it (used as is, no pre-emptive decimation), convert it as in §3, then add our detail (signs, lettering, awnings, balconies, roof ornaments) as separate meshes. Where the data is missing or wrong (e.g. temple roofs), model by hand. Each hero is its own `.blend` under `tools/source/city/heroes/`, one shared atlas. Check massing, height and roof shape against the data and the reference photos before calling it done. Locate every building in `district.json` (`buildings[].name`) and confirm it is inside the map bounds first.

**Tier A — stop landmarks (build first; they drive the first screenshots):** Western Market (stop 1; red-brick Edwardian, cream string courses, arched openings, turret); Man Mo Temple + Lit Shing Kung (stop 8; grey brick, green-tile pitched roofs with ridge ornaments, lanterns, incense coils); Central Market (stop 10) and PMQ (stop 9); Sheung Wan Municipal Services Building and the MTR station entrance/vent shaft (stop 12); Macau Ferry Terminal / Shun Tak Centre (stop 2); Hollywood Road Park pavilions and gate (stop 6); Dried Seafood Street corner block (stop 4; a hand-polished tenement block, not a landmark).

**Tier B — recognisable street-level buildings:** Sheung Wan Fire Station, Ying Wa Girls' School, Rumsey Street Multi-Storey Car Park, Wing On Centre, Cosco Tower, Hang Seng Bank Headquarters, Infinitus Plaza, plus any other named building near a stop or route with a distinctive silhouette. Propose additions to the owner with a screenshot before modelling.

**Tier C — skyline (far LOD only):** The Center (346 m), IFC, Exchange Square, China Merchants Tower, Man Yee / Midland Plaza and other towers above ~100 m.

---

## 7. Art direction

- **Working default:** stylised toon with real proportions and clutter, three-band toon lighting, silhouette first, texture second. **The final look is undecided**, so keep geometry and look separable: blocks export geometry + UVs + vertex colour; the look lives in a swappable material/atlas. Phase 0 renders the same block in **look A (flat toon atlas)** and **look B (more painterly/realistic atlas, still original or CC0)** so the owner can choose.
- **Palette:** from the photos — ochre/orange, mint/jade, maroon, off-white, grey tile, teal glass. ≥ 8 body colours and ≥ 6 accents (fascias, awnings). Remove the current pastel teal wash (less fog, lower ambient, more sun contrast).
- **Text:** bilingual Chinese + English signs from invented, generic names (extend `SHOPS`/`ENGLISH` in `build_city.gd` by ~40). Bake text into a sign atlas or small meshes; no hundreds of `Label3D`.
- **Textures:** paint or procedurally bake your own atlas; CC0 sources (Poly Haven, ambientCG) may be baked in. See [CITY_RESEARCH.md](CITY_RESEARCH.md) §D.

---

## 8. Blender spec

### 8.1 Environment
Blender **5.2.2 LTS** (`/Applications/Blender.app/Contents/MacOS/Blender --background --python …`), Godot **4.6.1** (`/Applications/Godot.app/Contents/MacOS/Godot`). Sources: `tools/source/city/kit.blend`, `heroes/<name>.blend`, optional `blocks/block_*.blend`. LFS is configured; run `git lfs pull` on a fresh clone.

### 8.2 Scale, axes, origin, terrain
- 1 Blender unit = 1 m; apply scale/rotation before export.
- **Axes:** Godot `(x, y_up, z)` ↔ Blender `(x, −z, y_up)` (the glTF exporter's +Y-up maps Blender `(x, y, z)` → glTF `(x, z, −y)`). A LandsD building's local axes (x east, y north, z up) already match Blender; place it at Blender `(game_x, −game_z)`. Verify in Phase 0: block centre in Godot equals `city_index.json` within 5 cm, and a known corner (Western Market polygon) overlays the OSM polygon.
- **Origin:** block origin = centroid at ground height (`D.road_height`); `assemble_city.gd` places the instance there; vertices are local.
- **Terrain:** export a height grid from Godot (`D.road_height` at 2 m → `assets/map_data/height_grid.json`); the Blender script drapes pavement and building bases on it with a ≥ 3 m foundation skirt and stepped podiums on steep lots.

### 8.3 Export checklist (glTF)
Per [Godot's export notes](https://docs.godotengine.org/en/4.4/tutorials/assets_pipeline/importing_3d_scenes/model_export_considerations.html): **.glb, +Y Up, Apply Modifiers, Selected Objects only** (no cameras/lights/reference meshes); image textures or vertex colour only (procedural node materials don't export; bake first); **no Draco**; triangulate; apply scale/rotation; outward normals, no loose vertices. Collision-name suffixes (`-col`, `-colonly`, `-convcolonly`, `-noimp`) work on mesh nodes ([docs](https://docs.godotengine.org/en/4.2/tutorials/assets_pipeline/importing_3d_scenes/node_type_customization.html)); **do not rely on them for buildings**: building collision is generated in Godot from the footprints (convex prisms, as `build_city.gd` does), which is tested and keeps routes drivable. Verify collection-instance/linked-library behaviour with a small test file before relying on it.

### 8.4 Budgets (starting targets; confirm by profiling)
| Item | Target |
|---|---|
| Materials per block | ≤ 3 (opaque atlas, glass/emissive, signs); no alpha-blended facades |
| Textures | 1–2 shared atlases, 2048–4096 px; palette variation via vertex colour or per-instance shader parameter |
| Triangles per block (LOD0) | ≈ 60k–150k; hero blocks may exceed |
| GLB size per block | ≤ 3 MB |
| Visible draw calls in the chase view | ≲ 1,500 |
| Frame rate | stable 60 fps on the owner's M-series Mac, standalone build |

---

## 9. Godot spec

New files (don't repurpose `build_city.gd`): `tools/city/export_blocks.py`, `tools/city/build_blocks.py`, `tools/city/assemble_city.gd` (run with rendering enabled; headless loses MultiMesh buffers), `scenes/city/district_blocks.tscn` (small; references `res://assets/city/blocks/*.glb`), `tests/test_city_blocks.gd`.

### 9.1 Renderer migration (first task of Phase 0)
1. `project.godot`: `renderer/rendering_method="forward_plus"`; replace feature `"GL Compatibility"` with `"Forward Plus"`; remove `renderer/rendering_method.mobile="gl_compatibility"`.
2. Check the macOS export preset in `export_presets.cfg` still exports with matching 4.6.1 templates; rebuild `builds/`.
3. Re-run `./tests/run_checks.sh` and a **rendered** `tools/playtest.gd` (headless tests don't exercise the renderer).
4. Re-capture the standard shots against `captures/map_*.png`. Inspect `toon.gdshader` and `facade.gdshader` (custom `light()` using `DIFFUSE_LIGHT`; shading, shadows, `fwidth` antialiasing), `Label3D`, fog, MultiMesh, sun shadow bias, MSAA.
5. Update `docs/VALIDATION.md` (it says Compatibility) and README; record a Forward+ frame-time baseline.
6. If Forward+ fails somewhere, report it; never silently fall back.

### 9.2 Rules
- **Import:** default scene import; *Generate LODs* where useful; no skins/animation; commit `.import` files.
- **Visibility ranges:** LOD0 `visibility_range_end ≈ 220 m` with fade; LOD1 200–600 m; hide props beyond ~120 m.
- **Occlusion:** one `OccluderInstance3D` per block (box/prism from footprints); tall dense blocks suit it ([Godot docs](https://docs.godotengine.org/en/4.4/tutorials/performance/optimizing_3d_performance.html)).
- **Instancing:** repeated props (lamps, guardrails, bins, planters, trees) as `MultiMeshInstance3D` per block; automatic instancing helps only opaque/alpha-tested identical mesh+material.
- **Shadows:** one `DirectionalLight3D`; directional shadows multiply draw calls ([forum](https://forum.godotengine.org/t/understanding-batching-in-godot-4/65635)); keep `directional_shadow_max_distance` ≈ 160–220 m; consider orthogonal mode.
- **Materials:** reuse the toon look. Convert `facade.gdshader` into an *atlas toon* shader (albedo atlas + vertex colour + three-band light) with a `glass` variant.
- **Night-ready (night variant planned):** atlas emissive-mask channel (windows, shop interiors, lightboxes, signs); sign materials in their own slot so they glow independently; per-window variation; lamp posts as separate nodes ready for a few real lights near the camera (not hundreds). Provide `day` and `night` `Environment` presets (sky, ambient, fog, glow, sun/moon) that `assemble_city.gd` can switch; shader parameters, not duplicate meshes, select day/night. Verify both on the Phase 0 block.
- **Lighting:** dynamic sun + `Sky` ambient, no baked GI at first; Filmic/ACES tonemap; evaluate SSAO, SSIL, glow, SDFGI, volumetric fog one at a time and keep what earns its cost in the capture comparison. Test MSAA vs. TAA/FSR2 on thin features (railings, wires, blade signs).
- **Streaming:** only if memory/load time bites (`ResourceLoader.load_threaded_request`); 60–120 blocks should fit in memory.
- **Old scene:** keep `scenes/district.tscn` until blocks match it for collision/routing, then regenerate it **without buildings** (terrain, roads, rails, stops).

---

## 10. Verification (every phase)

1. `./tests/run_checks.sh` stays green; `tools/test_map_graph.gd` connectivity unchanged.
2. New `tests/test_city_blocks.gd`: every block in `city_index.json` exists and its transform matches; for every building from the sheet, built height equals surveyed height (±1.5 m); bus spawn and all 12 stops keep ≥ 2.5 m clearance; no building collision intrudes on road corridors (Hollywood regression at (−266, 32)).
3. **Physical driving** run (`tools/playtest.gd --policy=express --seed=20261113`) completes without new collisions/recoveries (baseline: 48 deliveries, 0 collisions, 0 recoveries, see VALIDATION.md).
4. **Screenshot pairs:** extend `tools/capture_map.gd` (or add `tools/capture_city_compare.gd`) with fixed shots at stops 1, 4, 5, 8, the Des Voeux tram spine, Hollywood Rd uphill and an overview; save to `captures/city_v<n>/` and compare with the reference photos ([CITY_RESEARCH.md](CITY_RESEARCH.md) §B; links only, never copies in the repo). Re-score the comparison table in [CITY_RESEARCH.md](CITY_RESEARCH.md) §A (✔/✘ per row).
5. **Performance report:** draw calls, triangles, FPS at the same shots in the standalone build, written into `docs/VALIDATION.md`.

Report failures honestly; don't claim a result you didn't measure.

---

## 11. Phases (each ends with green checks, new captures, a note in `docs/VALIDATION.md`, and an owner review)

**Phase 0 — Forward+ and one-block vertical slice.** (1) Migrate to Forward+ (§9.1) and show before/after captures of the *existing* city so renderer and art changes aren't confused. (2) Write `tools/city/landsd_to_blender.py`/`build_blocks.py` for the **Bonham Strand block (stop 5)** and its cross street toward Wing Lok: import the LandsD meshes, apply the §3 conversion, redo the height comparison by polygon overlap, add a minimal detail layer (2 facade families, 6 shopfront types, 10 props) and pavements, export, assemble, drive past it. (3) Render **look A / look B × day / night**. Deliver side-by-side images with the Bonham Strand photos plus the §10 numbers. **STOP: the owner picks the art direction.**

**Phase 1 — Corridor.** Blocks along Des Voeux Road Central → Bonham → Wing Lok → Des Voeux West (stops 1, 4, 5, 10, 12); fetch any extra sheets needed (§3 etiquette); add traffic lights, guardrails, crossings; drop procedural buildings in finished blocks.

**Phase 2 — Heroes.** Tier A, with stop screenshots after each; then Tier B.

**Phase 3 — Whole district.** Remaining sheets and blocks: Hollywood/Cat Street/SoHo hill (set-backs on slopes), waterfront, ferry terminal. Delete the legacy `building()` path.

**Phase 4 — Atmosphere and static dressing.** Trees, planters, scaffolding, Tier C skyline, Mid-Levels hillside backdrop, Kowloon skyline, day grade and the night preset. No vehicles or pedestrians.

**Phase 5 — Optimise and polish.** Performance-driven simplification if needed (§3), LOD/occluder tuning, 60 fps standalone, regenerate `scenes/district.tscn` without buildings, update README/MAP_DESIGN/VALIDATION.

## 12. Don'ts

- Don't move/resize roads or stops for art.
- Don't pre-emptively simplify the LandsD meshes (§3).
- Don't use Google 3D Tiles/photogrammetry/AI whole-city meshes, photo textures, or real logos/shop names.
- Don't add hundreds of `Label3D` or thousands of individual `MeshInstance3D` props; use atlas signs and MultiMesh.
- Don't use alpha-blended materials for facades or foliage cards at scale.
- Don't bake the city with headless Godot.
- Don't re-download data that is already in the repo, and don't crawl the data service.
- Don't spend effort on vehicles or pedestrians this milestone.

## 13. Still open (ask the owner; don't guess)

(a) Final art direction after the Phase 0 A/B. (b) Any purchase of a paid HK kit ([CITY_RESEARCH.md](CITY_RESEARCH.md) §D needs owner approval and licence review).
