# Lands Department 3D Visualisation Map (non-textured models) — provenance

Data © Lands Department, HKSAR Government, via DATA.GOV.HK / CSDI Portal.
Terms: https://data.gov.hk/en/terms-and-conditions and the CSDI portal terms of use
(free commercial and non-commercial use; identify the Government and the website as the source; no
removal of attribution; the terms include an indemnity clause; fair-usage policy on API calls).

Dataset: https://data.gov.hk/en-data/dataset/hk-landsd-openmap-3d-visualisation-map-non-textured-models

## What was downloaded (2026-11-16)

| Item | Value |
|---|---|
| Sheet | `11-SW-8A` (1:1000 sheet covering the western half of the game map: game x ≈ −418…64, z ≈ −300…80; includes Western Market, Bonham Strand, Dried Seafood St) |
| URL pattern | `https://download.map.gov.hk/api/3d-zip/GLTF0/<SHEETNO>.zip?key=<public key from LandsD's own sheet index>` (FBX0 / MAX0 are the other formats; `GLTF` without `0` is the individualised/textured product) |
| Sheet index | LandsD's index (sheet polygons + these URLs) as mirrored in https://github.com/Dorian1729/3D-Visualisation-Map (third party; 3,456 sheets) |
| Size | 52,863,180 bytes (zip), 103 MB extracted; 2,326 files |
| SHA-256 | `da64c7abae5f8e6d5cca776d88a109f7da9e23876dc55663577a14007f10420a` |
| Revision | server `Last-Modified: Tue, 07 Jul 2026`; index REVISIONDATE 20260717 |
| Requests made | 1 HEAD + 1 GET (interrupted by client timeout at 22 MB) + 1 resumed GET using HTTP Range. Server speed was ~70 KB/s. No other requests to the data servers. |

The raw zip is **tracked in the repository with Git LFS** (`tools/map_source/landsd/raw/11-SW-8A_GLTF0.zip`; run
`git lfs pull` after cloning). The extracted copy (`tools/map_source/landsd/extracted/`) is git-ignored and is
re-created from the zip by `python3 -I tools/city/landsd_index.py 11-SW-8A`. Further sheets follow the same
pattern: download once, add the zip under `raw/`. To fetch a new sheet, use with a resumable client (`curl -C -`), a descriptive User-Agent and no
parallel requests. Do not re-download if the zip exists and its SHA-256 matches.

## Contents of the sheet

762 `BUILDING/<id>/<id>.gltf` (+`.bin`) — one glTF per building, 11 `INFRASTRUCTURE`, 1 `TERRAIN(TB)`.
Each building glTF has a root node whose matrix places it in **HK1980 Grid** metres:
translation = (Easting, ground height, −Northing); local mesh axes are x east, y north, z up (the node matrix
rotates z-up into glTF y-up). One material, vertex colours, 16-bit/8-bit indices, no textures.

`tools/city/landsd_index.py` converts those positions to the game projection and writes
`assets/map_data/landsd_11-SW-8A_index.json` (derived; safe to commit).
