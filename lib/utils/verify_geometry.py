"""
Independent Python re-implementation of tenun_3d's riskiest geometry math,
used purely to stress-test the Dart source with hundreds of randomized
cases instead of the 1-2 examples that were checked by hand. This file is
NOT part of the shipped package -- it's a verification harness only.

Mirrors, line-for-line where practical:
  - MeshBuilder._perpendicularBasis  (mesh_builder.dart)
  - MeshBuilder.quaternionFromUp     (mesh_builder.dart)
  - MeshBuilder.cuboid faces         (mesh_builder.dart)
  - MeshBuilder.pieSlice winding     (mesh_builder.dart)
  - MeshBuilder.sphere winding       (mesh_builder.dart)
  - GlbWriter header/chunk layout    (glb_writer.dart)
"""
import math
import random
import struct

random.seed(20260804)

# ---------- Vec3 ----------
def add(a, b): return (a[0]+b[0], a[1]+b[1], a[2]+b[2])
def sub(a, b): return (a[0]-b[0], a[1]-b[1], a[2]-b[2])
def scale(a, s): return (a[0]*s, a[1]*s, a[2]*s)
def dot(a, b): return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]
def cross(a, b):
    return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def length(a): return math.sqrt(dot(a, a))
def normalize(a):
    l = length(a)
    return (0.0, 0.0, 0.0) if l < 1e-12 else (a[0]/l, a[1]/l, a[2]/l)

def random_unit_vector():
    while True:
        v = (random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(-1, 1))
        l = length(v)
        if l > 1e-6:
            return (v[0]/l, v[1]/l, v[2]/l)

# ---------- _perpendicularBasis (mesh_builder.dart) ----------
def perpendicular_basis(up):
    reference = (1.0, 0.0, 0.0) if abs(up[1]) > 0.99 else (0.0, 1.0, 0.0)
    right = normalize(cross(reference, up))
    forward = normalize(cross(right, up))
    return right, forward

# ---------- quaternionFromUp (mesh_builder.dart) ----------
def quaternion_from_up(up):
    right, forward = perpendicular_basis(up)
    m00, m01, m02 = right[0], up[0], forward[0]
    m10, m11, m12 = right[1], up[1], forward[1]
    m20, m21, m22 = right[2], up[2], forward[2]
    trace = m00 + m11 + m22

    if trace > 0:
        s = math.sqrt(trace + 1.0) * 2
        qw = 0.25 * s
        qx = (m21 - m12) / s
        qy = (m02 - m20) / s
        qz = (m10 - m01) / s
    elif m00 > m11 and m00 > m22:
        s = math.sqrt(1.0 + m00 - m11 - m22) * 2
        qw = (m21 - m12) / s
        qx = 0.25 * s
        qy = (m01 + m10) / s
        qz = (m02 + m20) / s
    elif m11 > m22:
        s = math.sqrt(1.0 + m11 - m00 - m22) * 2
        qw = (m02 - m20) / s
        qx = (m01 + m10) / s
        qy = 0.25 * s
        qz = (m12 + m21) / s
    else:
        s = math.sqrt(1.0 + m22 - m00 - m11) * 2
        qw = (m10 - m01) / s
        qx = (m02 + m20) / s
        qy = (m12 + m21) / s
        qz = 0.25 * s
    return (qx, qy, qz, qw), (right, up, forward)

def quat_to_matrix(q):
    x, y, z, w = q
    return (
        (1-2*(y*y+z*z), 2*(x*y-z*w),   2*(x*z+y*w)),
        (2*(x*y+z*w),   1-2*(x*x+z*z), 2*(y*z-x*w)),
        (2*(x*z-y*w),   2*(y*z+x*w),   1-2*(x*x+y*y)),
    )

def mat_vec(m, v):
    return (
        m[0][0]*v[0]+m[0][1]*v[1]+m[0][2]*v[2],
        m[1][0]*v[0]+m[1][1]*v[1]+m[1][2]*v[2],
        m[2][0]*v[0]+m[2][1]*v[1]+m[2][2]*v[2],
    )

