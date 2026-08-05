/// Layout engine for tenun_3d_core.
///
/// Provides various layout algorithms for positioning chart elements:
/// Cartesian, Polar, Geo, Tree, Force-directed, Treemap, Hex, and Surface layouts.
library;

import 'dart:math' as math;

import '../scene/scene_graph.dart';

/// Base class for all layout engines.
abstract class LayoutEngine {
  const LayoutEngine();

  /// Computes positions for data items.
  /// 
  /// Returns a list of (position, metadata) pairs.
  List<(Vec3 position, Map<String, dynamic> metadata)> computeLayout(
    List<Map<String, dynamic>> data,
    LayoutContext context,
  );
}

/// Context passed to layout engines.
class LayoutContext {
  const LayoutContext({
    this.bounds = const (-1.0, -1.0, -1.0, 1.0, 1.0, 1.0),
    this.padding = 0.1,
    this.customParams = const {},
  });

  /// Bounding box as (minX, minY, minZ, maxX, maxY, maxZ).
  final (double, double, double, double, double, double) bounds;

  /// Padding around content (0.0 to 1.0).
  final double padding;

  /// Custom parameters for specific layout types.
  final Map<String, dynamic> customParams;

  /// Gets the center of the bounds.
  Vec3 get center {
    return Vec3(
      (bounds.$1 + bounds.$4) / 2,
      (bounds.$2 + bounds.$5) / 2,
      (bounds.$3 + bounds.$6) / 2,
    );
  }

  /// Gets the size of the bounds.
  Vec3 get size {
    return Vec3(
      bounds.$4 - bounds.$1,
      bounds.$5 - bounds.$2,
      bounds.$6 - bounds.$3,
    );
  }
}

/// Cartesian grid layout for bar charts, scatter plots, etc.
class CartesianLayout extends LayoutEngine {
  const CartesianLayout({
    this.orientation = AxisOrientation.yUp,
    this.barGap = 0.2,
    this.groupGap = 0.5,
  });

  /// Which axis represents the value direction.
  final AxisOrientation orientation;

  /// Gap between bars within a group (as fraction of bar size).
  final double barGap;

  /// Gap between groups (as fraction of bar size).
  final double groupGap;

  @override
  List<(Vec3, Map<String, dynamic>)> computeLayout(
    List<Map<String, dynamic>> data,
    LayoutContext context,
  ) {
    final results = <(Vec3, Map<String, dynamic>)>[];
    final size = context.size;
    final center = context.center;
    
    // Calculate available space after padding
    final availWidth = size.x * (1 - context.padding * 2);
    final availHeight = size.y * (1 - context.padding * 2);
    final availDepth = size.z * (1 - context.padding * 2);

    // Group data by category if present
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final item in data) {
      final group = item['group']?.toString() ?? 'default';
      groups.putIfAbsent(group, () => []).add(item);
    }

    final groupCount = groups.length;
    final maxGroupSize = groups.values.map((g) => g.length).reduce((a, b) => a > b ? a : b);

    var groupIdx = 0;
    for (final entry in groups.entries) {
      final group = entry.value;
      final itemCount = group.length;

      for (var i = 0; i < itemCount; i++) {
        final item = group[i];
        
        double x, y, z;
        
        switch (orientation) {
          case AxisOrientation.yUp:
            // Bars rise along Y, arranged along X
            final totalItems = groupCount * maxGroupSize;
            final spacing = availWidth / totalItems;
            final baseX = context.bounds.$1 + context.padding * size.x;
            x = baseX + (groupIdx * maxGroupSize + i) * spacing + spacing / 2;
            y = context.bounds.$2 + context.padding * size.y;
            z = 0;
            break;
            
          case AxisOrientation.zUp:
            // For 3D charts where Z is up
            final totalItems = groupCount * maxGroupSize;
            final spacing = availWidth / totalItems;
            x = context.bounds.$1 + context.padding * size.x + 
                (groupIdx * maxGroupSize + i) * spacing + spacing / 2;
            y = 0;
            z = context.bounds.$3 + context.padding * size.z;
            break;
            
          case AxisOrientation.xUp:
            // Uncommon but supported
            x = 0;
            y = context.bounds.$2 + context.padding * size.y + 
                (groupIdx * maxGroupSize + i) * (availDepth / (groupCount * maxGroupSize));
            z = context.bounds.$3 + context.padding * size.z;
            break;
        }

        results.add((
          Vec3(x, y, z),
          {
            'value': item['value'],
            'category': item['category'],
            'group': entry.key,
            'index': i,
          },
        ));
      }
      
      groupIdx++;
    }

