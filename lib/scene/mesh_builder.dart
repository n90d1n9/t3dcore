import 'dart:math' as math;

import 'scene_graph.dart';

/// Procedural mesh generators. Each chart primitive maps to one of these,
/// matching the "Bar -> Cube Mesh" style pipeline from the architecture
/// note. Only the box (bar) and a flat ground plane are implemented here;
/// pie/line/scatter meshes (cylinder segment / tube / sphere) are natural
/// follow-ups using the same pattern — see the README.
///
/// The box uses 24 vertices (4 per face) rather than 8, so every face gets
/// its own flat normal instead of averaged vertex normals — this is what
/// makes a bar look like a crisp cube instead of a rounded blob once lit.
class MeshBuilder {
  /// A box sitting on the ground plane: spans x in [-sizeX/2, sizeX/2],
  /// y in [0, sizeY] (height), z in [-sizeZ/2, sizeZ/2].
  static MeshData cuboid({
    required double sizeX,
    required double sizeY,
    required double sizeZ,
  }) {
    final w = sizeX / 2;
    final h = sizeY;
    final d = sizeZ / 2;

    // Each face listed as 4 CCW-from-outside corners + its flat normal.
    final faces = <(List<List<double>>, List<double>)>[
      // +X
      (
        [
          [w, 0, -d],
          [w, h, -d],
          [w, h, d],
          [w, 0, d],
        ],
        [1, 0, 0],
      ),
      // -X
      (
        [
          [-w, 0, -d],
          [-w, 0, d],
          [-w, h, d],
          [-w, h, -d],
        ],
        [-1, 0, 0],
      ),
      // +Y (top)
      (
        [
          [-w, h, -d],
          [-w, h, d],
          [w, h, d],
          [w, h, -d],
        ],
        [0, 1, 0],
      ),
      // -Y (bottom)
      (
        [
          [-w, 0, -d],
          [w, 0, -d],
          [w, 0, d],
          [-w, 0, d],
        ],
        [0, -1, 0],
      ),
      // +Z (front)
      (
        [
          [-w, 0, d],
          [w, 0, d],
          [w, h, d],
          [-w, h, d],
        ],
        [0, 0, 1],
      ),
      // -Z (back)
      (
        [
          [-w, 0, -d],
          [-w, h, -d],
          [w, h, -d],
          [w, 0, -d],
        ],
        [0, 0, -1],
      ),
    ];

    final positions = <double>[];
    final normals = <double>[];
    final indices = <int>[];

    for (final (corners, normal) in faces) {
      final base = positions.length ~/ 3;
      for (final c in corners) {
        positions.addAll(c);
        normals.addAll(normal);
      }
      indices.addAll([base, base + 1, base + 2, base, base + 2, base + 3]);
    }

    return MeshData(positions: positions, normals: normals, indices: indices);
  }

  /// A thin flat slab used as the chart's ground/base plate.
  static MeshData groundPlane({
    required double width,
    required double depth,
    double thickness = 0.02,
  }) {
    return cuboid(sizeX: width, sizeY: thickness, sizeZ: depth);
  }

