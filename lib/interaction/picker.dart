/// Interaction system for tenun_3d_core.
///
/// Provides picking, hit testing, selection, hover, and tooltip abstractions.
/// This allows swapping between different picking implementations (e.g., 
/// LegendPicker vs RaycastPicker) without API changes.
library;

import '../scene/scene_graph.dart';
import '../ecs/entity_component_system.dart';

/// Result of a pick/raycast operation.
class PickResult {
  const PickResult({
    this.hit = false,
    this.entity,
    this.point,
    this.normal,
    this.distance,
    this.uv,
    this.faceIndex,
  });

  /// Whether the ray hit anything.
  final bool hit;

  /// The entity that was hit (if any).
  final Entity? entity;

  /// World-space position of the hit.
  final Vec3? point;

  /// World-space normal at the hit point.
  final Vec3? normal;

  /// Distance from ray origin to hit point.
  final double? distance;

  /// UV coordinates at hit point (if available).
  final List<double>? uv;

  /// Index of the triangle face that was hit.
  final int? faceIndex;

  /// Creates a miss result.
  factory PickResult.miss() {
    return const PickResult(hit: false);
  }

  /// Creates a hit result.
  factory PickResult.hit({
    required Entity entity,
    required Vec3 point,
    required Vec3 normal,
    required double distance,
    List<double>? uv,
    int? faceIndex,
  }) {
    return PickResult(
      hit: true,
      entity: entity,
      point: point,
      normal: normal,
      distance: distance,
      uv: uv,
      faceIndex: faceIndex,
    );
  }
}

/// A ray for picking operations.
class Ray {
  const Ray({
    required this.origin,
    required this.direction,
  });

  /// Origin point of the ray.
  final Vec3 origin;

  /// Normalized direction vector of the ray.
  final Vec3 direction;

  /// Gets a point along the ray at distance t.
  Vec3 pointAt(double t) => origin + direction * t;
}

/// Abstract base for picking implementations.
abstract class Picker {
  const Picker();

  /// Performs a pick test with the given ray.
  PickResult pick(Ray ray, World world);

  /// Performs a multi-pick test, returning all hits sorted by distance.
  List<PickResult> pickAll(Ray ray, World world) {
    final result = pick(ray, world);
    return result.hit ? [result] : [];
  }
}

/// Placeholder picker that always misses (for backends without picking support).
class NullPicker extends Picker {
  const NullPicker();

  @override
  PickResult pick(Ray ray, World world) {
    return const PickResult.miss();
  }
}

/// Legend-based picker - uses metadata matching instead of raycasting.
/// This is the current fallback for model-viewer which doesn't expose
/// raycasting APIs.
class LegendPicker extends Picker {
  const LegendPicker({
    this.matchStrategy = MatchStrategy.nearest,
  });

  /// Strategy for matching picks to entities.
  final MatchStrategy matchStrategy;

  @override
  PickResult pick(Ray ray, World world) {
    // This is a placeholder - actual implementation would need
    // screen-to-world mapping and legend correlation
    return const PickResult.miss();
  }
}

/// Strategy for matching picks to entities.
enum MatchStrategy {
  /// Pick the nearest entity.
  nearest,

  /// Pick based on screen-space bounds.
  screenBounds,

  /// Pick based on data ID matching.
  dataId,
}

/// Future raycast-based picker for backends with raycasting support.
class RaycastPicker extends Picker {
  const RaycastPicker({
    this.triangleAccuracy = true,
  });

  /// Whether to do per-triangle intersection tests (more accurate but slower).
  final bool triangleAccuracy;

  @override
  PickResult pick(Ray ray, World world) {
    // TODO: Implement proper ray-triangle intersection
    // This would iterate through mesh entities and test intersections
    return const PickResult.miss();
  }

  /// Tests intersection between a ray and a triangle.
  static PickResult? rayTriangleIntersection({
    required Ray ray,
    required Vec3 v0,
    required Vec3 v1,
    required Vec3 v2,
    Entity? entity,
  }) {
    // Möller–Trumbore ray-triangle intersection algorithm
    final edge1 = v1 - v0;
    final edge2 = v2 - v0;
    final h = ray.direction.cross(edge2);
    final a = edge1.dot(h);

    if (a.abs() < 1e-10) {
      return null; // Ray parallel to triangle
    }

    final f = 1.0 / a;
    final s = ray.origin - v0;
    final u = f * s.dot(h);

    if (u < 0.0 || u > 1.0) {
      return null;
    }

    final q = s.cross(edge1);
    final v = f * ray.direction.dot(q);

    if (v < 0.0 || u + v > 1.0) {
      return null;
    }

    final t = f * edge2.dot(q);

    if (t < 1e-10) {
      return null; // Intersection behind ray origin
    }

    final point = ray.pointAt(t);
    final normal = edge1.cross(edge2).normalized();

    return PickResult.hit(
      entity: entity ?? Entity(id: EntityId.newId()),
      point: point,
      normal: normal,
      distance: t,
      uv: [u, v],
    );
  }
}

/// Selection state management.
class SelectionManager {
  SelectionManager({
    this.multiSelect = false,
    this.toggleOnSecondClick = true,
  });

  /// Currently selected entities.
  final Set<EntityId> _selected = {};

