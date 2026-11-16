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
11. **Milestone scope: static buildings and street blocks only.** No ambient traffic, parked-vehicle, or pedestrian work in this milestone (existing trams, rival buses and stop queues stay as they are). Build everything **night-ready** though (emissive window/sign masks, §7), because a night variant is planned.
12. **Build from the Lands Department meshes.** The Hong Kong Lands Department 3D building data (sheet `11-SW-8A`, in the repo via Git LFS) is the **primary source for building geometry**: use those meshes directly for heights, massing and roofs, and **simplify only if performance becomes an issue** (§3.3). Check §3.1 for other reusable tools and CC0 content, follow the download etiquette in §3.2 for further sheets, and log every third-party item in `docs/ASSET_LICENSES.md`.

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
| 7 | **Street life & props** | Parked vans/taxis/scooters, double-decker trams with full ad wraps, **pedestrian guardrails**, traffic-light poles, zebra crossings, trees in planters, overhead tram wires. | Empty roads; a few trams; stop shelters and street lamps only. No cars, no pedestrians (except queues), no guardrails or traffic lights. | **High** (vehicles/pedestrians out of scope this milestone; guardrails, signals, signs, trees are in scope) |
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
8. ~~Parked/standing vehicles, pedestrians~~ — **out of scope for this milestone** (owner decision, 2026-11-16). Leave kerb-side space and pavement widths realistic so they can be added later.
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

### 3.1 What can be reused (background research, 2026-11-16)

Licences below are from search results and listing pages, **not legal review**. Verify on the source page before shipping anything, and record each item in `docs/ASSET_LICENSES.md` (source URL, licence, date checked, what was changed, attribution text). Anything unverified is marked ⚠.

**1. Real Hong Kong building geometry — the most valuable find**

