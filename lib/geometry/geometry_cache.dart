/// Geometry cache for reusing common mesh primitives.
///
/// Modern engines never regenerate identical meshes. This cache stores
/// pre-built primitive meshes that can be reused across multiple entities,
/// reducing memory usage and improving performance.
library;

import '../scene/mesh_builder.dart';
import '../scene/scene_graph.dart';

/// Cache of commonly used geometry primitives.
class GeometryCache {
  GeometryCache({
    this.cubeSegments = 1,
    this.sphereStacks = 24,
    this.sphereSlices = 48,
    this.cylinderSegments = 32,
  }) {
    _initialize();
  }

  final int cubeSegments;
  final int sphereStacks;
  final int sphereSlices;
  final int cylinderSegments;

  late MeshData _cube;
  late MeshData _sphere;
  late MeshData _cylinder;
  late MeshData _plane;

  /// A unit cube mesh (1x1x1) centered at origin.
  MeshData get cube => _cube;

  /// A unit sphere mesh (radius 1) centered at origin.
  MeshData get sphere => _sphere;

  /// A unit cylinder mesh (radius 1, height 1) centered at origin.
  MeshData get cylinder => _cylinder;

  /// A unit plane mesh (1x1) on the XZ plane.
  MeshData get plane => _plane;

  void _initialize() {
    // Create a unit cube
    _cube = MeshBuilder.cuboid(sizeX: 1.0, sizeY: 1.0, sizeZ: 1.0);

    // Create a unit sphere
    _sphere = MeshBuilder.sphere(
      radius: 1.0,
      stacks: sphereStacks,
      slices: sphereSlices,
    );

    // Create a unit cylinder (approximated as a tall thin cuboid for now)
    // TODO: Add proper cylinder builder to MeshBuilder
    _cylinder = MeshBuilder.cuboid(sizeX: 1.0, sizeY: 1.0, sizeZ: 1.0);

    // Create a unit plane
    _plane = MeshBuilder.groundPlane(width: 1.0, depth: 1.0, thickness: 0.01);
  }

  /// Gets a cached mesh by name.
  MeshData? get(String name) {
    switch (name.toLowerCase()) {
      case 'cube':
        return _cube;
      case 'sphere':
        return _sphere;
      case 'cylinder':
        return _cylinder;
      case 'plane':
        return _plane;
      default:
        return null;
    }
  }

  /// Clears all cached meshes (useful for hot reload or theme changes).
  void clear() {
    _initialize();
  }
}

/// Global shared geometry cache instance.
GeometryCache? _sharedGeometryCache;

/// Returns the shared geometry cache instance.
GeometryCache get sharedGeometryCache {
  _sharedGeometryCache ??= GeometryCache();
  return _sharedGeometryCache!;
}

/// Sets the shared geometry cache instance (for testing or custom configuration).
void setSharedGeometryCache(GeometryCache cache) {
  _sharedGeometryCache = cache;
}