  /// Currently hovered entity.
  EntityId? _hovered;

  /// Whether multiple entities can be selected at once.
  final bool multiSelect;

  /// Whether clicking an already selected entity deselects it.
  final bool toggleOnSecondClick;

  /// Callback when selection changes.
  void Function(Set<EntityId>)? onSelectionChanged;

  /// Callback when hover changes.
  void Function(EntityId?)? onHoverChanged;

  /// Gets the currently selected entity IDs.
  Set<EntityId> get selected => Set.unmodifiable(_selected);

  /// Gets the currently hovered entity ID.
  EntityId? get hovered => _hovered;

  /// Selects an entity.
  void select(EntityId id, {bool additive = false}) {
    if (!multiSelect && !additive) {
      _selected.clear();
    }

    if (_selected.contains(id) && toggleOnSecondClick && !additive) {
      _selected.remove(id);
    } else {
      _selected.add(id);
    }

    onSelectionChanged?.call(_selected);
  }

  /// Deselects an entity.
  void deselect(EntityId id) {
    if (_selected.remove(id)) {
      onSelectionChanged?.call(_selected);
    }
  }

  /// Clears all selections.
  void clearSelection() {
    if (_selected.isNotEmpty) {
      _selected.clear();
      onSelectionChanged?.call(_selected);
    }
  }

  /// Sets the hovered entity.
  void setHovered(EntityId? id) {
    if (_hovered != id) {
      _hovered = id;
      onHoverChanged?.call(id);
    }
  }

  /// Clears hover state.
  void clearHover() {
    if (_hovered != null) {
      _hovered = null;
      onHoverChanged?.call(null);
    }
  }

  /// Checks if an entity is selected.
  bool isSelected(EntityId id) => _selected.contains(id);

  /// Checks if an entity is hovered.
  bool isHovered(EntityId id) => _hovered == id;
}

/// Tooltip configuration and management.
class TooltipConfig {
  const TooltipConfig({
    this.enabled = true,
    this.delay = 0.3,
    this.showDuration = 2.0,
    this.offset = const Vec3(0.1, 0.1, 0.1),
    this.maxWidth = 200,
    this.style = TooltipStyle.defaultStyle,
  });

  /// Whether tooltips are enabled.
  final bool enabled;

  /// Delay in seconds before showing tooltip.
  final double delay;

  /// Duration to show tooltip after hover ends (0 = hide immediately).
  final double showDuration;

  /// Offset from the hit point.
  final Vec3 offset;

  /// Maximum width in pixels.
  final double maxWidth;

  /// Tooltip visual style.
  final TooltipStyle style;
}

/// Visual style for tooltips.
enum TooltipStyle {
  /// Default rounded rectangle with shadow.
  defaultStyle,

  /// Minimal flat style.
  flat,

  /// Glass/material design style.
  glass,

  /// Technical/CAD style with leader line.
  technical,
}

/// Tooltip data for display.
class TooltipData {
  const TooltipData({
    required this.title,
    this.subtitle,
    this.values,
    this.customContent,
  });

  /// Main title text.
  final String title;

  /// Optional subtitle text.
  final String? subtitle;

  /// Key-value pairs to display.
  final Map<String, dynamic>? values;

  /// Custom widget/content (backend-specific).
  final dynamic customContent;

  TooltipData copyWith({
    String? title,
    String? subtitle,
    Map<String, dynamic>? values,
    dynamic customContent,
  }) {
    return TooltipData(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      values: values ?? this.values,
      customContent: customContent ?? this.customContent,
    );
  }
}

/// Hit test utilities.
class HitTestUtils {
  /// Computes the bounding sphere of a mesh.
  static (Vec3 center, double radius) computeBoundingSphere(MeshData mesh) {
    if (mesh.vertexCount == 0) {
      return (Vec3.zero, 0.0);
    }

    var minX = double.infinity;
    var minY = double.infinity;
    var minZ = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    var maxZ = double.negativeInfinity;

    for (var i = 0; i < mesh.positions.length; i += 3) {
      final x = mesh.positions[i];
      final y = mesh.positions[i + 1];
      final z = mesh.positions[i + 2];

      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (z < minZ) minZ = z;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
      if (z > maxZ) maxZ = z;
    }

    final center = Vec3(
      (minX + maxX) / 2,
      (minY + maxY) / 2,
      (minZ + maxZ) / 2,
    );

    var maxDistSq = 0.0;
    for (var i = 0; i < mesh.positions.length; i += 3) {
      final dx = mesh.positions[i] - center.x;
      final dy = mesh.positions[i + 1] - center.y;
      final dz = mesh.positions[i + 2] - center.z;
      final distSq = dx * dx + dy * dy + dz * dz;
      if (distSq > maxDistSq) maxDistSq = distSq;
    }

    return (center, math.sqrt(maxDistSq));
  }

  /// Tests if a ray intersects a sphere.
  static bool raySphereIntersection({
    required Ray ray,
    required Vec3 center,
    required double radius,
  }) {
    final oc = ray.origin - center;
    final b = oc.dot(ray.direction);
    final c = oc.dot(oc) - radius * radius;
    final discriminant = b * b - c;

    return discriminant >= 0 && b < 0;
  }
}

// Import math for sqrt
import 'dart:math' as math;
