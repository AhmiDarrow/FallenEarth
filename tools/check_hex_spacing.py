#!/usr/bin/env python3
import math

def get_hex_spherical_pos(q, r, hex_radius, sphere_radius=4.0):
    px = math.sqrt(3.0) * q + math.sqrt(3.0) / 2.0 * r
    py = 1.5 * r
    plane_dist = math.sqrt(px*px + py*py)

    ring_dist = plane_dist / math.sqrt(3.0)
    angular_step = math.radians(9.0)
    polar = ring_dist * angular_step

    polar_shift = math.radians(58.0)
    polar = polar + polar_shift
    polar = min(polar, math.radians(175.0))

    azimuth = math.atan2(px, py)

    sp = math.sin(polar)
    cp = math.cos(polar)

    x = sp * math.cos(azimuth) * sphere_radius
    y = cp * sphere_radius
    z = sp * math.sin(azimuth) * sphere_radius
    return (x, y, z)

def axial_neighbors(q, r):
    dirs = [(1,0), (0,1), (-1,1), (-1,0), (0,-1), (1,-1)]
    return [(q+dq, r+dr) for dq,dr in dirs]

def hex_distance(q1, r1, q2, r2):
    s1 = -q1 - r1
    s2 = -q2 - r2
    return int((abs(q1 - q2) + abs(r1 - r2) + abs(s1 - s2)) / 2)

R = 12
S = 4.0
sample_dists = []
for q in range(-R-1, R+2):
    for r in range(-R-1, R+2):
        if hex_distance(q, r, 0, 0) > R:
            continue
        tpos = get_hex_spherical_pos(q, r, R, S)
        for nq, nr in axial_neighbors(q, r):
            if hex_distance(nq, nr, 0, 0) <= R:
                npos = get_hex_spherical_pos(nq, nr, R, S)
                d = math.sqrt( (tpos[0]-npos[0])**2 + (tpos[1]-npos[1])**2 + (tpos[2]-npos[2])**2 )
                if d > 0.001:
                    sample_dists.append(d)
                break

if sample_dists:
    avg = sum(sample_dists) / len(sample_dists)
    hex_size = avg / math.sqrt(3.0) * 1.03
    print(f"Sampled {len(sample_dists)} neighbor distances")
    print(f"Avg center-to-center: {avg:.4f}")
    print(f"Computed hex_3d_size (with 1.03): {hex_size:.4f}")
    print("Radial + 58° shift + 9° step: great local hex look + patch reaches far across the sphere.")
else:
    print("No samples")