def close(a, b, eps=1e-6):
    return abs(a-b) < eps

def vec_close(a, b, eps=1e-6):
    return all(close(a[i], b[i], eps) for i in range(3))


# =====================================================================
# TEST 1: quaternionFromUp across hundreds of random + edge-case dirs
# =====================================================================
def test_quaternion_from_up(n=500):
    failures = []
    dirs = [random_unit_vector() for _ in range(n)]
    # Edge cases: exact poles of the reference-switch logic, and axes.
    dirs += [(0,1,0), (0,-1,0), (1,0,0), (-1,0,0), (0,0,1), (0,0,-1),
             (0, 0.995, math.sqrt(1-0.995**2)), (0, -0.995, math.sqrt(1-0.995**2))]

    for up in dirs:
        up = normalize(up)
        q, (right, up2, forward) = quaternion_from_up(up)
        # quaternion must be unit length
        qlen = math.sqrt(sum(c*c for c in q))
        if not close(qlen, 1.0, 1e-5):
            failures.append(("unit-length", up, qlen))
            continue
        m = quat_to_matrix(q)
        # local +Y must map to `up`
        mapped_up = mat_vec(m, (0, 1, 0))
        if not vec_close(mapped_up, up, 1e-5):
            failures.append(("Y->up", up, mapped_up))
        # local +X must map to `right`, local +Z to `forward`
        mapped_right = mat_vec(m, (1, 0, 0))
        mapped_forward = mat_vec(m, (0, 0, 1))
        if not vec_close(mapped_right, right, 1e-5):
            failures.append(("X->right", up, mapped_right, right))
        if not vec_close(mapped_forward, forward, 1e-5):
            failures.append(("Z->forward", up, mapped_forward, forward))
        # matrix must be a proper rotation: det = +1 (not a reflection)
        det = (m[0][0]*(m[1][1]*m[2][2]-m[1][2]*m[2][1])
               - m[0][1]*(m[1][0]*m[2][2]-m[1][2]*m[2][0])
               + m[0][2]*(m[1][0]*m[2][1]-m[1][1]*m[2][0]))
        if not close(det, 1.0, 1e-4):
            failures.append(("det+1", up, det))
    return len(dirs), failures


# =====================================================================
# TEST 2: cuboid() face winding (mirrors the 6-face table in mesh_builder.dart)
# =====================================================================
def cuboid_faces(w, h, d):
    return [
        ([(w,0,-d),(w,h,-d),(w,h,d),(w,0,d)], (1,0,0)),
        ([(-w,0,-d),(-w,0,d),(-w,h,d),(-w,h,-d)], (-1,0,0)),
        ([(-w,h,-d),(-w,h,d),(w,h,d),(w,h,-d)], (0,1,0)),
        ([(-w,0,-d),(w,0,-d),(w,0,d),(-w,0,d)], (0,-1,0)),
        ([(-w,0,d),(w,0,d),(w,h,d),(-w,h,d)], (0,0,1)),
        ([(-w,0,-d),(-w,h,-d),(w,h,-d),(w,0,-d)], (0,0,-1)),
    ]

def test_cuboid_winding(n=50):
    failures = []
    for _ in range(n):
        w = random.uniform(0.1, 3)
        h = random.uniform(0.1, 3)
        d = random.uniform(0.1, 3)
        for corners, normal in cuboid_faces(w, h, d):
            # triangulation (0,1,2) and (0,2,3), same as the Dart code
            for tri in [(0,1,2), (0,2,3)]:
                a, b, c = (corners[tri[0]], corners[tri[1]], corners[tri[2]])
                n_computed = normalize(cross(sub(b, a), sub(c, a)))
                if dot(n_computed, normal) < 0.99:
                    failures.append((w, h, d, normal, tri, n_computed))
    return n * 6 * 2, failures