  /// An extruded circular sector — a pie slice (`innerRadius: 0`) or a
  /// donut/ring segment (`innerRadius > 0`), matching the "Slice ->
  /// Cylinder Segment -> Material" step from the architecture note.
  ///
  /// Angles are in degrees, measured the same way `dart:math`'s
  /// `cos`/`sin` measure them (0° along +X, sweeping toward +Z).
  /// The arc is subdivided into straight segments — [segmentsPerFullCircle]
  /// controls how many segments a *full* 360° circle would use; a slice's
  /// segment count is scaled down proportionally to its sweep so a 10°
  /// sliver isn't wastefully over-tessellated.
  ///
  /// Face structure: flat top/bottom (uniform normal), a smooth-shaded
  /// curved outer wall (and inner wall, for donuts), and — unless the
  /// slice is a full 360° ring — two flat end caps closing the wedge.
  /// Every winding direction below was derived and numerically verified
  /// by hand (see the package's git history / PR description) rather
  /// than assumed, since a flipped triangle here is invisible until you
  /// orbit the camera to the wrong side.
  static MeshData pieSlice({
    required double startAngleDeg,
    required double endAngleDeg,
    required double outerRadius,
    double innerRadius = 0,
    required double height,
    int segmentsPerFullCircle = 48,
  }) {
    final sweep = (endAngleDeg - startAngleDeg).clamp(0.0001, 360.0).toDouble();
    final isFullRing = sweep >= 359.99;
    final segments = math.max(
      1,
      (sweep / 360.0 * segmentsPerFullCircle).round(),
    );

    final angles = List<double>.generate(
      segments + 1,
      (i) => (startAngleDeg + sweep * i / segments) * math.pi / 180.0,
    );

    List<double> ring(double radius, double y) {
      final pts = <double>[];
      for (final a in angles) {
        pts.addAll([math.cos(a) * radius, y, math.sin(a) * radius]);
      }
      return pts;
    }

    // Flat vertex sets (top/bottom faces + end caps need a uniform
    // per-face normal, so they get their own duplicated vertices).
    final outerTop = ring(outerRadius, height);
    final outerBottom = ring(outerRadius, 0);
    final innerTop = ring(innerRadius, height);
    final innerBottom = ring(innerRadius, 0);

    final positions = <double>[];
    final normals = <double>[];
    final indices = <int>[];

    int addVertex(List<double> ringData, int i, List<double> normal) {
      final idx = positions.length ~/ 3;
      positions.addAll([
        ringData[i * 3],
        ringData[i * 3 + 1],
        ringData[i * 3 + 2],
      ]);
      normals.addAll(normal);
      return idx;
    }

    void quad(int a, int b, int c, int d) {
      indices.addAll([a, b, c, a, c, d]);
    }

    // --- Top face (normal straight up) ---
    for (var i = 0; i < segments; i++) {
      final a = addVertex(outerTop, i, const [0, 1, 0]);
      final b = addVertex(innerTop, i, const [0, 1, 0]);
      final c = addVertex(innerTop, i + 1, const [0, 1, 0]);
      final d = addVertex(outerTop, i + 1, const [0, 1, 0]);
      quad(a, b, c, d); // (outer[i], inner[i], inner[i+1], outer[i+1])
    }

    // --- Bottom face (normal straight down; reversed winding) ---
    for (var i = 0; i < segments; i++) {
      final a = addVertex(outerBottom, i + 1, const [0, -1, 0]);
      final b = addVertex(innerBottom, i + 1, const [0, -1, 0]);
      final c = addVertex(innerBottom, i, const [0, -1, 0]);
      final d = addVertex(outerBottom, i, const [0, -1, 0]);
      quad(a, b, c, d); // (outer[i+1], inner[i+1], inner[i], outer[i])
    }

    // --- Outer wall (smooth-shaded: normal = radial outward at each ring point) ---
    for (var i = 0; i < segments; i++) {
      final nA = [math.cos(angles[i]), 0.0, math.sin(angles[i])];
      final nB = [math.cos(angles[i + 1]), 0.0, math.sin(angles[i + 1])];
      final a = addVertex(outerBottom, i, nA);
      final b = addVertex(outerTop, i, nA);
      final c = addVertex(outerTop, i + 1, nB);
      final d = addVertex(outerBottom, i + 1, nB);
      quad(a, b, c, d); // (bottom[i], top[i], top[i+1], bottom[i+1])
    }

    // --- Inner wall, only if this is a donut/ring segment ---
    if (innerRadius > 0) {
      for (var i = 0; i < segments; i++) {
        final nA = [-math.cos(angles[i]), 0.0, -math.sin(angles[i])];
        final nB = [-math.cos(angles[i + 1]), 0.0, -math.sin(angles[i + 1])];
        final a = addVertex(innerBottom, i + 1, nB);
        final b = addVertex(innerTop, i + 1, nB);
        final c = addVertex(innerTop, i, nA);
        final d = addVertex(innerBottom, i, nA);
        quad(a, b, c, d); // (bottom[i+1], top[i+1], top[i], bottom[i])
      }
    }

    // --- End caps, unless this slice is a closed 360° ring ---
    if (!isFullRing) {
      final startNormal = [
        math.sin(angles.first),
        0.0,
        -math.cos(angles.first),
      ];
      final a = addVertex(innerBottom, 0, startNormal);
      final b = addVertex(innerTop, 0, startNormal);
      final c = addVertex(outerTop, 0, startNormal);
      final d = addVertex(outerBottom, 0, startNormal);
      quad(
        a,
        b,
        c,
        d,
      ); // (innerBottom[0], innerTop[0], outerTop[0], outerBottom[0])

      final lastIdx = segments;
      final endNormal = [-math.sin(angles.last), 0.0, math.cos(angles.last)];
      final e = addVertex(innerBottom, lastIdx, endNormal);
      final f = addVertex(outerBottom, lastIdx, endNormal);
      final g = addVertex(outerTop, lastIdx, endNormal);
      final h = addVertex(innerTop, lastIdx, endNormal);
      quad(
        e,
        f,
        g,
        h,
      ); // (innerBottom[N], outerBottom[N], outerTop[N], innerTop[N])
    }

    return MeshData(positions: positions, normals: normals, indices: indices);
  }

