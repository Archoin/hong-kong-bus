# Research and visual direction

Research performed on 13 November 2026. The game interprets its references; it does not reproduce a surveyed road layout or any operator's branding.

## Hong Kong minibus

- [Transport Department — Fact Sheet on Transport](https://www.td.gov.hk/en/publications_and_press_releases/publications/free_publications/fact_sheet_on_transport/index.html): public light buses have no more than 19 seats; red minibuses have flexible routes while green services use fixed routes. This informed the default capacity and the red-roof player identity.
- [Transport Department — Road Users' Code, Public Transport](https://www.td.gov.hk/en/road_safety/road_users_code/index/chapter_3_for_passengers/public_transport/index.html): red-roof minibuses use a yellow body. The model uses a warm cream/yellow body, red roof, large windows, destination box, mirrors and compact proportions.
- [Wikimedia Commons — Rmb le9372.jpg](https://commons.wikimedia.org/wiki/File:Rmb_le9372.jpg): photographic reference for the older Coaster-style silhouette and placement of window pillars, roof sign and body trim. The photo itself is not included in the project.

The vehicle mesh is original, generated in Blender and retained as both `.blend` source and `.glb`. It has no Toyota badge, copied texture or third-party mesh. The green Jade Express is a fictional game variant, not a claim about real green-minibus route rules or upgraded legal capacity.

## District

- [Hong Kong Tourism Board — Hollywood Road](https://www.discoverhongkong.com/eng/neighbourhoods/hollywood-road.html): inspiration for the mix of shops, cultural landmarks, narrow streets and old-town character.
- [Hong Kong Tourism Board — Man Mo Temple](https://www.discoverhongkong.com/eng/place-to-go/travel.guide-man-mo-temple.html): landmark and Hollywood Road context.
- [MTR — Sheung Wan Station street map](https://www.mtr.com.hk/archive/ch/services/maps/shw.pdf): reference for the relationship of waterfront streets, Des Voeux Road, Queen's Road and Hollywood Road.
- [Lands Department — Sheung Wan / Central district map](https://www.landsd.gov.hk/doc/en/mapping/ehkg/MapPages/GeoPDF/HK03_SheungWan_CentralDistrict.pdf): wider geographic context and harbor orientation.

The playable street grid is deliberately simplified, flattened and compressed. Western Market, Harbour Pier, Central Market, Pottinger Street, Man Mo Temple and Cat Street serve as memorable route-planning destinations. Yellow road markings, left-side AI lanes, striped shop awnings, air-conditioning units, bamboo scaffolding, bilingual blade signs and a distant harbor skyline provide local visual cues.

## Asset decisions

[Kenney City Kit (Roads)](https://kenney.nl/assets/city-kit-roads) was evaluated as a CC0 option. The slice instead uses original generated geometry so road widths, junctions, curbs, bays and shopfronts agree with the driving and camera requirements. No downloaded third-party art or music is shipped.

The icon, geometry, shader and audio synthesis code were created for this project. The UI asks for installed Avenir/Arial/Noto system fonts and falls back through Godot's font system; no commercial font files are redistributed. The engine is Godot 4.6.1, distributed under the MIT license.

## Technical references

- [Godot CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html): grounded collision and arcade movement.
- [Godot RenderingServer](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html): headless rendering limitations; city baking requires a renderer to retain MultiMesh buffers.
- [Godot macOS exporting](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html): universal app bundle and local ad-hoc signing.
