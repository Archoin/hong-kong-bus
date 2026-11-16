# City Build Guide — for Codex Astra

**Audience:** Codex Astra (the coding agent building the city). **Owner:** the game's designer.
**Status:** draft v1, written 2026-11-16. Supersedes the "generate everything in GDScript" approach described in [MAP_DESIGN.md](MAP_DESIGN.md) for *visual* city content. Roads, routing and collision stay as they are.

> **Goal in one sentence:** the city should read as *Sheung Wan, Hong Kong* at bus-driver eye level — dense, vertical, layered, cluttered and colourful — by authoring buildings and whole street blocks in **Blender**, exporting them as **GLB**, and assembling them in **Godot** around the existing, tested road network.

---

## 0. Read this first (the 10 rules)

1. **Do not hand-edit or "improve" `tools/build_city.gd` building code any further.** It extrudes footprints and paints a window shader; that ceiling has been reached (see §1). Keep its `terrain()`, `roads()`, markings, rails and stop furniture until a block replaces them; remove its `building()` output once blocks exist.
2. **Buildings and street blocks are authored in Blender** and live as `.blend` sources in `tools/source/city/`, exported to `assets/city/**/*.glb`. Every export is reproducible by a script (`blender --background --python …`), like `tools/build_bus.py`.
3. **Gameplay data stays in Godot.** `assets/map_data/district.json`, `scripts/district.gd` (`road_height`, `nearest_road`, `route`, stops…) and the road collision are the source of truth. Do not change road geometry, stop positions or the 0.8× projection to suit art. If art needs a different road, ask the owner.
4. **One unit = one metre. Y is up in Godot.** Floor-to-floor is **3.0 m**. See §6 for the Blender↔Godot axis mapping — get this wrong and every block lands mirrored.
5. **Never commit a single 40 MB `.tscn`.** The current `scenes/district.tscn` is 41 MB because meshes are serialized inline. The new city is a small `.tscn` that *instances* GLB scenes by path.
6. **Do not use `gl_compatibility`.** `project.godot` currently sets it (`renderer/rendering_method="gl_compatibility"`, feature `"GL Compatibility"`); **migrate to Forward+** (`forward_plus`, native Metal driver on macOS) as the first step of Phase 0 (§7.1). Do not design the city around Compatibility's limits. Forward+ features (SSAO, SSIL, SDFGI/VoxelGI, volumetric fog, glow, SSR, TAA/FSR2, better shadows) are allowed, but each must be justified by a before/after capture and a frame-time measurement. Draw-call discipline still applies (§6.6, §7).
7. **Prove the pipeline on ONE block before building the city** (Phase 0, §9). Stop and show the owner a side-by-side screenshot before continuing.
8. **Compare every iteration against real photos** (§2 list) using the repeatable camera shots in `tools/capture_map.gd`. "Looks better" is not evidence; a side-by-side is.
9. **Stylised, not photoreal.** Keep the project's flat, three-band toon look and warm/teal palette, but with *real proportions and real clutter*. The goal is "illustrated Hong Kong", not "low-effort boxes" and not "photo textures".
10. **Do not ship third-party photos or Google/Cesium data.** Reference images are for looking at only. Generated textures must be original or CC0. See §5.

---

## 1. What is wrong with the current city (screenshots vs. real photos)

Game captures reviewed: `captures/map_desvoeux.png`, `map_bonham.png`, `map_manmo.png`, `map_overview.png`, `review_driving.png`.
Real references (all Wikimedia Commons, CC-licensed, linked in §2): Des Voeux Rd Central / Cleverly St (tram), Bonham Strand (Gee Tuck Building, Cleverly St), Wing Lok Street, Hollywood Rd / Lok Ku Rd.