    return results;
  }
}

/// Orientation for cartesian layouts.
enum AxisOrientation {
  /// Y-axis points up (standard 2D chart style).
  yUp,

  /// Z-axis points up (common in 3D visualization).
  zUp,

  /// X-axis points up (less common).
  xUp,
}

/// Polar layout for pie charts, radar charts, etc.
class PolarLayout extends LayoutEngine {
  const PolarLayout({
    this.startAngle = 0.0,
    this.sweepAngle = 2 * math.pi,
    this.innerRadius = 0.0,
    this.outerRadius = 1.0,
    this.angularPadding = 0.02,
  });

  /// Starting angle in radians (0 = along positive X axis).
  final double startAngle;

  /// Total sweep angle in radians (2π = full circle).
  final double sweepAngle;

  /// Inner radius (0 = pie chart, >0 = donut chart).
  final double innerRadius;

  /// Outer radius scale.
  final double outerRadius;

  /// Angular padding between slices (as fraction of slice angle).
  final double angularPadding;

  @override
  List<(Vec3, Map<String, dynamic>)> computeLayout(
    List<Map<String, dynamic>> data,
    LayoutContext context,
  ) {
    final results = <(Vec3, Map<String, dynamic>)>[];
    final center = context.center;
    
    // Calculate total value for proportional sizing
    final total = data.fold<double>(
      0,
      (sum, item) => sum + ((item['value'] as num?)?.toDouble() ?? 0),
    );

    var currentAngle = startAngle;
    final effectiveSweep = sweepAngle * (1 - angularPadding * data.length);
    final paddingPerSlice = (sweepAngle - effectiveSweep) / data.length;

    for (final item in data) {
      final value = (item['value'] as num?)?.toDouble() ?? 0;
      final proportion = total > 0 ? value / total : 1.0 / data.length;
      final sliceAngle = proportion * effectiveSweep;

      // Calculate midpoint angle for positioning
      final midAngle = currentAngle + sliceAngle / 2;

      // Position at average radius, midpoint angle
      final avgRadius = (innerRadius + outerRadius) / 2 * 
                        math.min(context.size.x, context.size.y) / 2;
      
      final x = center.x + math.cos(midAngle) * avgRadius;
      final z = center.z + math.sin(midAngle) * avgRadius;
      final y = center.y;

      results.add((
        Vec3(x, y, z),
        {
          'value': value,
          'proportion': proportion,
          'startAngle': currentAngle,
          'endAngle': currentAngle + sliceAngle,
          'midAngle': midAngle,
          'innerRadius': innerRadius * math.min(context.size.x, context.size.y) / 2,
          'outerRadius': outerRadius * math.min(context.size.x, context.size.y) / 2,
          'height': value, // For extrusion
        },
      ));

      currentAngle += sliceAngle + paddingPerSlice;
    }

    return results;
  }
}

/// Geographic layout for map-based visualizations.
class GeoLayout extends LayoutEngine {
  const GeoLayout({
    this.projection = GeoProjection.mercator,
    this.center = const (0.0, 0.0),
    this.scale = 1.0,
  });

  /// Map projection to use.
  final GeoProjection projection;

  /// Center point as (longitude, latitude).
  final (double, double) center;

  /// Scale multiplier.
  final double scale;

  @override
  List<(Vec3, Map<String, dynamic>)> computeLayout(
    List<Map<String, dynamic>> data,
    LayoutContext context,
  ) {
    final results = <(Vec3, Map<String, dynamic>)>[];
    final center = context.center;
    final size = context.size;

    for (final item in data) {
      final lat = (item['latitude'] as num?)?.toDouble() ?? 0;
      final lng = (item['longitude'] as num?)?.toDouble() ?? 0;

      final (x, y) = _project(lng, lat);

      final worldX = center.x + x * size.x * scale;
      final worldZ = center.z + y * size.z * scale;
      final worldY = center.y;

      results.add((
        Vec3(worldX, worldY, worldZ),
        {
          'latitude': lat,
          'longitude': lng,
          'value': item['value'],
          'projectedX': x,
          'projectedY': y,
        },
      ));
    }

    return results;
  }

