# Third-party assets and data

| Item | Source | Licence / terms | Date checked | Use in repo | Attribution |
|---|---|---|---|---|---|
| OpenStreetMap extract, `tools/map_source/sheung_wan.osm`, `assets/map_data/district.json` | https://www.openstreetmap.org | ODbL 1.0 | 2026-11-13 | Street/footprint source | README "Geographic attribution" |
| Copernicus DEM via Open-Meteo, `tools/map_source/elevation.json` | https://open-meteo.com/en/docs/elevation-api | See provider terms | 2026-11-13 | Terrain | README |
| Lands Department 3D Visualisation Map, non-textured models, sheet 11-SW-8A (raw, git-ignored) and derived `assets/map_data/landsd_11-SW-8A_index.json` | https://data.gov.hk/en-data/dataset/hk-landsd-openmap-3d-visualisation-map-non-textured-models | data.gov.hk Terms and Conditions of Use: free commercial/non-commercial use with attribution; indemnity clause; fair-usage policy. Owner reviewed and cleared use on 2026-11-16 | 2026-11-16 | Surveyed heights/massing as input for building generator and heroes; derived, simplified, restyled meshes only | "3D building data: (c) Lands Department, HKSAR Government, via DATA.GOV.HK" (confirm exact wording on the dataset page; add to README and credits screen when shipping derived data) |