| # | Aspect | Real Sheung Wan (photos) | Current game | Impact |
|---|---|---|---|---|
| 1 | **Skyline & massing** | Sharp contrast of heights on one street: 5–12-storey tenement/mid-rise next to a 30-storey tower, with **set-backs, podiums, stepped rooftops**. Rooftops are busy: water tanks, illegal rooftop huts, sign frames, antennas, plants. | Near-uniform 10–40-floor boxes (median 33 m; 764 of 822 footprints are "tenement" style, 58 "glass"). Flat roofs, no roof objects. Streets read as an identical canyon. | **High** |
| 2 | **Frontage rhythm** | Lots are narrow (≈4–8 m). The facade **changes every few metres**: different paint, balcony type, window type, signage. | One footprint edge = one 10–40 m flat wall with one tiled window shader. No lot subdivision, no per-lot variation. | **High** |
| 3 | **Facade vocabulary** | Projecting balconies, **AC units clustered on ledges and steel racks** (never a neat grid), window grilles/cages, pipes, ceramic-tile podiums, horizontal spandrel bands, stained concrete, exposed external stairs, bamboo scaffolding with green/black netting. | Procedural window grid + a few evenly spaced AC boxes. No balconies, cages, pipes, stairs. Scaffolding is only a few poles. | **High** |
| 4 | **Colour** | Painted ochre/orange, mint green, maroon/purple, white, grey tile, mosaics — saturated and varied per building. | 8 pale, similar greys/creams + teal glass, further washed by fog and a linear tonemap. Whole image is pastel teal. | **High** |
| 5 | **Ground floor / shopfronts** | Deep, layered: roller shutters, glass with goods visible, awnings/canopies, **huge red/gold fascia signs**, goods spilling onto the pavement (dried seafood on Wing Lok / Des Voeux West), hydrants, bins, bollards. | A dark recessed strip with thin columns, a coloured band and a slim awning. Reads as a placeholder. | **High** |
| 6 | **Signage** | Dense **vertical blade signs** projecting across the street at 2nd–4th floor, lightboxes, green/blue street-name plates, road signs, bilingual text. | A handful of blade signs, text via `Label3D` (flat, small). | **High** |
| 7 | **Street life & props** | Parked vans/taxis/scooters, double-decker trams with full ad wraps, **pedestrian guardrails**, traffic-light poles, zebra crossings, trees in planters, overhead tram wires. | Empty roads; a few trams; stop shelters and street lamps only. No cars, no pedestrians (except queues), no guardrails or traffic lights. | **High** |
| 8 | **Street proportions** | Bonham Strand ≈ 2 narrow lanes with pavement; Des Voeux ≈ tram track + 2 lanes each way. Buildings feel *close*. | Roads 11.5–26 m wide (`build_city.gd` also paints a pavement strip `width + 3.8 m`); plenty of unused flat asphalt and plain featureless verge. Streets feel wide and empty. | Medium |
| 9 | **Pavements & ground** | Red-brick/grey paver pavements, kerb lines, ramps, tactile strips, manholes, double-yellow lines. | Plain cream flat verge; yellow lines exist (good). | Medium |
| 10 | **Hero landmarks** | Western Market: red-brick Edwardian with cream bands, turret, arched openings. Man Mo Temple: grey brick, green-tile pitched roofs with ridge ornaments, incense coils, lanterns. | Western Market is a box with strips; Man Mo is a cream box with a red door (`captures/map_manmo.png`). | **High** (landmarks anchor stops 1, 8, 10) |
| 11 | **Light & atmosphere** | Humid, hazy, bright with **hard, dark shadows between buildings**; sky gradient, harbour glare. | Flat pastel ambient, flat clear colour sky, shallow shadows (`directional_shadow_max_distance=160`). | Medium |
| 12 | **Context / backdrop** | Sheung Wan climbs the Mid-Levels slope: stacked towers up the hillside to the south; Kowloon across the harbour. | Map is a rectangle with floating pastel blocks on the sides and flat slab skyline (`captures/map_overview.png`). Edges feel unfinished. | Medium |
| 13 | **Overview readability** | Block-level texture (courtyards, rooftops, streets as continuous ribbons). | Roads appear as torn dark fragments on cream ground; no block ground texture. | Low (only seen by the map camera) |
| 14 | **Scene weight** | n/a | `scenes/district.tscn` is 41 MB, entirely generated; not human-editable. | Process |

**What the game already gets right — keep it:** the yellow road markings and kerb lines, the dense AC/sign vocabulary *attempted*, bilingual shop names, the toon shading mood, the road/terrain/collision coupling, trams on the real Des Voeux corridor, and real street alignments.

### Visual vocabulary checklist (build these, in roughly this priority)

1. Variable building height, set-backs, podiums, roof clutter (water tank, rooftop hut, antenna, sign frame).
2. Narrow lots with a distinct facade per lot (3–4 facade families, 6+ paint colours each).
3. Balconies + AC clusters on ledges/racks + window grilles/cages.
4. Layered shopfronts: shutter / glass / fascia sign / canopy / spill-out goods.
5. Blade signs and lightboxes crossing the street; real bilingual lettering.
6. Pedestrian guardrails, traffic lights, road signs, bins, hydrants, bollards, trees in planters.
7. Bamboo scaffolding with green/black netting (on ~1 in 15 buildings).
8. Parked/standing vehicles (vans, taxis, scooters, a few buses), pedestrians.
9. Pavement materials: brick paver, kerb, tactile strip, manholes.
10. Hero landmarks (Western Market, Man Mo Temple, PMQ, Central Market, Sheung Wan Municipal Services Building, Macau Ferry Terminal / Shun Tak, The Center / IFC skyline).

---

## 2. Reference photo set (look, don't copy)

Open these in a browser while working. Do not add them to the repo or use them as textures.