  /// A UV sphere (latitude/longitude tessellation) — the globe for the
  /// geo chart, matching the "Point -> Sphere" step from the architecture
  /// note, just used for a planet instead of a scatter dot.
  ///
  /// Unlike [cuboid]/[pieSlice], this shares one vertex per (stack, slice)
  /// grid cell rather than duplicating per face — a sphere's true surface
  /// normal *is* just the normalized position (it's centered at the
  /// origin), so sharing costs nothing visually and roughly quarters the
  /// vertex count. [stacks] is latitude bands pole-to-pole, [slices] is
  /// longitude segments around the equator.
  static MeshData sphere({
    required double radius,
    int stacks = 24,
    int slices = 48,
  }) {
    final positions = <double>[];
    final normals = <double>[];
    final indices = <int>[];

    // grid[i][j] = vertex index at latitude band i, longitude slice j.
    final grid = List.generate(stacks + 1, (_) => List<int>.filled(slices, 0));

    for (var i = 0; i <= stacks; i++) {
      final phi = math.pi * i / stacks; // 0 at north pole, pi at south pole
      final y = math.cos(phi) * radius;
      final ringRadius = math.sin(phi) * radius;
      for (var j = 0; j < slices; j++) {
        final theta = 2 * math.pi * j / slices;
        final x = math.cos(theta) * ringRadius;
        final z = math.sin(theta) * ringRadius;
        final idx = positions.length ~/ 3;
        positions.addAll([x, y, z]);
        final n = Vec3(x, y, z).normalized();
        normals.addAll([n.x, n.y, n.z]);
        grid[i][j] = idx;
      }
    }

    for (var i = 0; i < stacks; i++) {
      for (var j = 0; j < slices; j++) {
        final jNext = (j + 1) % slices;
        final top = grid[i][j];
        final topNext = grid[i][jNext];
        final bottom = grid[i + 1][j];
        final bottomNext = grid[i + 1][jNext];
        // Verified winding (see pieSlice's doc comment on method): for a
        // band running from the north-pole side ("top", smaller i) to the
        // south-pole side ("bottom", larger i), outward-facing triangles
        // are (top, bottomNext, bottom) and (top, topNext, bottomNext).
        // Degenerate at the poles (top==topNext or bottom==bottomNext) —
        // harmless zero-area triangles, the standard way to close a pole.
        indices.addAll([top, bottomNext, bottom, top, topNext, bottomNext]);
      }
    }

    return MeshData(positions: positions, normals: normals, indices: indices);
  }

