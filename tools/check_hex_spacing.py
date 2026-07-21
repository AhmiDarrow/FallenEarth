#!/usr/bin/env python3
"""Match WorldGenerator hexasphere packing (10*F^2+2 tiles, geodesic icosahedron)."""
import math

PHI = (1.0 + math.sqrt(5.0)) / 2.0
HEX_PACK_RATIO = 0.97


def icosa_vertices():
    raw = [
        (-1, PHI, 0), (1, PHI, 0), (-1, -PHI, 0), (1, -PHI, 0),
        (0, -1, PHI), (0, 1, PHI), (0, -1, -PHI), (0, 1, -PHI),
        (PHI, 0, -1), (PHI, 0, 1), (-PHI, 0, -1), (-PHI, 0, 1),
    ]
    out = []
    for x, y, z in raw:
        L = math.sqrt(x * x + y * y + z * z)
        out.append((x / L, y / L, z / L))
    return out


FACES = [
    (0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11),
    (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
    (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9),
    (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1),
]


def build_hexasphere(F, radius=4.0):
    base = icosa_vertices()
    verts = []
    lookup = {}
    edges = set()

    def add_vert(p):
        L = math.sqrt(p[0] ** 2 + p[1] ** 2 + p[2] ** 2)
        n = (p[0] / L, p[1] / L, p[2] / L)
        qk = (round(n[0] * 1e5), round(n[1] * 1e5), round(n[2] * 1e5))
        if qk in lookup:
            return lookup[qk]
        idx = len(verts)
        verts.append(n)
        lookup[qk] = idx
        return idx

    def add_edge(a, b):
        if a != b:
            edges.add((min(a, b), max(a, b)))

    for fa, fb, fc in FACES:
        v0, v1, v2 = base[fa], base[fb], base[fc]
        grid = []
        for i in range(F + 1):
            row = []
            for j in range(F - i + 1):
                k = F - i - j
                p = (
                    (v0[0] * k + v1[0] * i + v2[0] * j) / F,
                    (v0[1] * k + v1[1] * i + v2[1] * j) / F,
                    (v0[2] * k + v1[2] * i + v2[2] * j) / F,
                )
                row.append(add_vert(p))
            grid.append(row)
        for i in range(F + 1):
            for j in range(F - i + 1):
                a = grid[i][j]
                if j < F - i:
                    add_edge(a, grid[i][j + 1])
                if i < F and j <= F - i - 1:
                    add_edge(a, grid[i + 1][j])
                if i < F and j > 0:
                    add_edge(a, grid[i + 1][j - 1])

    adj = [[] for _ in verts]
    for a, b in edges:
        adj[a].append(b)
        adj[b].append(a)

    positions = [(v[0] * radius, v[1] * radius, v[2] * radius) for v in verts]
    local_mins = []
    for i, p in enumerate(positions):
        best = 1e9
        for j in adj[i]:
            q = positions[j]
            d = math.dist(p, q)
            if 1e-6 < d < best:
                best = d
        if best < 1e8:
            local_mins.append(best)
    return len(verts), local_mins


def analyze(F=7, S=4.0):
    n, local_mins = build_hexasphere(F, S)
    min_nn = min(local_mins)
    max_nn = max(local_mins)
    avg_nn = sum(local_mins) / len(local_mins)
    pack_width = min_nn * HEX_PACK_RATIO
    hex_size = pack_width / math.sqrt(3.0)
    nn_ratio = max_nn / min_nn
    pack_ratio = pack_width / min_nn
    expected = 10 * F * F + 2
    print(f"F={F} tiles={n} (expect {expected})")
    print(f"min_nn={min_nn:.4f} avg_nn={avg_nn:.4f} max_nn={max_nn:.4f} nn_ratio={nn_ratio:.3f}")
    print(f"hex_size={hex_size:.4f} pack_ratio={pack_ratio:.3f}")
    ok = n == expected and nn_ratio <= 1.40 and 0.90 <= pack_ratio <= 0.99
    print("RESULT:", "OK" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(analyze())
