#!/usr/bin/env python3
"""Index a downloaded Lands Department non-textured glTF sheet in game coordinates.

Reads tools/map_source/landsd/extracted/<SHEET>/BUILDING/*/*.gltf (never re-downloads),
converts each building's HK1980 Grid position to the game's projection (see
assets/map_data/district.json "projection"), and writes
assets/map_data/landsd_<SHEET>_index.json.

Usage: python3 -I tools/city/landsd_index.py 11-SW-8A
Data (c) Lands Department, HKSAR Government, via DATA.GOV.HK. See tools/map_source/landsd/SOURCE.md.
"""
import glob, hashlib, json, math, os, sys, zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
# HK1980 Grid (EPSG:2326): transverse Mercator, International 1924 ellipsoid.
A, F = 6378388.0, 1 / 297.0
E2 = 2 * F - F * F
EP2 = E2 / (1 - E2)
K0, FE, FN = 0.99996, 836694.05, 819069.80
LAT0 = math.radians(22 + 18 / 60 + 43.68 / 3600)
LON0 = 114 + 10 / 60 + 42.80 / 3600
# HK1980 -> WGS84 approximation (validated against OSM footprints: residual ~0.5-1 m median).
D_LAT, D_LON = -5.5 / 3600, +8.8 / 3600


def _meridian(phi):
    e4, e6 = E2 * E2, E2 ** 3
    return A * ((1 - E2 / 4 - 3 * e4 / 64 - 5 * e6 / 256) * phi
                - (3 * E2 / 8 + 3 * e4 / 32 + 45 * e6 / 1024) * math.sin(2 * phi)
                + (15 * e4 / 256 + 45 * e6 / 1024) * math.sin(4 * phi)
                - (35 * e6 / 3072) * math.sin(6 * phi))


M0 = _meridian(LAT0)


def hk80_to_wgs84(e, n):
    m = M0 + (n - FN) / K0
    mu = m / (A * (1 - E2 / 4 - 3 * E2 ** 2 / 64 - 5 * E2 ** 3 / 256))
    e1 = (1 - math.sqrt(1 - E2)) / (1 + math.sqrt(1 - E2))
    p1 = (mu + (3 * e1 / 2 - 27 * e1 ** 3 / 32) * math.sin(2 * mu)
          + (21 * e1 ** 2 / 16 - 55 * e1 ** 4 / 32) * math.sin(4 * mu)
          + (151 * e1 ** 3 / 96) * math.sin(6 * mu) + (1097 * e1 ** 4 / 512) * math.sin(8 * mu))
    c1, t1 = EP2 * math.cos(p1) ** 2, math.tan(p1) ** 2
    n1 = A / math.sqrt(1 - E2 * math.sin(p1) ** 2)
    r1 = A * (1 - E2) / (1 - E2 * math.sin(p1) ** 2) ** 1.5
    d = (e - FE) / (n1 * K0)
    lat = p1 - (n1 * math.tan(p1) / r1) * (d ** 2 / 2 - (5 + 3 * t1 + 10 * c1 - 4 * c1 ** 2 - 9 * EP2) * d ** 4 / 24
          + (61 + 90 * t1 + 298 * c1 + 45 * t1 ** 2 - 252 * EP2 - 3 * c1 ** 2) * d ** 6 / 720)
    lon = math.radians(LON0) + (d - (1 + 2 * t1 + c1) * d ** 3 / 6
          + (5 - 2 * c1 + 28 * t1 - 3 * c1 ** 2 + 8 * EP2 + 24 * t1 ** 2) * d ** 5 / 120) / math.cos(p1)
    return math.degrees(lat) + D_LAT, math.degrees(lon) + D_LON


def to_game(lat, lon, proj):
    """Game x/z in metres (north is -z), same projection as tools/import_map.py."""
    return ((lon - proj["origin"][0]) * proj["x_m_per_deg"] * proj["scale"],
            -(lat - proj["origin"][1]) * proj["z_m_per_deg"] * proj["scale"])


def ensure_extracted(sheet):
    """Unzip tools/map_source/landsd/raw/<sheet>_GLTF0.zip (tracked in Git LFS) if not yet extracted."""
    out = os.path.join(ROOT, "tools/map_source/landsd/extracted", sheet)
    if os.path.isdir(os.path.join(out, "BUILDING")):
        return
    zip_path = os.path.join(ROOT, "tools/map_source/landsd/raw", sheet + "_GLTF0.zip")
    if not os.path.exists(zip_path) or os.path.getsize(zip_path) < 1000:
        sys.exit("Missing or LFS-pointer zip %s: run `git lfs pull`" % zip_path)
    os.makedirs(out, exist_ok=True)
    with zipfile.ZipFile(zip_path) as z:
        z.extractall(out)      # zipfile rejects path traversal
    print("extracted", zip_path, "->", out)


def main(sheet):
    ensure_extracted(sheet)
    district = json.load(open(os.path.join(ROOT, "assets/map_data/district.json")))
    proj = district["projection"]
    base = os.path.join(ROOT, "tools/map_source/landsd/extracted", sheet, "BUILDING")
    rows = []
    for path in sorted(glob.glob(os.path.join(base, "*", "*.gltf"))):
        g = json.load(open(path))
        m = g["nodes"][0]["matrix"]          # translation = (Easting, ground height, -Northing)
        pos = g["accessors"][0]
        lat, lon = hk80_to_wgs84(m[12], -m[14])
        x, z = to_game(lat, lon, proj)
        rows.append({"id": os.path.basename(path)[:-5], "x": round(x, 2), "z": round(z, 2),
                     "ground": round(m[13], 2), "height": round(pos["max"][2] - pos["min"][2], 2),
                     "tris": g["accessors"][3]["count"] // 3,
                     "file": os.path.relpath(path, ROOT)})
    out = os.path.join(ROOT, "assets/map_data/landsd_%s_index.json" % sheet)
    json.dump({"sheet": sheet, "source": "Lands Department, HKSAR Government, via DATA.GOV.HK",
               "buildings": rows}, open(out, "w"), separators=(",", ":"))
    print("wrote", out, len(rows), "buildings")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "11-SW-8A")
