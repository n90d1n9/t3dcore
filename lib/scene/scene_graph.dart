/// Minimal, engine-independent scene graph.
///
/// This mirrors the "Scene / Node / Mesh / Material / Camera / Light"
/// separation described in the Tenun 3D architecture note: charts never
/// know about glTF directly, they only build a [Scene3D]. A separate
/// exporter (see `../gltf/glb_writer.dart`) turns the scene into bytes.
library scene_graph;

import 'dart:math' as math;

/// Simple 3-component vector. Kept dependency-free (no `vector_math`)
/// so this package has zero extra transitive deps beyond Flutter itself.
class Vec3 {
  const Vec3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  static const zero = Vec3(0, 0, 0);
  static const one = Vec3(1, 1, 1);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);

  double get length => math.sqrt(x * x + y * y + z * z);

  Vec3 normalized() {
    final l = length;
    if (l < 1e-12) return Vec3.zero;
    return Vec3(x / l, y / l, z / l);
  }

  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;

  Vec3 cross(Vec3 o) =>
      Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);

  List<double> toList() => [x, y, z];
}

/// A PBR-ish material. `flutter_3d_controller` renders through
/// google's `model-viewer`, which understands glTF's
/// metallic/roughness material model, so we expose exactly that
/// rather than inventing our own shading model.
class Material3D {
  const Material3D({
    required this.baseColor,
    this.metallic = 0.1,
    this.roughness = 0.6,
    this.opacity = 1.0,
    this.name,
  });

  /// RGBA in 0..1.
  final List<double> baseColor;
  final double metallic;
  final double roughness;
  final double opacity;
  final String? name;
}

/// Raw triangle-mesh data: positions/normals are flat `x,y,z` triples,
/// indices are triangle-list indices into those triples.
class MeshData {
  const MeshData({
    required this.positions,
    required this.normals,
    required this.indices,
  });

  final List<double> positions; // length = 3 * vertexCount
  final List<double> normals; // length = 3 * vertexCount
  final List<int> indices; // length = 3 * triangleCount

  int get vertexCount => positions.length ~/ 3;
}

/// One placed mesh instance in the scene.
class Node3D {
  const Node3D({
    required this.name,
    required this.mesh,
    required this.material,
    this.translation = Vec3.zero,
    this.rotation,
    this.datumId,
    this.seriesId,
    this.animatable = true,
  });

  final String name;
  final MeshData mesh;
  final Material3D material;
  final Vec3 translation;

  /// glTF quaternion `[x, y, z, w]`, or `null` for no rotation (the glTF
  /// default, equivalent to `[0, 0, 0, 1]`). Because glTF's node TRS
  /// order applies scale in *local* space before rotation, a node built
  /// with this — e.g. `MeshBuilder.radialPin`'s plain upright post, tilted
  /// into place via rotation instead of having its vertices baked at an
  /// angle — can still use the shared "growIn" `scale.y` animation
  /// correctly: scaling still happens along the mesh's own local up axis,
  /// which rotation then points wherever it needs to. See
  /// `MeshBuilder.quaternionFromUp` for how these get built.
  final List<double>? rotation;

  /// Optional identifiers so a future picking/interaction layer can map
  /// a rendered node back to the chart datum it represents. Not consumed
  /// by the current glTF export (glTF has no concept of this), but kept
  /// on the Dart-side scene graph for tooltip/legend wiring.
  final String? datumId;
  final String? seriesId;

  /// Whether [GlbWriter] should include this node in the baked
  /// "growIn" entrance animation (see glb_writer.dart). Data nodes
  /// (bars, slices) default to `true`; structural nodes like the
  /// ground plate should pass `false`.
  final bool animatable;
}

/// Everything needed to render one chart as a 3D scene.
class Scene3D {
  const Scene3D({required this.nodes, this.name = 'tenun_3d_scene'});

  final String name;
  final List<Node3D> nodes;
}