# =====================================================================
# TEST 3: pieSlice() outer/inner wall + end-cap winding, many angle ranges
# =====================================================================
def test_pieslice_winding(trials=60):
    failures = []
    checked = 0
    for _ in range(trials):
        start = random.uniform(-350, 350)
        sweep = random.uniform(5, 359)
        end = start + sweep
        outer_r = random.uniform(0.3, 2.0)
        inner_r = random.uniform(0.0, outer_r * 0.8) if random.random() < 0.5 else 0.0
        height = random.uniform(0.1, 2.0)
        segs = max(1, round(sweep / 360 * 48))
        angles = [math.radians(start + sweep * i / segs) for i in range(segs + 1)]

        def ring(r, y):
            return [(math.cos(a) * r, y, math.sin(a) * r) for a in angles]

        outer_top, outer_bot = ring(outer_r, height), ring(outer_r, 0)
        inner_top, inner_bot = ring(inner_r, height), ring(inner_r, 0)

        # Outer wall: quad(bottom[i], top[i], top[i+1], bottom[i+1]) -> tris (0,1,2),(0,2,3)
        for i in range(segs):
            mid_angle = (angles[i] + angles[i+1]) / 2
            expected_n = (math.cos(mid_angle), 0, math.sin(mid_angle))
            quad = [outer_bot[i], outer_top[i], outer_top[i+1], outer_bot[i+1]]
            for tri in [(0,1,2),(0,2,3)]:
                a, b, c = quad[tri[0]], quad[tri[1]], quad[tri[2]]
                n_computed = normalize(cross(sub(b,a), sub(c,a)))
                checked += 1
                if dot(n_computed, expected_n) < 0.9:
                    failures.append(("outer_wall", start, sweep, i, n_computed, expected_n))

        # Inner wall (only if donut): quad(bottom[i+1], top[i+1], top[i], bottom[i])
        if inner_r > 0:
            for i in range(segs):
                mid_angle = (angles[i] + angles[i+1]) / 2
                expected_n = (-math.cos(mid_angle), 0, -math.sin(mid_angle))
                quad = [inner_bot[i+1], inner_top[i+1], inner_top[i], inner_bot[i]]
                for tri in [(0,1,2),(0,2,3)]:
                    a, b, c = quad[tri[0]], quad[tri[1]], quad[tri[2]]
                    n_computed = normalize(cross(sub(b,a), sub(c,a)))
                    checked += 1
                    if dot(n_computed, expected_n) < 0.9:
                        failures.append(("inner_wall", start, sweep, i, n_computed, expected_n))

        # End caps (only if not a full ring)
        if sweep < 359.99:
            start_normal = (math.sin(angles[0]), 0, -math.cos(angles[0]))
            quad = [inner_bot[0], inner_top[0], outer_top[0], outer_bot[0]]
            for tri in [(0,1,2),(0,2,3)]:
                a, b, c = quad[tri[0]], quad[tri[1]], quad[tri[2]]
                n_computed = normalize(cross(sub(b,a), sub(c,a)))
                checked += 1
                if dot(n_computed, start_normal) < 0.9:
                    failures.append(("start_cap", start, sweep, n_computed, start_normal))

            end_normal = (-math.sin(angles[-1]), 0, math.cos(angles[-1]))
            quad = [inner_bot[-1], outer_bot[-1], outer_top[-1], inner_top[-1]]
            for tri in [(0,1,2),(0,2,3)]:
                a, b, c = quad[tri[0]], quad[tri[1]], quad[tri[2]]
                n_computed = normalize(cross(sub(b,a), sub(c,a)))
                checked += 1
                if dot(n_computed, end_normal) < 0.9:
                    failures.append(("end_cap", start, sweep, n_computed, end_normal))
    return checked, failures