| Use for | Wikimedia Commons file |
|---|---|
| Des Voeux tram corridor, bamboo scaffolding & netting, strong horizontal banded maroon tower, double-yellow & box junction, traffic lights | [Champion Building / Cleverly St, July 2020](https://commons.wikimedia.org/wiki/File:HK_SW_Sheung_Wan_Cleverly_Street_Des_Voeux_Road_Central_Champion_Building_July_2020_SS2_01.jpg) |
| Bonham Strand: ochre mid-rise with balconies + AC, big red shop fascia, canopies, narrow street, scooter, vans | [Bonham Strand / Cleverly St, Feb 2025](https://commons.wikimedia.org/wiki/File:HK_%E4%B8%8A%E7%92%B0_Sheung_Wan_%E6%96%87%E5%92%B8%E8%A1%97_Bonham_Strand_Cleverly_Street_February_2025_R12S_01.jpg) |
| Bonham Strand: 1970s-style ribbon-window mid-rise over a shop, ground floor detail | [Gee Tuck Building, May 2024](https://commons.wikimedia.org/wiki/File:HK_SW_Sheung_Wan_Bonham_Strand_%E8%87%B3%E5%BE%B7%E5%A4%A7%E5%BB%88_Gee_Tuck_Building_May_2024_R12S_02.jpg) |
| Wing Lok Street: tile-clad podium with large brown fascia sign, dried-seafood trade, hydrant, brick pavement | [Wing Lok Street, Sep 2024](https://commons.wikimedia.org/wiki/File:HK_SW_%E4%B8%8A%E7%92%B0_Sheung_Wan_%E6%B0%B8%E6%A8%82%E8%A1%97_Wing_Lok_Street_September_2024_R12S_09.jpg) |
| Hollywood Rd / Lok Ku Rd: colourful stepped tenements (green, yellow), hill street, rooftop plants, shop blade signs | [Hollywood Rd n Lok Ku Rd, May 2025](https://commons.wikimedia.org/wiki/File:HK_SW_Sheung_Wan_%E8%8D%B7%E6%9D%8E%E6%B4%BB%E9%81%93_Hollywood_Road_n_Lok_Ku_Road_Tai_Hing_building_n_Sai_Street_May_2025_R12S.jpg) |
| Hollywood Building, Possession St: street receding downhill, railings, glass tower mixed with tenements | [190 Hollywood Rd, May 2025](https://commons.wikimedia.org/wiki/File:HK_SW_Sheung_Wan_%E8%8D%B7%E6%9D%8E%E6%B4%BB%E9%81%93_190_Hollywood_Road_Hollywood_Building_n_Possession_Street_May_2025_R12S_01.jpg) |
| More: Des Voeux Rd Central, Sheung Wan (buildings, shops, western market terminus) | [Category](https://commons.wikimedia.org/wiki/Category:Des_Voeux_Road_Central,_Sheung_Wan) |
| More: Western Market exterior | [Category](https://commons.wikimedia.org/wiki/Category:Exterior_of_Western_Market) |
| Older context for Des Voeux shopfront arcades | [HKU Hong Kong in Transition](https://arthistory.hku.hk/HKinTransition/image_detail.php?id=25793) |

**Method note:** the analysis in §1 used these Commons photos, not Google Street View (Street View cannot be embedded in a script and its terms forbid reuse). The owner can open Google Street View at the stop coordinates (`D.STOP_POS` → lat/lon via the projection in `district.json`: origin 114.1515 E, 22.2858 N, 0.8× scale) for extra checking. Use it for looking only.

---

## 3. How other people build cities, and how they compare

Research performed 2026-11-16. Sources linked inline; treat vendor pages as marketing.

| # | Approach | How it works | Pros | Cons | Fit here |
|---|---|---|---|---|---|
| A | **Current: GDScript extrudes OSM footprints + shader facade** | Footprint → prism; window pattern in a fragment shader; boxes for props, baked into a `.tscn` | Real street layout, tiny repo footprint, fully scripted, great for collision | Generic look; no silhouette detail (balconies, stairs, roof clutter); 41 MB scene; hard to art-direct; every improvement is more code | **Keep only for roads/terrain/collision** |
| B | **OSM → Blender add-on (Blosm / BlenderGIS)** — [Blosm](https://github.com/vvoovv/blosm), [BlenderGIS OSM import](https://github.com/domlysz/BlenderGIS/wiki/OSM-import) | One-click import of footprints with height/levels, terrain, roofs; premium adds textures/Geometry Nodes | Fast blockout of real areas; reads tags; global coverage | Output is a base to refine, not final art; gaps where OSM unmapped; thousands of objects freeze Blender (import-as-single-mesh workaround); free version untextured | **Use as optional pre-vis only.** We already have clean footprints in `district.json` |
| C | **Procedural generators in Blender (Geometry Nodes)** — e.g. free [Auto-Building](https://auto-building.readthedocs.io/), paid [MBG](https://superhivemarket.com/products/mbg-building-geometry-nodes), [Pro City – Hong Kong](https://superhivemarket.com/products/pro-city-hong-kong/docs), [PBG 2](https://blendermarket.com/products/pbg-2/docs) | Low-poly mass → modular walls/windows/balconies/roofs instanced from *your* collections | Fast variation; art stays in your kit; re-runnable when footprints change; can export per block | Third-party styles aren't Sheung Wan; paid licences to vet; live modifiers must be applied before export; docs rarely cover game export, UVs or atlasing | **Best base for filler buildings** — but build *our own* small GN/Python generator driven by our own kit (§6.3). Study Auto-Building's "collections of parts" design |
| D | **Fully hand-modelled buildings** | Artist models each building | Best silhouette and character; total control | Very slow; cannot cover ~800 footprints | **Heroes only** (~10–25 buildings) |
| E | **Hero + filler split** — see [hero vs. filler workflow](https://www.tripo3d.ai/blog/city-block-generator), [Houdini city workflows](https://80.lv/articles/learn-how-to-make-procedural-building-generator-in-houdini/) | Procedural layout produces footprints/massing; hand-made heroes are anchors; tiling filler meshes are instanced | How most production cities are made; effort goes where the player looks | Needs a clean boundary between hero and filler and a naming convention | **Recommended** (this is §4) |
| F | **Houdini / Houdini Engine pipelines** — e.g. [OSM → Houdini → Unity](https://80.lv/articles/generating-cities-with-unity-houdini-openstreetmap-data), Epic's [City Sample](https://dev.epicgames.com/documentation/unreal-engine/city-sample-quick-start-for-generating-a-city-and-freeway-using-houdini) | Node-based procedural layout + facade rules | Industry-strength; great control | No Houdini Engine plugin for Godot (bake to GLB instead); licence cost; Police Simulator team found generation times slow and fell back to grayboxing ([80.lv](https://80.lv/articles/creating-an-open-world-environment-in-police-simulator-patrol-officers/)) | Not now |
| G | **Photogrammetry / Google Photorealistic 3D Tiles (Cesium)** — [Cesium terms discussion](https://community.cesium.com/t/can-i-make-a-videogame-with-cesium-for-unreal/28962) | Stream real captured city | Instantly real | Must be streamed, cannot ship or edit; free tier non-commercial only; attribution/logo required; no Godot-native path; wrong art style; can't isolate/extract buildings | **No** |
| H | **Off-the-shelf modular kits** — e.g. [Kenney City Kit](https://kenney.nl/assets/city-kit-roads), itch.io/Superhive "modular city" packs | Drop pre-made pieces on a grid | Free/cheap, GLB-ready, trim-sheet efficient | Western/generic; wrong proportions (HK is vertical, narrow, cluttered); the repo already evaluated and rejected Kenney (RESEARCH.md) | Use only for non-HK-specific props (bins, bollards) if licence allows |
| I | **Stylised hand-kit + vertex colour (the "Lucky Mountain" approach)** — [Sketchfab write-up](https://sketchfab.com/blogs/community/art-spotlight-lucky-mountain-games-environment-prototype) | Small flat-colour low-poly kit; vertex colour instead of textures; palette from film reference | Very cheap to render; cohesive; fits our toon shader; proves Hong Kong street can be done low-poly | Needs disciplined palette and silhouette work | **Matches our style** — use vertex colour + a small atlas |
| J | **Trim sheets + shared atlas** — e.g. [modular kits sharing one trim sheet](https://sigilsvault.itch.io/modular-cathedral-kit) | All pieces share 1–2 textures | Few materials → few draw calls; consistent look | UV discipline required | **Required** — few materials keep draw calls and texture lookups low in any renderer (§7) |

**Verdict.** Approach **E** (hero + filler) built with **C** (our own Blender kit and generator) and **I/J** (flat-colour kit + shared atlas), keeping **A**'s road/terrain/collision. This is also your preference: author buildings and street blocks in Blender, instance them in Godot.

---

## 4. Target architecture

```
                 ┌────────────────────────────┐
 district.json ─▶│ tools/city/export_blocks.py│  (plain Python, no Blender)
 (OSM footprints,│  - assigns footprints to    │
  roads, terrain)│    street blocks            │
                 │  - writes per-block JSON    │
                 │    + height grid            │
                 └──────────────┬─────────────┘
                                ▼
 tools/source/city/kit.blend ──▶ tools/city/build_blocks.py  (Blender --background)
 (facade kit, shopfronts,        - reads block JSON
  props, hero .blend files)      - builds / instances buildings, sidewalks, props
                                 - writes assets/city/blocks/block_###.glb (+ _lod1.glb)
                                 - writes assets/city/city_index.json (centres, bounds, hero list)
                                              ▼
                     tools/city/assemble_city.gd  (Godot, rendering on)
                     - instances block GLBs under scenes/city/district_blocks.tscn
                     - adds visibility ranges, occluders, collision, lights
                                              ▼
                          scripts/district.gd, roads, stops, trams, bus (unchanged)
```

**Responsibilities**

| Layer | Owns | Where |
|---|---|---|
| Gameplay-critical | Roads, road markings, rails, stop bays, routing, collision of roads and buildings, terrain function `D.road_height()` | Godot (existing `tools/build_city.gd`, `scripts/district.gd`) |
| Visual city | Buildings (filler + hero), podiums, shopfronts, balconies, signs, roof clutter, sidewalks + kerbs, planters, guardrails, lamp posts, scaffolding | Blender → GLB |
| Dynamic/world | Trams, buses, vehicles, pedestrians, queues | Godot scenes/scripts |
| Atmosphere | Sky, fog, light, harbour, far skyline/hills | Godot (`WorldEnvironment`) + a few Blender far-LOD meshes |

**A "street block" is** a group of adjacent footprints bounded by roads, plus the pavement strip around them. Build it by connected components of footprints after buffering by ~2 m, then split any block wider than ~120 m on a grid. Target **~60–120 block files** for the whole 1,120 × 660 m map. Name them `block_<gx>_<gz>.glb` using a 100 m grid index of the block centroid so files are stable across re-exports.

**Why blocks rather than one file per building:** fewer nodes, a natural unit for visibility ranges/occluders/LOD, shared pavement and party walls, and easy to hand-polish in Blender (open a block, move a sign, re-export). Heroes are separate files (`assets/city/heroes/*.glb`) placed on top of their footprint, replacing the filler building there.

---

## 5. Art direction and rules

- **Style:** stylised, flat colour with the existing 3-band toon lighting; real proportions and clutter. Silhouette first; texture detail second.
- **Palette:** pull from the photos — ochre/orange, mint/jade green, maroon, off-white, grey ceramic tile, teal glass. At least **8 body colours** and **6 accent colours** (shop fascias, awnings). Stop the pastel teal wash: reduce fog density, lower ambient, raise sun contrast.
- **Texture sources:** original or CC0 only. Paint your own trim sheet/atlas in Blender (procedural bake) or by hand. No photograph texture goes into the repo.
- **Text:** shop signs are real bilingual Chinese + English (existing `SHOPS`/`ENGLISH` lists in `build_city.gd` are a good start; add ~40 more). Prefer text baked into the sign atlas or small meshes; do not use hundreds of `Label3D`s.
- **IP:** no real brand logos or real shop names. Generic or invented names only. The existing note in README (HKU photos are links only) applies to everything.
- **Attribution:** OSM/ODbL attribution already in README stays.

---

## 6. Blender spec

### 6.1 Environment

- Blender **5.2.2 LTS** at `/Applications/Blender.app/Contents/MacOS/Blender` (run `--background --python`). Godot **4.6.1** at `/Applications/Godot.app/Contents/MacOS/Godot`.
- Source files: `tools/source/city/kit.blend` (kit), `tools/source/city/heroes/<name>.blend`, `tools/source/city/blocks/block_*.blend` (optional hand-polished blocks).
- Keep `.blend1` out of git (already ignored). Large `.glb` outputs: expect 60–120 blocks × 0.5–3 MB. Ask the owner before enabling Git LFS if the total exceeds ~150 MB.

### 6.2 Scale, axes, origin

- 1 Blender unit = 1 m. Apply all scale and rotation before export.
- **Axis mapping.** Godot world `(x, y_up, z)` ↔ Blender `(x, −z, y_up)`. The glTF exporter's "+Y up" setting maps Blender `(x, y, z)` → glTF `(x, z, −y)`, so `Blender.y = −Godot.z`. When the script places a footprint vertex from `district.json` (x, z) it must write Blender `(x, −z)`. Verify with the unit test in Phase 0: block centre in Godot equals `city_index.json` centre within 5 cm, and a known corner (e.g. Western Market polygon) overlays the OSM polygon.
- **Origin.** Each block's origin is its centroid at **ground height** (`D.road_height(centroid)`). `assemble_city.gd` places the instance at that world position. Vertices are local to the origin. This keeps float precision and lets you hand-move a block in Godot.
- **Terrain.** Streets climb Hollywood/SoHo hills. Export a height grid from Godot (`D.road_height` sampled at 2 m → `assets/map_data/height_grid.json`) and let the Blender script drape pavement and building bases on it. Buildings need a **foundation skirt** ≥ 3 m deep below their lowest corner so no gaps show on slopes, with stepped podiums on steep lots.

### 6.3 Kit and generator

Floor-to-floor **3.0 m**. Bay widths **2.4 / 3.0 / 3.6 m**; ground floor 3.6–4.2 m. Facade families (each with ≥ 6 colour variants and 3 variants of window/balcony arrangement):

| Family | Heights | Where | Signature |
|---|---|---|---|
| **Tong lau / old tenement** | 4–7 floors | Hollywood Rd, Bonham, Wing Lok, Cat Street | Cantilevered balconies, shutters/louvres, narrow lots, rooftop huts, exposed stairs |
| **Post-war mid-rise ("composite" building)** | 8–18 floors | Des Voeux, Queen's Rd, Bonham | Ribbon windows or window grids, ceramic-tile podium, AC clusters, rooftop water tanks, big shop fascia |
| **Commercial podium + tower** | 20–45 floors | Waterfront, Central edge | Tiled/curtain-wall podium, glass tower with spandrel bands, plant rooms on top |
| **Heritage / civic** | 2–6 floors | Western Market, PMQ, Central Market, Man Mo | Hand-modelled hero (§6.4) |

Generator requirements (`tools/city/build_blocks.py`):
- Subdivide each footprint edge into **lots 4–8 m wide** (random but seeded from `osm_id`) so each lot picks its own colour, balcony type, sign and AC layout.
- Vary height per lot (set-backs, a stepped top, a tall thin neighbour). Respect OSM `height` for **named** buildings; for the anonymous majority apply ±30 % variation and cap at the OSM value ×1.25.
- Place roof clutter (tank, hut, antenna, sign frame) on ≥ 70 % of roofs.
- Ground floor: shutter / glass / fascia sign / canopy / spill-out props, chosen per lot, with a **minimum clear pavement** of 1.8 m.
- Blade signs project ≤ 2 m over the carriageway, starting ≥ 4.5 m above ground (bus roof is ~3 m; the camera must not clip signs).
- AC units in **irregular clusters** on balconies/ledges/racks, never a regular grid.
- Pavement: brick-paver strip, kerb 12–15 cm, lamp posts every ~25 m, guardrails near crossings and stops, planters/trees where space allows.
- Seeded and deterministic: the same inputs must produce byte-identical GLBs.

Use Geometry Nodes or plain Python `bpy` — whichever is easier to keep deterministic — but **apply all modifiers and realize instances before export** (see §6.5).

### 6.4 Heroes (hand-modelled)

Build each in its own `.blend`, ~3–15k triangles, one atlas, with LOD1 (~25 %) authored or decimated. Footprints and approximate height come from `district.json` (`landmarks` and named buildings). Priority:

1. **Western Market** (stop 1) — red-brick Edwardian, cream string courses, arched openings, corner turret, lettering.
2. **Man Mo Temple + Lit Shing Kung** (stop 8) — grey brick, green-tile pitched roofs with ridge ornaments, red doors, lanterns, incense coils, courtyard.
3. **Central Market** (stop 10) and **PMQ** (stop 9) — recognisable massing and balconies.
4. **Sheung Wan Municipal Services Building**, **Macau Ferry Terminal / Shun Tak twin towers**.
5. Skyline: **The Center** (346 m crown), **IFC**, **Exchange Square** — silhouettes only, far LOD.

### 6.5 Export checklist (glTF, per Blender/Godot docs)

Per [Godot's export notes](https://docs.godotengine.org/en/4.4/tutorials/assets_pipeline/importing_3d_scenes/model_export_considerations.html) and community checklists such as [this one](https://app.cinevva.com/guides/blender-to-godot-export-checklist):

- Format **glTF Binary (.glb)**, **+Y Up**, **Apply Modifiers** on, include **Selected Objects** only (no cameras/lights/reference meshes).
- Materials: **image textures on Principled BSDF** or vertex colour only. Procedural node materials do not export — bake them first.
- No Draco compression (Godot does not support it).
- Triangulate (Triangulate modifier + Apply Modifiers).
- Apply scale/rotation; zero-pivot sanity; **recalculate normals outward**; no loose verts; no n-gon artifacts.
- Collision hints: name suffix `-col`, `-colonly`, `-convcolonly` on mesh nodes are honoured by Godot's importer ([docs](https://docs.godotengine.org/en/4.2/tutorials/assets_pipeline/importing_3d_scenes/node_type_customization.html)). **Do not rely on them for buildings.** Keep building collision generated from OSM footprints in Godot (as `build_city.gd` does today with convex prisms) — it is tested and keeps routes drivable. Use `-colonly` only for small props if useful. Use `-noimp` for reference/helper nodes you want visible in Blender only.
- Do **not** assume collection-instance or linked-library behaviour: verify with a small test file first (documentation is thin).

### 6.6 Budgets (starting targets — confirm with the profiler, then adjust)

| Item | Target |
|---|---|
| Materials per block | ≤ 3 (opaque atlas, glass/emissive, signs). No alpha-blended facades |
| Texture | 1–2 shared atlases of 2048–4096 px; palette variation via vertex colour or per-instance shader parameter |
| Triangles per block LOD0 | 60k–150k, with hero blocks possibly higher |
| LOD1 per block | ≈ 15–25 % of LOD0, window texture only, no props |
| Visible draw calls in the typical chase-camera view | ≲ 1,500 (measure with the Godot profiler / `RenderingServer` stats in Forward+) |
| GLB size per block | ≤ 3 MB |
| Frame rate | stable 60 fps on the owner's M-series Mac in the standalone build |

---

## 7. Godot integration spec

New files (create; don't repurpose `build_city.gd`):

- `tools/city/export_blocks.py` — reads `assets/map_data/district.json`, writes block membership + height grid (pure Python, `python3 -I`).
- `tools/city/build_blocks.py` — Blender script (above).
- `tools/city/assemble_city.gd` — Godot `SceneTree` script, run with rendering enabled like `build_city.gd`. Instances every block as a child of `scenes/city/district_blocks.tscn`, sets transforms from `city_index.json`, adds `OccluderInstance3D`, `visibility_range_*`, `StaticBody3D` collision from footprints, a `WorldEnvironment` and sun.
- `scenes/city/district_blocks.tscn` — **small**; references `res://assets/city/blocks/*.glb` by path (no inline meshes).
- `tests/test_city_blocks.gd` — see §8.

### 7.1 Renderer migration (first task of Phase 0)

1. In `project.godot`: set `renderer/rendering_method="forward_plus"`, replace the `"GL Compatibility"` feature with `"Forward Plus"`, and remove `renderer/rendering_method.mobile="gl_compatibility"` (use `"mobile"` there only if a mobile target is ever wanted — it is not). Leave `textures/vram_compression/import_etc2_astc` alone unless the export needs it.
2. Check that `export_presets.cfg` macOS preset still exports with the matching 4.6.1 templates, and that `builds/` are rebuilt.
3. Re-run `./tests/run_checks.sh` and a rendered `tools/playtest.gd` run. Headless tests do not exercise the renderer, so the rendered run and screenshots are the real check.
4. Re-capture the standard shots and compare with `captures/map_*.png`. Known risks to inspect: `assets/shaders/toon.gdshader` and `facade.gdshader` (custom `light()` using `DIFFUSE_LIGHT`; confirm shading, shadows and `fwidth` antialiasing look the same), `Label3D` text and outlines, fog, MultiMesh instances, shadow bias on the sun (`DirectionalLight3D`), and MSAA.
5. Update `docs/VALIDATION.md` (it says it was reviewed with the OpenGL Compatibility renderer) and the README with the new renderer and a first Forward+ frame-time baseline on the owner's Mac.
6. If Forward+ fails in some environment, report it to the owner instead of silently falling back to Compatibility.

Rules:

- **Import settings** (`*.glb.import`): keep default scene import; enable *Generate LODs* for static meshes where useful; no `Skin`/animation. Commit `.import` files.
- **Visibility ranges.** LOD0 `visibility_range_end ≈ 220 m` with fade; LOD1 from 200 m to ~600 m; hide interiors/props beyond ~120 m. Use `visibility_range_fade_mode = SELF`.
- **Occlusion.** One `OccluderInstance3D` per block with a simple box/prism occluder built from the footprints (Godot's [3D optimisation docs](https://docs.godotengine.org/en/4.4/tutorials/performance/optimizing_3d_performance.html) recommend occluders when streets are blocked by walls; dense tall city blocks suit this well).
- **Instancing.** Repeated props (lamps, guardrails, bins, planters, trees, vehicles) use `MultiMeshInstance3D` per block; the doc notes automatic instancing only helps opaque/alpha-tested identical mesh+material and that alpha-blended items never batch.
- **Shadows.** Directional-light shadows multiply draw calls ([forum report](https://forum.godotengine.org/t/understanding-batching-in-godot-4/65635)). Keep `directional_shadow_max_distance` modest (≈160–220 m); consider orthogonal shadow mode.
- **Materials.** Reuse the toon look. Convert `assets/shaders/facade.gdshader` into an *atlas toon* shader (albedo atlas + vertex colour + three-band light); keep a `glass` variant. Add a night/emissive window mask if the game later gets night.
- **Lighting (Forward+).** Start with a dynamic sun plus `Sky` ambient, no baked GI. Tune tonemap (Filmic/ACES), reduce `fog_density`, add a procedural sky gradient, raise sun/ambient contrast so shadows between buildings read. Then evaluate, one at a time and only if frame time allows: SSAO (contact shadow in canyons and under awnings), SSIL, glow for lightboxes/signs, SDFGI (bounce light in street canyons; test it on the 1,120 × 660 m map and with `cull_mask`/cascade settings), volumetric fog for harbour haze. Keep each feature that earns its cost in the capture comparison; drop the rest. Stay with a single `DirectionalLight3D` for shadows.
- **Anti-aliasing.** `msaa_3d=2` is set today; test MSAA vs. TAA/FSR2 in Forward+ on thin features (railings, wires, blade signs) and pick by capture.
- **Streaming (later, only if needed).** If memory or load time bites, load blocks by distance from the bus with `ResourceLoader.load_threaded_request`. Don't start here: 60–120 blocks fits in memory.
- **Old scene.** Leave `scenes/district.tscn` in git until blocks match it for collision and routing, then regenerate it **without buildings** (terrain + roads + rails + stops) so it drops from 41 MB to a few MB.

---

## 8. Verification (every phase)

Run, and attach evidence:

1. `./tests/run_checks.sh` — existing rules/graph/gameplay checks must stay green.
2. `tools/test_map_graph.gd` — connectivity unchanged.
3. New `tests/test_city_blocks.gd`: every block file in `city_index.json` exists; block centres match transforms; every named OSM building footprint with height ≥ 60 m has a mesh whose AABB reaches ≥ 80 % of that height; bus spawn and all 12 stops have ≥ 2.5 m clearance; no building collision intrudes on the road corridor (re-use the Hollywood regression at (−266, 32)).
4. **Physical driving** run (`tools/playtest.gd --policy=express --seed=20261113`) completes without new collisions/recoveries (baseline: 48 deliveries, 0 collisions, 0 recoveries — see VALIDATION.md).
5. **Screenshot pairs.** Extend `tools/capture_map.gd` (or add `tools/capture_city_compare.gd`) to render fixed shots at: stop 1 (Western Market), stop 5 (Bonham Strand), stop 4 (Dried Seafood Street), stop 8 (Man Mo Temple), Des Voeux tram spine, Hollywood Rd uphill, and an overview. Save to `captures/city_v<n>/`. Build a simple HTML or PNG sheet placing each against its reference photo (links only, never embedded copies in the repo) and fill the §1 table with ✔/✘ for each row.
6. **Performance report.** Draw calls, triangles, FPS in the standalone build at the same shots, with the numbers written into `docs/VALIDATION.md`.

Report failures honestly; don't claim a result you did not measure.

---

## 9. Phased plan with stop-gates

**Phase 0 — renderer migration + one-block vertical slice (≈ first deliverable).**
First migrate to Forward+ (§7.1) and show the before/after captures of the *existing* city, so renderer changes are not confused with art changes. Then choose the **Bonham Strand stop (stop 5)** block plus the cross street toward Wing Lok. Build `kit.blend` with the minimum kit (2 facade families, 6 shopfront types, 10 props), the generator for that block, export, `assemble_city.gd`, drive past it in-game. Deliver the side-by-side with the Bonham Strand photos and the numbers from §8. **STOP: owner reviews and approves art direction before Phase 1.**

**Phase 1 — corridor.** Generate blocks along Des Voeux Road Central → Bonham → Wing Lok → Des Voeux West (stops 1, 4, 5, 10, 12). Add tram-corridor props (wires/poles exist; add traffic lights, guardrails, crossings). Remove procedural buildings in those blocks from the old scene.

**Phase 2 — heroes.** Western Market, Man Mo Temple, Central Market, PMQ, municipal building. Verify with stop screenshots.

**Phase 3 — whole district.** Hollywood/Cat Street/SoHo hill blocks (set-back stepping on slopes), waterfront blocks, ferry terminal. Delete the legacy `building()` path once all blocks exist.

**Phase 4 — life and atmosphere.** Parked vehicles and scooters (MultiMesh), pedestrians along pavements, trees, bamboo scaffolding on selected buildings, far Mid-Levels hillside backdrop (billboard/low-poly mass), Kowloon skyline silhouettes, new sky/fog/light grade.

**Phase 5 — optimise and polish.** LOD tuning, occluder tuning, draw call pass, 60 fps in the standalone build, regenerate `scenes/district.tscn` without buildings, update README/MAP_DESIGN/VALIDATION.

Each phase ends with: green checks, updated captures, a short note appended to `docs/VALIDATION.md`, and a stop for owner review.

---

## 10. Things not to do

- Don't increase road widths, shrink them, or move stops for visual convenience.
- Don't swap in Google 3D tiles, photogrammetry or AI-generated whole-city meshes.
- Don't bake photographic textures or real logos.
- Don't add hundreds of `Label3D` or thousands of individual `MeshInstance3D` for props; use atlas signs and MultiMesh.
- Don't use alpha-blended materials for facades or foliage cards at scale.
- Don't regenerate the city with `--headless` Godot (MultiMesh transform buffers are lost; documented in MAP_DESIGN.md).
- Don't leave a pipeline that only works by hand: every asset must be rebuildable from scripts and sources committed in the repo.

## 11. Open questions for the owner

1. **Art direction confirmation:** "stylised toon with real proportions/clutter" (assumed here) vs. more realistic painterly textures.
2. **Scope of heroes:** is the list in §6.4 right, or should Cosco/Sheung Wan Station area or Hollywood Road landmarks get heroes too?
3. **Night time:** will there be a night variant? It changes whether windows/signs need emissive layers from day one.
4. **Git LFS:** acceptable for GLB/blend files if the repo grows beyond ~150 MB?
5. **Traffic and pedestrians:** are ambient cars/pedestrians in scope for this milestone or a later one?

---

## Sources

- Godot docs: [Model export considerations](https://docs.godotengine.org/en/4.4/tutorials/assets_pipeline/importing_3d_scenes/model_export_considerations.html), [Node type customization (name suffixes)](https://docs.godotengine.org/en/4.2/tutorials/assets_pipeline/importing_3d_scenes/node_type_customization.html), [Optimizing 3D performance](https://docs.godotengine.org/en/4.4/tutorials/performance/optimizing_3d_performance.html)
- Godot forum: [Understanding batching in Godot 4](https://forum.godotengine.org/t/understanding-batching-in-godot-4/65635)
- Blender → Godot checklist: [Cinevva guide](https://app.cinevva.com/guides/blender-to-godot-export-checklist)
- OSM in Blender: [Blosm](https://github.com/vvoovv/blosm), [BlenderGIS OSM import](https://github.com/domlysz/BlenderGIS/wiki/OSM-import)
- Procedural building generators: [Auto-Building docs](https://auto-building.readthedocs.io/), [MBG](https://superhivemarket.com/products/mbg-building-geometry-nodes), [Pro City – Hong Kong](https://superhivemarket.com/products/pro-city-hong-kong/docs), [PBG 2](https://blendermarket.com/products/pbg-2/docs)
- Pipelines: [Hero vs. filler city workflow](https://www.tripo3d.ai/blog/city-block-generator), [Houdini procedural building generator](https://80.lv/articles/learn-how-to-make-procedural-building-generator-in-houdini/), [Police Simulator open-world environment](https://80.lv/articles/creating-an-open-world-environment-in-police-simulator-patrol-officers/), [Epic City Sample](https://dev.epicgames.com/documentation/unreal-engine/city-sample-quick-start-for-generating-a-city-and-freeway-using-houdini)
- Stylised Hong Kong street in low poly: [Lucky Mountain Games environment](https://sketchfab.com/blogs/community/art-spotlight-lucky-mountain-games-environment-prototype)
- Trim-sheet kits: [Modular cathedral kit](https://sigilsvault.itch.io/modular-cathedral-kit)
- Google/Cesium terms: [Cesium community: can I make a videogame](https://community.cesium.com/t/can-i-make-a-videogame-with-cesium-for-unreal/28962), [Google 3D Tiles attribution](https://community.cesium.com/t/google-photorealistic-tiles-copyright-attribution/23999)
- Photo references: see §2 (Wikimedia Commons)
