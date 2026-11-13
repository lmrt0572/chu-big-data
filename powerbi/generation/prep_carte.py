"""Builds the map of the 18 French regions for the Power BI shape map (TopoJSON).

Source: regions-avec-outre-mer.geojson (gregoiredavid/france-geojson, IGN Admin Express 2018, Licence ouverte).
The five overseas regions are moved into small boxes south-west of metropolitan France, each at its own scale.
Borders shared by two regions are cut into common arcs and simplified once, so that neighbours stay joined.

Usage: python prep_carte.py <regions-avec-outre-mer.geojson> <sortie.json>
"""
import json
import math
import sys

SOURCE, SORTIE = sys.argv[1], sys.argv[2]
TOLERANCE = 0.012          # simplification step in degrees (about 1 km)
SURFACE_MINI = 0.003       # small islands of metropolitan France below this area are dropped
COS = math.cos(math.radians(46))

# Boxes (lon min, lat min, width, height) where each overseas region is drawn.
ENCARTS = {"01": (-9.6, 45.0, 2.4, 1.5), "02": (-9.6, 43.3, 2.4, 1.5), "03": (-9.6, 41.0, 2.4, 2.0),
           "04": (-6.6, 41.0, 2.4, 1.5), "06": (-6.6, 42.8, 2.4, 1.5)}


def surface(anneau):
    return abs(sum(x1 * y2 - x2 * y1 for (x1, y1), (x2, y2) in zip(anneau, anneau[1:]))) / 2


def deplacer(polygones, boite):
    """Scales an overseas region into its box, keeping its shape (longitudes corrected by the latitude)."""
    pts = [p for poly in polygones for anneau in poly for p in anneau]
    lat0 = sum(p[1] for p in pts) / len(pts)
    c = math.cos(math.radians(lat0))
    xs, ys = [p[0] * c for p in pts], [p[1] for p in pts]
    x0, y0, bw, bh = boite
    k = min(bw * COS / (max(xs) - min(xs)), bh / (max(ys) - min(ys)))
    ox = x0 + (bw - (max(xs) - min(xs)) * k / COS) / 2
    oy = y0 + (bh - (max(ys) - min(ys)) * k) / 2
    return [[[(ox + (p[0] * c - min(xs)) * k / COS, oy + (p[1] - min(ys)) * k) for p in anneau] for anneau in poly]
            for poly in polygones]


def douglas_peucker(points, tol):
    if len(points) < 3:
        return points
    (x1, y1), (x2, y2) = points[0], points[-1]
    dx, dy = x2 - x1, y2 - y1
    n = math.hypot(dx, dy)
    dist = [abs(dy * (x - x1) - dx * (y - y1)) / n if n else math.hypot(x - x1, y - y1) for x, y in points[1:-1]]
    i = max(range(len(dist)), key=dist.__getitem__) + 1
    if dist[i - 1] <= tol:
        return [points[0], points[-1]]
    return douglas_peucker(points[:i + 1], tol)[:-1] + douglas_peucker(points[i:], tol)


# 1. Read the regions, round the coordinates, move the overseas regions, drop the tiny islands.
regions = []
for f in json.load(open(SOURCE, encoding="utf-8"))["features"]:
    g = f["geometry"]
    polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
    polys = [[[(round(x, 5), round(y, 5)) for x, y in anneau] for anneau in poly] for poly in polys]
    code = f["properties"]["code"]
    if code in ENCARTS:
        polys = deplacer(polys, ENCARTS[code])
    else:
        polys = [poly for poly in polys if surface(poly[0]) >= SURFACE_MINI]
    regions.append((f["properties"], polys))

# 2. Cut each ring where the set of regions sharing the edge changes, so that a common border becomes one arc.
cote = {}
for r, (_, polys) in enumerate(regions):
    for poly in polys:
        for anneau in poly:
            for a, b in zip(anneau, anneau[1:]):
                cote.setdefault(frozenset((a, b)), set()).add(r)

arcs, index = [], {}


def arc_id(points):
    cle, inverse = tuple(points), tuple(reversed(points))
    if cle in index:
        return index[cle]
    if inverse in index:
        return ~index[inverse]
    index[cle] = len(arcs)
    arcs.append(douglas_peucker(points, TOLERANCE))
    return index[cle]


geometries = []
for props, polys in regions:
    forme = []
    for poly in polys:
        anneaux = []
        for anneau in poly:
            pts = anneau[:-1]
            qui = [frozenset(cote[frozenset((pts[i], pts[(i + 1) % len(pts)]))]) for i in range(len(pts))]
            coupes = [i for i in range(len(pts)) if qui[i] != qui[i - 1]]
            if not coupes:
                morceaux = [pts + [pts[0]]]
            else:
                pts, qui = pts[coupes[0]:] + pts[:coupes[0]], qui[coupes[0]:] + qui[:coupes[0]]
                bornes = [i for i in range(len(pts)) if qui[i] != qui[i - 1]] + [len(pts)]
                morceaux = [(pts + [pts[0]])[d:f + 1] for d, f in zip(bornes, bornes[1:])]
            anneaux.append([arc_id(m) for m in morceaux])
        forme.append(anneaux)
    geometries.append({"type": "MultiPolygon", "properties": {"nom": props["nom"], "code": props["code"]},
                       "arcs": forme})

# 3. Quantize the coordinates (integers relative to the bounding box) and write the TopoJSON.
xs = [p[0] for a in arcs for p in a]
ys = [p[1] for a in arcs for p in a]
Q = 20000
sx, sy = (max(xs) - min(xs)) / (Q - 1), (max(ys) - min(ys)) / (Q - 1)
arcs_q = []
for a in arcs:
    prec, sortie = (0, 0), []
    for x, y in a:
        q = (round((x - min(xs)) / sx), round((y - min(ys)) / sy))
        sortie.append([q[0] - prec[0], q[1] - prec[1]])
        prec = q
    arcs_q.append(sortie)
topo = {"type": "Topology", "transform": {"scale": [sx, sy], "translate": [min(xs), min(ys)]},
        "objects": {"regions": {"type": "GeometryCollection", "geometries": geometries}}, "arcs": arcs_q}
json.dump(topo, open(SORTIE, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
print("régions :", len(geometries), "arcs :", len(arcs), "points :", sum(len(a) for a in arcs))