  (double, double) _project(double lng, double lat) {
    final lngRad = lng * math.pi / 180;
    final latRad = lat * math.pi / 180;

    switch (projection) {
      case GeoProjection.mercator:
        final x = lngRad;
        final y = math.log(math.tan(math.pi / 4 + latRad / 2));
        return (x, y.clamp(-2.0, 2.0));
        
      case GeoProjection.equirectangular:
        return (lngRad, latRad);
        
      case GeoProjection.stereographic:
        final k = 2 / (1 + math.cos(latRad) * math.cos(lngRad));
        return (k * math.cos(latRad) * math.sin(lngRad), k * math.sin(latRad));
        
      case GeoProjection.orthographic:
        return (
          math.cos(latRad) * math.sin(lngRad),
          math.sin(latRad),
        );
    }
  }
}

/// Geographic projection types.
enum GeoProjection {
  /// Mercator projection (preserves angles, distorts area).
  mercator,

  /// Equirectangular projection (simple lat/lng to x/y).
  equirectangular,

  /// Stereographic projection (preserves circles).
  stereographic,

  /// Orthographic projection (appears spherical).
  orthographic,
}

/// Tree layout for hierarchical data.
class TreeLayout extends LayoutEngine {
  const TreeLayout({
    this.orientation = TreeOrientation.topDown,
    this.levelSpacing = 1.0,
    this.siblingSpacing = 0.5,
  });

  /// Direction of tree growth.
  final TreeOrientation orientation;

  /// Spacing between levels.
  final double levelSpacing;

  /// Spacing between siblings.
  final double siblingSpacing;

  @override
  List<(Vec3, Map<String, dynamic>)> computeLayout(
    List<Map<String, dynamic>> data,
    LayoutContext context,
  ) {
    // Simplified tree layout - would need proper tree structure input
    final results = <(Vec3, Map<String, dynamic>)>[];
    
    for (var i = 0; i < data.length; i++) {
      final item = data[i];
      final depth = (item['depth'] as int?) ?? 0;
      final index = (item['index'] as int?) ?? i;

      double x, y, z;
      
      switch (orientation) {
        case TreeOrientation.topDown:
          x = index * siblingSpacing;
          y = -depth * levelSpacing;
          z = 0;
          break;
        case TreeOrientation.leftToRight:
          x = depth * levelSpacing;
          y = index * siblingSpacing;
          z = 0;
          break;
        case TreeOrientation.radial:
          final angle = (index / data.length) * 2 * math.pi;
          final radius = depth * levelSpacing;
          x = math.cos(angle) * radius;
          y = 0;
          z = math.sin(angle) * radius;
          break;
      }

      results.add((
        Vec3(x, y, z),
        {
          'depth': depth,
          'index': index,
          'value': item['value'],
        },
      ));
    }

    return results;
  }
}

/// Tree orientation options.
enum TreeOrientation {
  topDown,
  leftToRight,
  radial,
}

/// Force-directed layout for network/graph data.
class ForceLayout extends LayoutEngine {
  const ForceLayout({
    this.repulsion = 100.0,
    this.attraction = 0.01,
    this.damping = 0.85,
    this.iterations = 50,
    this.initialRadius = 1.0,
  });

  /// Repulsion force between nodes.
  final double repulsion;

  /// Attraction force along edges.
  final double attraction;

  /// Velocity damping per iteration.
  final double damping;

  /// Number of simulation iterations.
  final int iterations;

  /// Initial radius for random placement.
  final double initialRadius;

  @override
  List<(Vec3, Map<String, dynamic>)> computeLayout(
    List<Map<String, dynamic>> data,
    LayoutContext context,
  ) {
    // Simplified force-directed layout
    final results = <(Vec3, Map<String, dynamic>)>[];
    final rng = math.Random(42); // Deterministic for reproducibility

    // Initialize positions randomly on a circle
    final positions = data.map((item) {
      final angle = rng.nextDouble() * 2 * math.pi;
      final r = rng.nextDouble() * initialRadius;
      return Vec3(
        math.cos(angle) * r,
        0,
        math.sin(angle) * r,
      );
    }).toList();

    final velocities = List.generate(data.length, (_) => Vec3.zero);

    // Run simulation
    for (var iter = 0; iter < iterations; iter++) {
      // Apply forces
      for (var i = 0; i < data.length; i++) {
        var force = Vec3.zero;

        // Repulsion from all other nodes
        for (var j = 0; j < data.length; j++) {
          if (i == j) continue;
          final delta = positions[i] - positions[j];
          final distSq = delta.dot(delta) + 0.01; // Avoid division by zero
          final dist = math.sqrt(distSq);
          force = force + delta * (repulsion / distSq / dist);
        }

        velocities[i] = (velocities[i] + force) * damping;
        positions[i] = positions[i] + velocities[i];
      }
    }

    // Build results
    for (var i = 0; i < data.length; i++) {
      results.add((
        positions[i],
        {
          'value': data[i]['value'],
          'index': i,
        },
      ));
    }

    return results;
  }
}

