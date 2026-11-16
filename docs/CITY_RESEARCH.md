# City Research — background for the city build

**Audience:** the owner and anyone who wants the evidence behind [CITY_BUILD_GUIDE.md](CITY_BUILD_GUIDE.md). Codex Astra does **not** need to read this to build; the guide has the decisions and instructions. Research done 2026-11-16. Licence notes are from search results and listing pages, not legal review (⚠ = unverified).

Contents: **A.** screenshots vs. real photos · **B.** reference photos · **C.** how other people build cities · **D.** reusable data, tools and content · **E.** sources.

---

## A. What is wrong with the current city (screenshots vs. real photos)
Game captures reviewed: `captures/map_desvoeux.png`, `map_bonham.png`, `map_manmo.png`, `map_overview.png`, `review_driving.png`.
Real references (all Wikimedia Commons, CC-licensed, linked in section B): Des Voeux Rd Central / Cleverly St (tram), Bonham Strand (Gee Tuck Building, Cleverly St), Wing Lok Street, Hollywood Rd / Lok Ku Rd.

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

## B. Reference photo set (look, don't copy)

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

**Method note:** the analysis in section A used these Commons photos, not Google Street View (Street View cannot be embedded in a script and its terms forbid reuse). The owner can open Google Street View at the stop coordinates (`D.STOP_POS` → lat/lon via the projection in `district.json`: origin 114.1515 E, 22.2858 N, 0.8× scale) for extra checking. Use it for looking only.

---

## C. How other people build cities, and how they compare

Research performed 2026-11-16. Sources linked inline; treat vendor pages as marketing.