  /// Builds an orthonormal `(right, forward)` pair perpendicular to [up]
  /// (which must already be unit length) — the "pick any perpendicular
  /// axis" step shared by every mesh here that orients something along an
  /// arbitrary direction instead of the world axes ([radialPin],
  /// [tubeSegment]). Swaps its reference vector near the poles so `cross`
  /// never sees two near-parallel vectors, and is built so that
  /// `right.cross(up) == forward` — i.e. it preserves the same
  /// right-handed relationship as the local `(x, y, z)` axes that
  /// [cuboid]/[pieSlice] are generated in, which is what keeps every
  /// outward-facing triangle outward-facing once this basis is applied as
  /// a rotation instead of a reflection.
  static (Vec3, Vec3) _perpendicularBasis(Vec3 up) {
    final reference = up.y.abs() > 0.99
        ? const Vec3(1, 0, 0)
        : const Vec3(0, 1, 0);
    final right = reference.cross(up).normalized();
    final forward = right.cross(up).normalized();
    return (right, forward);
  }

  /// A glTF quaternion `[x, y, z, w]` for the rotation that takes local
  /// `+Y` to point along [up] (unit length) — everything a [Node3D] needs
  /// to stand a plain, upright mesh (a [cuboid] or a [pieSlice] full
  /// ring) on its side instead of baking the tilt into vertex data. Used
  /// by [radialPin] and [tubeSegment].
  ///
  /// Converts the `(right, up, forward)` basis from [_perpendicularBasis]
  /// to a quaternion via the standard branch-on-trace method (numerically
  /// stable across the full rotation range — the naive single-formula
  /// conversion divides by ~0 near 180°). Verified against a known case
  /// by hand (`up = (0, 0, 1)` should give a 90° rotation about world X;
  /// it does) rather than assumed correct from the general formula alone.
  static List<double> quaternionFromUp(Vec3 up) {
    final (right, forward) = _perpendicularBasis(up);
    final m00 = right.x, m01 = up.x, m02 = forward.x;
    final m10 = right.y, m11 = up.y, m12 = forward.y;
    final m20 = right.z, m21 = up.z, m22 = forward.z;
    final trace = m00 + m11 + m22;

    double qw, qx, qy, qz;
    if (trace > 0) {
      final s = math.sqrt(trace + 1.0) * 2;
      qw = 0.25 * s;
      qx = (m21 - m12) / s;
      qy = (m02 - m20) / s;
      qz = (m10 - m01) / s;
    } else if (m00 > m11 && m00 > m22) {
      final s = math.sqrt(1.0 + m00 - m11 - m22) * 2;
      qw = (m21 - m12) / s;
      qx = 0.25 * s;
      qy = (m01 + m10) / s;
      qz = (m02 + m20) / s;
    } else if (m11 > m22) {
      final s = math.sqrt(1.0 + m11 - m00 - m22) * 2;
      qw = (m02 - m20) / s;
      qx = (m01 + m10) / s;
      qy = 0.25 * s;
      qz = (m12 + m21) / s;
    } else {
      final s = math.sqrt(1.0 + m22 - m00 - m11) * 2;
      qw = (m10 - m01) / s;
      qx = (m02 + m20) / s;
      qy = (m12 + m21) / s;
      qz = 0.25 * s;
    }
    return [qx, qy, qz, qw];
  }