/// Surface layout for 3D surface plots.
class SurfaceLayout extends LayoutEngine {
  const SurfaceLayout({
    this.gridWidth = 20,
    this.gridDepth = 20,
    this.scaleHeight = 1.0,
  });

  /// Number of grid points along width.
  final int gridWidth;

  /// Number of grid points along depth.
  final int gridDepth;

  /// Height scaling factor.
  final double scaleHeight;

  @override
  List<(Vec3, Map<String, dynamic>)> computeLayout(
    List<Map<String, dynamic>> data,
    LayoutContext context,
  ) {
    final results = <(Vec3, Map<String, dynamic>)>[];
    final size = context.size;
    final center = context.center;

    for (var i = 0; i < gridWidth; i++) {
      for (var j = 0; j < gridDepth; j++) {
        final u = i / (gridWidth - 1);
        final v = j / (gridDepth - 1);

        // Find corresponding data value (interpolation would be better)
        final dataIndex = (u * v * data.length).round().clamp(0, data.length - 1);
        final value = (data[dataIndex]['value'] as num?)?.toDouble() ?? 0;

        final x = context.bounds.$1 + u * size.x;
        final z = context.bounds.$3 + v * size.z;
        final y = center.y + value * scaleHeight;

        results.add((
          Vec3(x, y, z),
          {
            'u': u,
            'v': v,
            'gridX': i,
            'gridZ': j,
            'value': value,
          },
        ));
      }
    }

    return results;
  }
}

/// Hexagonal grid layout.
class HexLayout extends LayoutEngine {
  const HexLayout({
    this.hexSize = 0.5,
    this.orientation = HexOrientation.pointy,
  });

  /// Size of each hexagon (distance from center to vertex).
  final double hexSize;

  /// Hexagon orientation.
  final HexOrientation orientation;

  @override
  List<(Vec3, Map<String, dynamic>)> computeLayout(
    List<Map<String, dynamic>> data,
    LayoutContext context,
  ) {
    final results = <(Vec3, Map<String, dynamic>)>[];
    final center = context.center;

    var index = 0;
    var ring = 0;
    var posInRing = 0;

    for (final item in data) {
      final (q, r) = _hexCoords(ring, posInRing);
      
      double x, z;
      if (orientation == HexOrientation.pointy) {
        x = hexSize * math.sqrt(3) * (q + r / 2);
        z = hexSize * 3 / 2 * r;
      } else {
        x = hexSize * 3 / 2 * q;
        z = hexSize * math.sqrt(3) * (r + q / 2);
      }

      results.add((
        Vec3(center.x + x, center.y, center.z + z),
        {
          'value': item['value'],
          'hexQ': q,
          'hexR': r,
          'ring': ring,
        },
      ));

      // Move to next hex position
      posInRing++;
      if (posInRing >= 6 * ring && ring > 0) {
        ring++;
        posInRing = 0;
      } else if (ring == 0) {
        ring = 1;
      }
    }

    return results;
  }

  (int, int) _hexCoords(int ring, int posInRing) {
    if (ring == 0) return (0, 0);

    // Start at top-left corner and go clockwise
    final directions = [
      (1, -1), (1, 0), (0, 1),
      (-1, 1), (-1, 0), (0, -1),
    ];

    var q = -ring + 1;
    var r = 0;
    var side = 0;
    var stepsOnSide = 0;

    for (var i = 0; i < posInRing; i++) {
      q += directions[side].$1;
      r += directions[side].$2;
      stepsOnSide++;
      if (stepsOnSide >= ring) {
        side = (side + 1) % 6;
        stepsOnSide = 0;
      }
    }

    return (q, r);
  }
}

/// Hexagon orientation options.
enum HexOrientation {
  /// Pointy-top hexagons.
  pointy,

  /// Flat-top hexagons.
  flat,
}