| Resource | What it is | How to use it | Caveats |
|---|---|---|---|
| **HK Lands Department 3D Visualisation Map** — [non-textured models](https://data.gov.hk/en-data/dataset/hk-landsd-openmap-3d-visualisation-map-non-textured-models) (**glTF, FBX, MAX**; building, infrastructure and terrain geometry) and [individualised models](https://data.gov.hk/en-data/dataset/hk-landsd-openmap-3d-visualisation-map-individualised-models) (landmark-quality models; MAX, FBX, DAE, glTF, KML per the listing ⚠ check which are textured) | Territory-wide surveyed 3D geometry, part of the LandsD 3D Digital Map ([press release](https://www.news.gov.hk/eng/2024/06/20240628/20240628_141526_695.html), [2025 completion](https://news.gov.hk/eng/2025/03/20250327/20250327_141213_296.html)). Downloads via the [CSDI portal](https://portal.csdi.gov.hk/); a streaming [3D Spatial Data API](https://portal.csdi.gov.hk/csdi-webpage/apidoc/3d-spatial-data-api) serves Cesium 3D Tiles; the data.gov.hk download API can select by LandsD 1:1000 map-sheet number and format. | **Owner-approved for use** (licence is permissive; keep attribution). Use it to: (1) replace OSM's estimated heights with surveyed ones for every building, (2) take real roof shapes, podium/tower steps and set-backs, (3) use the individualised/landmark models as the geometric base of heroes (§6.4) — used directly, simplified only if performance requires it, (4) seed filler building massing (per-lot volumes) for the generator, (5) check street-canyon proportions against our road widths. Import into Blender, apply our material/transform conversion (§3.3), export block GLBs. | Attribution to the Government/Lands Department and DATA.GOV.HK is required by the [data.gov.hk terms](https://data.gov.hk/en/terms-and-conditions) — add it to the README, the credits screen and `docs/ASSET_LICENSES.md`; do not strip attribution notices; no resale of the raw data. Do **not** ship the textured photo-derived tiles' textures. Follow §3.2 so we do not abuse the service. |
| **OpenStreetMap** | Already imported (`tools/import_map.py`, `tools/map_source/sheung_wan.osm`). | Keep. Possible extra tags: `building:levels`, `roof:shape`, `building:colour`, `building:material` for filler variety. | ODbL attribution already in README. |

**2. Blender-side tools**

| Tool | Notes | Verdict |
|---|---|---|
| [Blosm](https://github.com/vvoovv/blosm) (source on GitHub; free + paid tiers) | OSM/terrain importer; free tier untextured; slow with tens of thousands of objects ([thread](https://blenderartists.org/t/blosm-import-of-google-3d-cities-openstreetmap-terrain/608089)). Licence ⚠ check repo. | Optional pre-visualisation; not needed, we already have footprints. |
| [Buildify](https://paveloliva.gumroad.com/l/buildify) ([CGChannel](https://www.cgchannel.com/2022/07/download-free-blender-3d-building-generator-buildify/)) | Free (pay-what-you-want) Geometry Nodes modular-building library; announced for Blender 3.2; works with Blosm footprints. Licence ⚠, compatibility with Blender 5.2 ⚠. | **Study its node design** for our generator; probably not usable as-is. |
| [Auto-Building](https://auto-building.readthedocs.io/) | Add-on that fills tagged faces of a low-poly mass with walls, windows, trims and roofs from collections you model. Licence ⚠, Blender 5.x support ⚠. | **Best architectural reference** for our "kit collections + generator" (§6.3). Try it on one block before deciding to write our own. |
| Paid: [Pro City – Hong Kong](https://superhivemarket.com/products/pro-city-hong-kong/docs), [MBG](https://superhivemarket.com/products/mbg-building-geometry-nodes), [Urban Forge](https://superhivemarket.com/products/urbanforge/docs), [CityMaker](https://superhivemarket.com/products/citymaker) | Commercial generators. Urban Forge and CityMaker list a GPL licence ⚠. | Don't buy without owner approval. Generated geometry is normally not covered by an add-on's licence, but confirm per product. |
| [CityShip thread](https://blenderartists.org/t/cityship-a-city-exports-as-one-giant-file-so-i-made-it-split-into-zones-that-snap-back-together/1652332) | Someone solved "a city exports as one giant file" by splitting into zones that snap back together. | Same problem as our block export; read for ideas. |

**3. Godot-side tools**

| Tool | Notes | Verdict |
|---|---|---|
| [CityCrafter3D](https://github.com/immaculate-lift-studio/CityCrafter3D) (MIT per its listing ⚠) | Slot/grid-based city generator for Godot 4. | Grid-based and generic, wrong fit for OSM footprints. Skim its assembly code only. |
| [Godot Road Generator](https://github.com/TheDuckCow/godot-road-generator) (MIT) | Road meshes. | Not needed; roads are already built and tested. |
| [Gaea](https://awesome.ecosyste.ms/projects/github.com%2Fgaea-godot%2Fgaea) | General procedural-generation add-on. | Not needed. |

**4. Content (textures, props)**

| Source | Licence | Use |
|---|---|---|
| [Poly Haven](https://polyhaven.com/license) textures/models | CC0 (per [FAQ](https://polyhaven.com/faq)) | **Source material to bake into our stylised atlases** (concrete, ceramic tile, brick, shutter metal, asphalt). Check each asset page. |
| [ambientCG](https://ambientcg.com/) | CC0 (per third-party guides ⚠, confirm on site) | Same as above; larger material catalogue. |
| [Quaternius LowPoly Modular Street](https://quaternius.itch.io/lowpoly-modular-street) | CC0, FBX/OBJ/Blend | Generic street props (bins, bollards, lamp posts) if contents suit; restyle to our palette. HK-specific pieces (guardrails, signals, AC units) are modelled by us. |
| [Kenney assets](https://kenney.nl/assets/city-kit-roads) / [Retro Urban Kit](https://opengameart.org/content/retro-urban-kit) | CC0 | Generic props only; rejected before for roads. |
| [Free Blender neon sign pack (RenderHub)](https://www.renderhub.com/magiccgistudios/glow-neon-sign-asset-pack) | Licence ⚠ | Study; our signs are bilingual HK blade signs we generate. |
| Paid HK kits: Fab ["Hong Kong Old Tenement Building"](https://www.fab.com/listings/67c374cb-ef9e-413c-a812-ea287fdc8720) (FBX/OBJ/BLEND, licence ⚠), CGTrader [HK-style building pack with AC units and neon](https://www.cgtrader.com/3d-models/exterior/street-exterior/japanese-hong-kong-styled-building-pack) (royalty-free, ~$4.49), CGTrader [HK neon sign bundles](https://www.cgtrader.com/3d-models/exterior/other/hong-kong-neon-sign-v05-bundle) | Royalty-free, **not CC0** | **Reference only** unless the owner approves a purchase. Do not use the "free for evaluation only" Unity HK city pack. Do not import photo-derived textures. |
| Art breakdowns: [Lucky Mountain HK street](https://sketchfab.com/blogs/community/art-spotlight-lucky-mountain-games-environment-prototype), [Kowloon back alley](https://80.lv/articles/kowloon-beauty-of-the-back-alley/), Polycount [Hong Kong threads](https://polycount.com/discussions/tagged/hong-kong) | Copyrighted | Learn from, do not copy. |

**Not found:** no free, CC0, Sheung Wan–style tenement kit; no free HK-specific kit covering AC units, scaffolding, blade signs and shopfronts together. Plan to model the kit ourselves, using the reusable items above as inputs (geometry for checking, CC0 textures for baking, generic props for filling).

**Reuse policy for Codex Astra.** (1) Prefer CC0 and our own work. (2) Anything needing attribution gets an in-game credits line and an entry in `docs/ASSET_LICENSES.md`. (3) No paid asset without owner approval. Free open-data downloads that the owner has cleared (the Lands Department data) are fine, under the etiquette in §3.2. (4) Never mix photo-derived textures into the atlas. (5) If a licence is unclear, treat it as reference-only.

### 3.2 Using the Lands Department data politely (do not abuse the service)

The owner has cleared the licence and asked that we **not abuse the API**. The services are public infrastructure; treat them as such.

1. **Download once, cache locally, never re-fetch.** Fetch only what the district needs (our bounds: `[-560,-330,560,330]` m around 114.1515 E, 22.2858 N, 0.8× projection; add ~200 m margin for context buildings — convert to lat/lon with `district.json`'s `projection`), not the territory. Prefer the **bulk download route** (CSDI portal / data.gov.hk download API, selecting by the 1:1000 map-sheet numbers covering Sheung Wan and western Central) over streaming tiles through the 3D API.
2. **The data is in the repository** (owner decision, 2026-11-16): the sheet zip `tools/map_source/landsd/raw/11-SW-8A_GLTF0.zip` is tracked with **Git LFS** (run `git lfs pull` after cloning); the extracted copy under `tools/map_source/landsd/extracted/` is git-ignored and re-created from the zip by `python3 -I tools/city/landsd_index.py <SHEET>`. Provenance is in `tools/map_source/landsd/SOURCE.md` (dataset URL, sheet, retrieval date, size, SHA-256, attribution). All later steps read from the repo copy. **Add each new sheet the same way** (one download, commit the zip via LFS, update SOURCE.md and `docs/ASSET_LICENSES.md`).
3. **Be gentle if you must hit an API:** one request at a time, a descriptive `User-Agent` that names the project and a contact address the owner supplies (don't invent one, and don't put the owner's personal details in it without asking), a pause of at least 1 s between requests, exponential back-off on any 429/5xx and stop after a few failures, honour `Retry-After`, and never loop or poll. No parallel or scripted crawling of tiles outside our bounding box. Dry-run first: compute and print the list of files/tiles and their total size before fetching anything, and tell the owner the count and size if it exceeds ~500 MB.
4. **Be idempotent:** skip files that already exist with the same size/checksum; resumable downloads; no "re-download all" flag in the scripts.
5. **State the total** (files, MB) in the Phase 0 note before and after downloading. If a request fails, report it; don't retry in a tight loop.
6. **What goes into the repo:** the raw sheet zips (Git LFS), the importer/extractor scripts, derived indexes (`assets/map_data/landsd_<SHEET>_index.json`), the exported block GLBs (Git LFS), and the attribution. **Not** any photo-derived tile textures.
7. **Attribution** (required by the data.gov.hk terms): add a line to the README geographic-attribution section, the in-game credits screen and `docs/ASSET_LICENSES.md`, naming the Lands Department / HKSAR Government as the source and DATA.GOV.HK as the portal, e.g. "3D building data: © Lands Department, HKSAR Government, via DATA.GOV.HK". Check the dataset page for the exact wording before using this one.

**Practical workflow**

1. Dry-run: list the sheets/tiles that intersect our bounds; show size.
2. Download once into `tools/map_source/landsd/`.
3. `tools/city/landsd_to_blender.py`: import each building's glTF from the extracted sheet, place it with the game transform (§3.3), and write per-block `.blend`/GLB. Use `assets/map_data/landsd_<SHEET>_index.json` to select buildings by game coordinates and to compare with OSM footprints/heights in `district.json`. Heights and roof shapes come straight from the meshes.
4. Feed those numbers into the generator (§6.3) and use the hero meshes as the base for hand-modelling (§6.4).
5. Add a test in `tests/test_city_blocks.gd`: surveyed height vs. built height within ±1.5 m for all named buildings.

### 3.3 Trial download: what we actually got (2026-11-16)

One sheet was downloaded to test usefulness (details and checksum in `tools/map_source/landsd/SOURCE.md`; licence logged in `docs/ASSET_LICENSES.md`).

**Download route that works** (replaces guesswork in §3.2): per-sheet zips at `https://download.map.gov.hk/api/3d-zip/GLTF0/<SHEETNO>.zip` (`GLTF0` = non-textured glTF; `FBX0`/`MAX0` also exist; without the `0` it is the individualised product). The sheet numbers and polygons come from LandsD's own sheet index (a GeoJSON; a mirror is in [Dorian1729/3D-Visualisation-Map](https://github.com/Dorian1729/3D-Visualisation-Map), third party), and the URLs in that index carry a public key. The portal's *3D Spatial Data API* (Cesium 3D Tiles) needs a free key requested from `3dmap@landsd.gov.hk`; we do not need it. The server is slow (≈70 KB/s here) but supports HTTP `Range`, so resume with `curl -C -` rather than restarting.

**Which sheets we need.** Sheet `11-SW-8A` (53 MB) covers the **western half of the game map** (game x −418…64, z −300…80): Western Market, Bonham Strand, Dried Seafood Street, much of the waterfront. The eastern half and the Hollywood/Man Mo/PMQ hills are in neighbouring sheets: find them by intersecting the game bounds with the index polygons, and fetch them one at a time (expect roughly 3–5 sheets, a few hundred MB), only when the phase that needs them starts.

**What is in it.** 762 buildings, one glTF each, 376k triangles total (median 249 tris, max 19.6k; the 10 heaviest hold 24 % of all triangles; 23 buildings exceed 2,000 tris). Heights: 493 below 30 m, 112 at 30–60 m, 130 at 60–100 m, 27 above 100 m (max 166 m). Positions are in HK1980 Grid; `tools/city/landsd_index.py` converts them to game coordinates and writes `assets/map_data/landsd_11-SW-8A_index.json` (id, x, z, ground, height, tris, file). The conversion was validated against OSM footprints: median offset about 0.5–1 m, so overlaying is reliable.

**Quality (see `captures/landsd/westernmkt_top.png` and `westernmkt_oblique.png`, Blender Workbench renders of the raw data around Western Market).** Far better massing than OSM extrusions: real podium/tower steps, set-backs, pitched roofs, colonnades with columns, recessed window bands on some towers, plant rooms and parapets. It is **untextured geometry with one material and a vertex colour**, no balconies, AC units, signs or shopfronts. Hence it solves silhouette and heights, not facade detail.

**Does it help? Yes, with limits:**
- **Heights.** A crude centroid match (within 6 m, 143 pairs) of our current building heights against surveyed ones showed almost no correlation (r ≈ 0.05; 62 % differ by more than 10 m; surveyed median 25 m vs. our 33 m). The match is crude (our footprints are clipped parts), so redo it by polygon overlap, but it strongly suggests our OSM-derived heights are largely wrong and the skyline is too tall. Replacing them is the cheapest big win.
- **Massing/roofs for filler.** Use surveyed per-building volumes (and their steps/roofs) as the generator's base mass, then add lots, facades and clutter on top (§6.3).
- **Heroes.** A very good starting mesh (e.g. the ~13k-triangle complex next to Western Market). Use it directly and add detail (signs, awnings, balconies, lettering) as separate meshes on top.

**Owner decision: build from these meshes. Use them as they are, and simplify only if performance becomes an issue.** Codex Astra must not pre-emptively decimate, re-model or replace them. They are low-poly already (median 249 tris, 376k tris for the 762 buildings of the sheet, the same order of magnitude as the budget in §6.6). Simplify a building only when a profiler capture shows it is a cost (see "Performance-driven simplification" below).

**Required conversion (not simplification):**
1. **Material:** each glTF has one default material and `COLOR_0` vertex colour. Assign our atlas/toon material (§7) to every mesh. Keep the geometry untouched. Add UVs only where the atlas needs them (box-project walls with per-floor repeat) — a UV/attribute change, not a geometry change.
2. **Scale:** heights are real metres but our horizontal projection is **0.8×**. Scale x/z by 0.8 and keep y as `landsd_index.py` and the Blender preview did; otherwise towers look too thin against the streets.
3. **Ground:** the models sit at surveyed ground height; our terrain is smoothed (`D.road_height`). Snap each building's base to the game terrain and add a foundation skirt (§6.2) instead of editing the mesh walls.
4. **Road clearance:** the game's roads are widened, so some meshes will intrude into road corridors. **Do not move or shrink roads.** Check each building against the road corridor (as `tools/import_map.py` does); for the few that intrude, trim only the intruding part (Blender boolean/bisect) or, if cheaper, nudge the whole building out. Re-use the Hollywood regression test and the physical driving run (§8).
5. **Ignore** `INFRASTRUCTURE` and `TERRAIN(TB)` (the terrain tile is half the data). They stay in the zip, unused unless a later need appears.
6. **Grouping:** group buildings into street blocks (§4). Merging meshes by block for draw-call reasons is encouraged but not mandatory; do it if node/draw-call counts require, preserving each building's geometry.

**Performance-driven simplification (only if needed).** Triggers: a block over the triangle/draw-call budget (§6.6) in a profiler capture, or frame-time spikes traced to a specific mesh. Order of remedies: (a) visibility ranges and occluders (§7), (b) LOD1 via Godot's automatic mesh LOD or Blender decimate on distant versions, (c) merge by block, (d) decimate or rebuild the specific heavy buildings (the 23 above ~2,000 tris, e.g. podium complexes and multi-storey car parks). Record the measurement that justified each simplification in `docs/VALIDATION.md`.

**Next step for Codex Astra (Phase 0):** write `tools/city/landsd_to_blender.py` (see §3.2 workflow) that imports the buildings of the stop-5 (Bonham Strand) block from the repo copy, applies the conversion above, and exports the first block GLB; compare it against OSM footprints and heights; show the owner side-by-side screenshots in Godot.

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

- **Style (owner: undecided, working default for now):** stylised toon with real proportions and clutter — flat colour with the existing 3-band toon lighting. Silhouette first; texture detail second. **Because the final look is undecided, keep geometry and look separable:** buildings export geometry + UV layout + vertex colour only; the *look* lives in a material/atlas that can be swapped without re-exporting blocks. Phase 0 must therefore show **two looks of the same block** (A: flat toon atlas; B: more painterly/realistic atlas, still original or CC0 textures, still the same Forward+ shader pipeline) so the owner can choose.
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
- Keep `.blend1` out of git (already ignored). Large `.glb` outputs: expect 60–120 blocks × 0.5–3 MB.
- **Git LFS is approved.** Set it up in Phase 0, before the first binary asset is committed: `git lfs install`, then a `.gitattributes` tracking at least `*.blend`, `*.glb`, and large texture atlases (`assets/city/**/*.png`). Do not rewrite existing history; only new binaries go to LFS. Check whether the owner's `git lfs` is installed (`git lfs version`) and tell them to `brew install git-lfs` if not. Keep `.import` files and small scripts as normal git objects. Do not track the old 41 MB `scenes/district.tscn` in LFS; it is being replaced.

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

Build each in its own `.blend`, starting from the Lands Department mesh of that building (used as is, no pre-emptive decimation), plus our detail meshes on top, one atlas, with LOD1 only if the profiler needs it. Footprints and approximate height come from `district.json` (`landmarks` and named buildings). Priority:

The owner asked for **more heroes** (2026-11-16). Hero list, in build order. Tier A are stop landmarks and drive the first screenshots; B and C are named in `district.json` and must be located there first (query `buildings[].name`; check each is inside the 1,120 × 660 m bounds and note its footprint/height).

**Tier A — stop landmarks (full hand-modelled, LOD0 + LOD1):**
1. **Western Market** (stop 1) — red-brick Edwardian, cream string courses, arched openings, corner turret, lettering.
2. **Man Mo Temple + Lit Shing Kung** (stop 8) — grey brick, green-tile pitched roofs with ridge ornaments, red doors, lanterns, incense coils, courtyard.
3. **Central Market** (stop 10) and **PMQ** (stop 9) — recognisable massing, balconies, courtyards.
4. **Sheung Wan Municipal Services Building** (market + complex, near stop 12) and **Sheung Wan MTR station entrance/vent shaft** (stop 12).
5. **Macau Ferry Terminal / Shun Tak Centre twin towers** (stop 2).
6. **Hollywood Road Park pavilions and gate** (stop 6) and **Dried Seafood Street** corner buildings (stop 4, hand-polished tenement block rather than a landmark).

**Tier B — recognisable street-level buildings (hand-modelled, simpler, ~3–8k tris):**
- **Sheung Wan Fire Station**, **Ying Wa Girls' School**, **Rumsey Street Multi-Storey Car Park** (distinctive open-deck facade), **Wing On Centre**, **Cosco Tower**, **Hang Seng Bank Headquarters**, **Infinitus Plaza**.
- Any other named building in `district.json` that sits on a bus route or next to a stop (`D.STOP_POS`) and has a distinctive silhouette. Propose additions to the owner with a screenshot before modelling.

**Tier C — skyline silhouettes (far LOD only, < 2k tris):**
- **The Center** (346 m crown), **IFC**, **Exchange Square**, **China Merchants Tower**, **Man Yee / Midland Plaza** and other towers taller than ~100 m.

Use the Lands Department 3D meshes (§3.1–§3.3) as the geometric base for every hero in §6.4 wherever the sheet covers it: extract the building, convert it as in §3.3, then add our stylised detail (signs, lettering, awnings, balconies, roof ornaments) as separate meshes on top. Do not simplify unless the profiler says so. Where a hero is missing or wrong in the data (e.g. temple roofs), model it by hand. Check massing, height and roof shape against the data before finishing each hero.

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
- **Materials.** Reuse the toon look. Convert `assets/shaders/facade.gdshader` into an *atlas toon* shader (albedo atlas + vertex colour + three-band light); keep a `glass` variant. **A night variant is planned (owner: yes), so build night-ready now:** the atlas has an emissive-mask channel (windows, shop interiors, lightboxes, neon-style signs; a separate material slot for signs so they can glow independently), per-window variation so lit/unlit windows are not uniform, and lamp posts as separate nodes ready for a few real `OmniLight3D`/`SpotLight3D`s near the camera (not hundreds). Provide a `day` and a `night` `Environment` preset (sky, ambient, fog, glow, sun/moon energy) and have `assemble_city.gd` switch between them. Verify both on the Phase 0 block. Shader parameters, not duplicate meshes, select day/night.
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
First migrate to Forward+ (§7.1) and show the before/after captures of the *existing* city, so renderer changes are not confused with art changes. Then choose the **Bonham Strand stop (stop 5)** block plus the cross street toward Wing Lok. Build `kit.blend` with the minimum kit (2 facade families, 6 shopfront types, 10 props), the generator for that block, export, `assemble_city.gd`, drive past it in-game. Render it in **both looks (A toon / B painterly, §5) and in day and night**. Deliver the side-by-side with the Bonham Strand photos and the numbers from §8. **STOP: owner reviews and picks the art direction before Phase 1.** Also in Phase 0: Git LFS setup (§6.1), `docs/ASSET_LICENSES.md`, and a Lands Department data check for the hero buildings in this block (§3.1).

**Phase 1 — corridor.** Generate blocks along Des Voeux Road Central → Bonham → Wing Lok → Des Voeux West (stops 1, 4, 5, 10, 12). Add tram-corridor props (wires/poles exist; add traffic lights, guardrails, crossings). Remove procedural buildings in those blocks from the old scene.

**Phase 2 — heroes.** Tier A (§6.4) first, with stop screenshots after each; then Tier B; Tier C silhouettes in Phase 4. Each hero is verified against Lands Department massing and the reference photos.

**Phase 3 — whole district.** Hollywood/Cat Street/SoHo hill blocks (set-back stepping on slopes), waterfront blocks, ferry terminal. Delete the legacy `building()` path once all blocks exist.

**Phase 4 — atmosphere and static dressing.** Trees and planters, bamboo scaffolding on selected buildings, Tier C skyline silhouettes, far Mid-Levels hillside backdrop (low-poly mass), Kowloon skyline, new day sky/fog/light grade and the **night preset** (§7). **No vehicles or pedestrians in this milestone.**

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

## 11. Owner decisions (2026-11-16) and remaining open items

| # | Question | Decision |
|---|---|---|
| 1 | Art direction | **Undecided.** Working default: stylised toon with real proportions. Phase 0 shows toon (A) vs. painterly (B); owner picks (§5, §9). Keep look swappable. |
| 2 | Hero scope | **More heroes.** Tiered list in §6.4 (A stop landmarks, B street-level named buildings, C skyline). |
| 3 | Night variant | **Yes.** Build emissive masks, separate sign materials, day/night presets from Phase 0 (§7). |
| 4 | Git LFS | **Yes.** Set up in Phase 0 for `*.blend`, `*.glb`, atlases (§6.1). |
| 5 | Traffic / pedestrians | **Out of scope.** This milestone is static buildings and street blocks only (rule 11). |
| 6 | Renderer | **Not `gl_compatibility`.** Forward+ (§7.1). |

Still open (ask the owner when you reach them, don't guess): (a) the final art direction after the Phase 0 A/B; (b) whether to buy any paid HK-specific kit listed in §3.1 (needs owner approval and licence review).

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
- Reusable data, tools and content: see §3.1 (each item linked inline there)