# =====================================================================
# TEST 4: sphere() winding, full grid, multiple stack/slice combos
# =====================================================================
def test_sphere_winding():
    failures = []
    checked = 0
    for stacks, slices in [(4, 6), (8, 12), (24, 48), (2, 3)]:
        radius = 1.7
        grid = {}
        for i in range(stacks + 1):
            phi = math.pi * i / stacks
            y = math.cos(phi) * radius
            ring_r = math.sin(phi) * radius
            for j in range(slices):
                theta = 2 * math.pi * j / slices
                x = math.cos(theta) * ring_r
                z = math.sin(theta) * ring_r
                grid[(i, j)] = (x, y, z)

        for i in range(stacks):
            for j in range(slices):
                jn = (j + 1) % slices
                top, top_n = grid[(i, j)], grid[(i, jn)]
                bot, bot_n = grid[(i+1, j)], grid[(i+1, jn)]
                for tri in [(top, bot_n, bot), (top, top_n, bot_n)]:
                    a, b, c = tri
                    if vec_close(a, b) or vec_close(b, c) or vec_close(a, c):
                        continue  # degenerate pole triangle, skip
                    n_computed = normalize(cross(sub(b, a), sub(c, a)))
                    centroid = scale(add(add(a, b), c), 1/3)
                    outward = normalize(centroid)
                    checked += 1
                    if dot(n_computed, outward) < 0.5:
                        failures.append((stacks, slices, i, j, n_computed, outward))
    return checked, failures


# =====================================================================
# TEST 5: GLB container header/chunk byte layout (glb_writer.dart)
# =====================================================================
def test_glb_header():
    failures = []
    json_bytes = b'{"asset":{"version":"2.0"}}'
    json_pad = (4 - (len(json_bytes) % 4)) % 4
    padded_json = json_bytes + b' ' * json_pad
    bin_bytes = bytes(range(37))  # arbitrary non-4-aligned length, like real vertex data
    bin_pad = (4 - (len(bin_bytes) % 4)) % 4
    padded_bin = bin_bytes + b'\x00' * bin_pad

    total_len = 12 + 8 + len(padded_json) + 8 + len(padded_bin)
    header = struct.pack('<III', 0x46546C67, 2, total_len)
    json_chunk_header = struct.pack('<II', len(padded_json), 0x4E4F534A)
    bin_chunk_header = struct.pack('<II', len(padded_bin), 0x004E4942)
    glb = header + json_chunk_header + padded_json + bin_chunk_header + padded_bin

    if len(padded_json) % 4 != 0:
        failures.append("json chunk not 4-byte aligned")
    if len(padded_bin) % 4 != 0:
        failures.append("bin chunk not 4-byte aligned")
    if glb[0:4] != b'glTF':
        failures.append(f"magic bytes wrong: {glb[0:4]!r}")
    if len(glb) != total_len:
        failures.append(f"total length mismatch: header says {total_len}, actual {len(glb)}")
    # chunk type bytes should literally spell 'JSON' and 'BIN\0'
    if glb[16:20] != b'JSON':
        failures.append(f"JSON chunk type bytes wrong: {glb[16:20]!r}")
    bin_chunk_type_offset = 12 + 8 + len(padded_json)
    if glb[bin_chunk_type_offset+4:bin_chunk_type_offset+8] != b'BIN\x00':
        failures.append(f"BIN chunk type bytes wrong: {glb[bin_chunk_type_offset+4:bin_chunk_type_offset+8]!r}")
    return 5, failures


if __name__ == '__main__':
    results = []
    n, f = test_quaternion_from_up(500)
    results.append(("quaternionFromUp (incl. Y->up, X->right, Z->forward, det=+1, unit-length)", n, f))
    n, f = test_cuboid_winding(50)
    results.append(("cuboid() face winding", n, f))
    n, f = test_pieslice_winding(60)
    results.append(("pieSlice() outer/inner wall + end-cap winding", n, f))
    n, f = test_sphere_winding()
    results.append(("sphere() triangle winding", n, f))
    n, f = test_glb_header()
    results.append(("GLB container header/chunk byte layout", n, f))

    print("=" * 70)
    total_checks = 0
    total_failures = 0
    for name, n, f in results:
        total_checks += n
        total_failures += len(f)
        status = "PASS" if not f else f"FAIL ({len(f)})"
        print(f"[{status:10}] {name}  ({n} checks)")
        for item in f[:5]:
            print(f"    -> {item}")
        if len(f) > 5:
            print(f"    ... and {len(f)-5} more")
    print("=" * 70)
    print(f"TOTAL: {total_checks} checks, {total_failures} failures")