| # | Approach | How it works | Pros | Cons | Fit here |
|---|---|---|---|---|---|
| A | **Current: GDScript extrudes OSM footprints + shader facade** | Footprint → prism; window pattern in a fragment shader; boxes for props, baked into a `.tscn` | Real street layout, tiny repo footprint, fully scripted, great for collision | Generic look; no silhouette detail (balconies, stairs, roof clutter); 41 MB scene; hard to art-direct; every improvement is more code | **Keep only for roads/terrain/collision** |
| B | **OSM → Blender add-on (Blosm / BlenderGIS)** — [Blosm](https://github.com/vvoovv/blosm), [BlenderGIS OSM import](https://github.com/domlysz/BlenderGIS/wiki/OSM-import) | One-click import of footprints with height/levels, terrain, roofs; premium adds textures/Geometry Nodes | Fast blockout of real areas; reads tags; global coverage | Output is a base to refine, not final art; gaps where OSM unmapped; thousands of objects freeze Blender (import-as-single-mesh workaround); free version untextured | **Use as optional pre-vis only.** We already have clean footprints in `district.json` |
| C | **Procedural generators in Blender (Geometry Nodes)** — e.g. free [Auto-Building](https://auto-building.readthedocs.io/), paid [MBG](https://superhivemarket.com/products/mbg-building-geometry-nodes), [Pro City – Hong Kong](https://superhivemarket.com/products/pro-city-hong-kong/docs), [PBG 2](https://blendermarket.com/products/pbg-2/docs) | Low-poly mass → modular walls/windows/balconies/roofs instanced from *your* collections | Fast variation; art stays in your kit; re-runnable when footprints change; can export per block | Third-party styles aren't Sheung Wan; paid licences to vet; live modifiers must be applied before export; docs rarely cover game export, UVs or atlasing | **Best base for filler buildings** — but build *our own* small GN/Python generator driven by our own kit (guide §5). Study Auto-Building's "collections of parts" design |
| D | **Fully hand-modelled buildings** | Artist models each building | Best silhouette and character; total control | Very slow; cannot cover ~800 footprints | **Heroes only** (~10–25 buildings) |
| E | **Hero + filler split** — see [hero vs. filler workflow](https://www.tripo3d.ai/blog/city-block-generator), [Houdini city workflows](https://80.lv/articles/learn-how-to-make-procedural-building-generator-in-houdini/) | Procedural layout produces footprints/massing; hand-made heroes are anchors; tiling filler meshes are instanced | How most production cities are made; effort goes where the player looks | Needs a clean boundary between hero and filler and a naming convention | **Recommended** (this is guide §4) |
| F | **Houdini / Houdini Engine pipelines** — e.g. [OSM → Houdini → Unity](https://80.lv/articles/generating-cities-with-unity-houdini-openstreetmap-data), Epic's [City Sample](https://dev.epicgames.com/documentation/unreal-engine/city-sample-quick-start-for-generating-a-city-and-freeway-using-houdini) | Node-based procedural layout + facade rules | Industry-strength; great control | No Houdini Engine plugin for Godot (bake to GLB instead); licence cost; Police Simulator team found generation times slow and fell back to grayboxing ([80.lv](https://80.lv/articles/creating-an-open-world-environment-in-police-simulator-patrol-officers/)) | Not now |
| G | **Photogrammetry / Google Photorealistic 3D Tiles (Cesium)** — [Cesium terms discussion](https://community.cesium.com/t/can-i-make-a-videogame-with-cesium-for-unreal/28962) | Stream real captured city | Instantly real | Must be streamed, cannot ship or edit; free tier non-commercial only; attribution/logo required; no Godot-native path; wrong art style; can't isolate/extract buildings | **No** |
| H | **Off-the-shelf modular kits** — e.g. [Kenney City Kit](https://kenney.nl/assets/city-kit-roads), itch.io/Superhive "modular city" packs | Drop pre-made pieces on a grid | Free/cheap, GLB-ready, trim-sheet efficient | Western/generic; wrong proportions (HK is vertical, narrow, cluttered); the repo already evaluated and rejected Kenney (RESEARCH.md) | Use only for non-HK-specific props (bins, bollards) if licence allows |
| I | **Stylised hand-kit + vertex colour (the "Lucky Mountain" approach)** — [Sketchfab write-up](https://sketchfab.com/blogs/community/art-spotlight-lucky-mountain-games-environment-prototype) | Small flat-colour low-poly kit; vertex colour instead of textures; palette from film reference | Very cheap to render; cohesive; fits our toon shader; proves Hong Kong street can be done low-poly | Needs disciplined palette and silhouette work | **Matches our style** — use vertex colour + a small atlas |
| J | **Trim sheets + shared atlas** — e.g. [modular kits sharing one trim sheet](https://sigilsvault.itch.io/modular-cathedral-kit) | All pieces share 1–2 textures | Few materials → few draw calls; consistent look | UV discipline required | **Required** — few materials keep draw calls and texture lookups low in any renderer (guide §9) |

**Verdict.** Approach **E** (hero + filler) built with **C** (our own Blender kit and generator) and **I/J** (flat-colour kit + shared atlas), keeping **A**'s road/terrain/collision. This is also your preference: author buildings and street blocks in Blender, instance them in Godot.

---

## D. Reusable data, tools and content

Licences below are from search results and listing pages, **not legal review**. Verify on the source page before shipping anything, and record each item in `docs/ASSET_LICENSES.md` (source URL, licence, date checked, what was changed, attribution text). Anything unverified is marked ⚠.

**1. Real Hong Kong building geometry — the most valuable find**

| Resource | What it is | How to use it | Caveats |
|---|---|---|---|
| **HK Lands Department 3D Visualisation Map** — [non-textured models](https://data.gov.hk/en-data/dataset/hk-landsd-openmap-3d-visualisation-map-non-textured-models) (**glTF, FBX, MAX**; building, infrastructure and terrain geometry) and [individualised models](https://data.gov.hk/en-data/dataset/hk-landsd-openmap-3d-visualisation-map-individualised-models) (landmark-quality models; MAX, FBX, DAE, glTF, KML per the listing ⚠ check which are textured) | Territory-wide surveyed 3D geometry, part of the LandsD 3D Digital Map ([press release](https://www.news.gov.hk/eng/2024/06/20240628/20240628_141526_695.html), [2025 completion](https://news.gov.hk/eng/2025/03/20250327/20250327_141213_296.html)). Downloads via the [CSDI portal](https://portal.csdi.gov.hk/); a streaming [3D Spatial Data API](https://portal.csdi.gov.hk/csdi-webpage/apidoc/3d-spatial-data-api) serves Cesium 3D Tiles; the data.gov.hk download API can select by LandsD 1:1000 map-sheet number and format. | **Owner-approved for use** (licence is permissive; keep attribution). Use it to: (1) replace OSM's estimated heights with surveyed ones for every building, (2) take real roof shapes, podium/tower steps and set-backs, (3) use the individualised/landmark models as the geometric base of heroes (guide §6) — used directly, simplified only if performance requires it, (4) seed filler building massing (per-lot volumes) for the generator, (5) check street-canyon proportions against our road widths. Import into Blender, apply our material/transform conversion (guide §3), export block GLBs. | Attribution to the Government/Lands Department and DATA.GOV.HK is required by the [data.gov.hk terms](https://data.gov.hk/en/terms-and-conditions) — add it to the README, the credits screen and `docs/ASSET_LICENSES.md`; do not strip attribution notices; no resale of the raw data. Do **not** ship the textured photo-derived tiles' textures. Follow guide §3 so we do not abuse the service. |
| **OpenStreetMap** | Already imported (`tools/import_map.py`, `tools/map_source/sheung_wan.osm`). | Keep. Possible extra tags: `building:levels`, `roof:shape`, `building:colour`, `building:material` for filler variety. | ODbL attribution already in README. |

**2. Blender-side tools**

| Tool | Notes | Verdict |
|---|---|---|
| [Blosm](https://github.com/vvoovv/blosm) (source on GitHub; free + paid tiers) | OSM/terrain importer; free tier untextured; slow with tens of thousands of objects ([thread](https://blenderartists.org/t/blosm-import-of-google-3d-cities-openstreetmap-terrain/608089)). Licence ⚠ check repo. | Optional pre-visualisation; not needed, we already have footprints. |
| [Buildify](https://paveloliva.gumroad.com/l/buildify) ([CGChannel](https://www.cgchannel.com/2022/07/download-free-blender-3d-building-generator-buildify/)) | Free (pay-what-you-want) Geometry Nodes modular-building library; announced for Blender 3.2; works with Blosm footprints. Licence ⚠, compatibility with Blender 5.2 ⚠. | **Study its node design** for our generator; probably not usable as-is. |
| [Auto-Building](https://auto-building.readthedocs.io/) | Add-on that fills tagged faces of a low-poly mass with walls, windows, trims and roofs from collections you model. Licence ⚠, Blender 5.x support ⚠. | **Best architectural reference** for our "kit collections + generator" (guide §5). Try it on one block before deciding to write our own. |
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

**Reuse policy for Codex Astra.** (1) Prefer CC0 and our own work. (2) Anything needing attribution gets an in-game credits line and an entry in `docs/ASSET_LICENSES.md`. (3) No paid asset without owner approval. Free open-data downloads that the owner has cleared (the Lands Department data) are fine, under the etiquette in guide §3. (4) Never mix photo-derived textures into the atlas. (5) If a licence is unclear, treat it as reference-only.

---

## E. Sources

- Godot docs: [Model export considerations](https://docs.godotengine.org/en/4.4/tutorials/assets_pipeline/importing_3d_scenes/model_export_considerations.html), [Node type customization (name suffixes)](https://docs.godotengine.org/en/4.2/tutorials/assets_pipeline/importing_3d_scenes/node_type_customization.html), [Optimizing 3D performance](https://docs.godotengine.org/en/4.4/tutorials/performance/optimizing_3d_performance.html)
- Godot forum: [Understanding batching in Godot 4](https://forum.godotengine.org/t/understanding-batching-in-godot-4/65635)
- Blender → Godot checklist: [Cinevva guide](https://app.cinevva.com/guides/blender-to-godot-export-checklist)
- OSM in Blender: [Blosm](https://github.com/vvoovv/blosm), [BlenderGIS OSM import](https://github.com/domlysz/BlenderGIS/wiki/OSM-import)
- Procedural building generators: [Auto-Building docs](https://auto-building.readthedocs.io/), [MBG](https://superhivemarket.com/products/mbg-building-geometry-nodes), [Pro City – Hong Kong](https://superhivemarket.com/products/pro-city-hong-kong/docs), [PBG 2](https://blendermarket.com/products/pbg-2/docs)
- Pipelines: [Hero vs. filler city workflow](https://www.tripo3d.ai/blog/city-block-generator), [Houdini procedural building generator](https://80.lv/articles/learn-how-to-make-procedural-building-generator-in-houdini/), [Police Simulator open-world environment](https://80.lv/articles/creating-an-open-world-environment-in-police-simulator-patrol-officers/), [Epic City Sample](https://dev.epicgames.com/documentation/unreal-engine/city-sample-quick-start-for-generating-a-city-and-freeway-using-houdini)
- Stylised Hong Kong street in low poly: [Lucky Mountain Games environment](https://sketchfab.com/blogs/community/art-spotlight-lucky-mountain-games-environment-prototype)
- Trim-sheet kits: [Modular cathedral kit](https://sigilsvault.itch.io/modular-cathedral-kit)
- Google/Cesium terms: [Cesium community: can I make a videogame](https://community.cesium.com/t/can-i-make-a-videogame-with-cesium-for-unreal/28962), [Google 3D Tiles attribution](https://community.cesium.com/t/google-photorealistic-tiles-copyright-attribution/23999)
- Photo references: see section B (Wikimedia Commons)
- Reusable data, tools and content: see section D (each item linked inline there)