  /// Applies a rotation (via an orthonormal `right/up/forward` frame) and
  /// translation to every vertex of [mesh], returning a new mesh with the
  /// transform baked into its raw position/normal data — an alternative
  /// to [Node3D.rotation] for cases where minimizing node/draw-call count
  /// matters more than each piece being independently animatable (baked
  /// meshes can be merged into one node; rotated ones can't, since each
  /// needs its own transform).
  static MeshData transformed(
    MeshData mesh, {
    required Vec3 origin,
    required Vec3 right,
    required Vec3 up,
    required Vec3 forward,
  }) {
    final positions = <double>[];
    final normals = <double>[];
    for (var i = 0; i < mesh.vertexCount; i++) {
      final lx = mesh.positions[i * 3];
      final ly = mesh.positions[i * 3 + 1];
      final lz = mesh.positions[i * 3 + 2];
      final worldPos = origin + right * lx + up * ly + forward * lz;
      positions.addAll(worldPos.toList());

      final nlx = mesh.normals[i * 3];
      final nly = mesh.normals[i * 3 + 1];
      final nlz = mesh.normals[i * 3 + 2];
      // No translation for normals, and right/up/forward being orthonormal
      // means this rotation doesn't need an inverse-transpose correction.
      final worldNormal = (right * nlx + up * nly + forward * nlz).normalized();
      normals.addAll(worldNormal.toList());
    }
    return MeshData(
      positions: positions,
      normals: normals,
      indices: mesh.indices,
    );
  }

  /// A thin post standing on a sphere's surface at [surfacePoint], pointing
  /// straight outward along [outwardNormal] (must be unit length), used by
  /// the geo chart to mark a magnitude at a lat/lng location — "Point ->
  /// Sphere" in the architecture note's own mesh-per-primitive table,
  /// specialized here into "value at a location -> radial post".
  ///
  /// Returns an [OrientedMesh]: the mesh itself is a plain upright post
  /// (unrotated, as if standing at the world origin) — [outwardNormal] is
  /// carried as a [Node3D] rotation instead of being baked into vertex
  /// data, so the post can still use the shared "growIn" animation.
  static OrientedMesh radialPin({
    required Vec3 surfacePoint,
    required Vec3 outwardNormal,
    required double length,
    required double width,
  }) {
    final mesh = cuboid(sizeX: width, sizeY: length, sizeZ: width);
    return OrientedMesh(
      mesh: mesh,
      translation: surfacePoint,
      rotation: quaternionFromUp(outwardNormal),
    );
  }

  /// A round tube (solid cylinder — reuses [pieSlice]'s full-ring case
  /// rather than duplicating cylinder geometry) running from [from] to
  /// [to], used by the line chart to connect consecutive data points —
  /// the architecture note's "Line: Polyline -> Tube Mesh", one straight
  /// segment at a time. Returns an [OrientedMesh] for the same reason as
  /// [radialPin].
  static OrientedMesh tubeSegment({
    required Vec3 from,
    required Vec3 to,
    required double radius,
  }) {
    final delta = to - from;
    final length = delta.length;
    if (length < 1e-9) {
      // Degenerate (coincident points): a tiny sphere reads better than
      // a zero-length, direction-less cylinder, and needs no rotation.
      return OrientedMesh(
        mesh: sphere(radius: radius, stacks: 8, slices: 12),
        translation: from,
        rotation: null,
      );
    }
    final up = delta.normalized();
    final mesh = pieSlice(
      startAngleDeg: 0,
      endAngleDeg: 360,
      outerRadius: radius,
      height: length,
    );
    return OrientedMesh(
      mesh: mesh,
      translation: from,
      rotation: quaternionFromUp(up),
    );
  }
}

/// A mesh generated upright in its own local space, plus the translation
/// and (optional) rotation needed to place it in the scene — everything
/// [radialPin] and [tubeSegment]'s callers need to build a [Node3D]
/// directly, without baking the transform into vertex data themselves.
class OrientedMesh {
  const OrientedMesh({
    required this.mesh,
    required this.translation,
    required this.rotation,
  });

  final MeshData mesh;
  final Vec3 translation;

  /// glTF quaternion `[x, y, z, w]`, or `null` for no rotation.
  final List<double>? rotation;
}
