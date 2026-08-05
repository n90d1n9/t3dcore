/// Enhanced material system with multiple material types.
///
/// Evolves the simple Material3D into a hierarchy of material types
/// supporting PBR, Phong, Unlit, Wireframe, Gradient, Heatmap, and custom shaders.
library;

import '../scene/scene_graph.dart';

/// Base class for all material types.
abstract class Material {
  const Material({this.name, this.doubleSided = false, this.opacity = 1.0});

  final String? name;
  final bool doubleSided;
  final double opacity;

  /// Converts this material to the base Material3D format.
  Material3D toMaterial3D();
}

/// Standard PBR (Physically Based Rendering) material.
///
/// Uses metallic/roughness model compatible with glTF 2.0.
class PBRMaterial extends Material {
  const PBRMaterial({
    this.baseColor = const [1.0, 1.0, 1.0, 1.0],
    this.metallic = 0.0,
    this.roughness = 1.0,
    this.emissive = const [0.0, 0.0, 0.0],
    this.normalScale = 1.0,
    this.occlusionStrength = 1.0,
    super.name,
    super.doubleSided,
    super.opacity,
  });

  /// RGBA base color factor [r, g, b, a].
  final List<double> baseColor;

  /// Metallic factor (0.0 = non-metallic, 1.0 = fully metallic).
  final double metallic;

  /// Roughness factor (0.0 = smooth/glossy, 1.0 = rough/matte).
  final double roughness;

  /// Emissive color [r, g, b] for self-illumination.
  final List<double> emissive;

  /// Normal map scale factor.
  final double normalScale;

  /// Occlusion strength (0.0 = no occlusion, 1.0 = full occlusion).
  final double occlusionStrength;

  @override
  Material3D toMaterial3D() {
    return Material3D(
      baseColor: [baseColor[0], baseColor[1], baseColor[2]],
      metallic: metallic,
      roughness: roughness,
      opacity: opacity < 1.0
          ? opacity
          : baseColor.length > 3
          ? baseColor[3]
          : 1.0,
      name: name,
    );
  }
}

/// Phong/Blinn-Phong material for non-PBR rendering.
class PhongMaterial extends Material {
  const PhongMaterial({
    this.diffuse = const [1.0, 1.0, 1.0],
    this.specular = const [0.5, 0.5, 0.5],
    this.shininess = 32.0,
    this.ambient = const [0.2, 0.2, 0.2],
    String? name,
    bool doubleSided = false,
    double opacity = 1.0,
  }) : super(name: name, doubleSided: doubleSided, opacity: opacity);

  final List<double> diffuse;
  final List<double> specular;
  final double shininess;
  final List<double> ambient;

  @override
  Material3D toMaterial3D() {
    // Approximate Phong as PBR
    return Material3D(
      baseColor: diffuse,
      metallic: 0.0,
      roughness: 1.0 - (shininess / 128.0),
      opacity: opacity,
      name: name,
    );
  }
}

/// Unlit material for flat shading without lighting calculations.
class UnlitMaterial extends Material {
  const UnlitMaterial({
    required this.color,
    String? name,
    bool doubleSided = false,
    double opacity = 1.0,
  }) : super(name: name, doubleSided: doubleSided, opacity: opacity);

  final List<double> color;

  @override
  Material3D toMaterial3D() {
    return Material3D(
      baseColor: color,
      metallic: 0.0,
      roughness: 1.0,
      opacity: opacity,
      name: name,
    );
  }
}

/// Wireframe material for technical visualization.
class WireframeMaterial extends Material {
  const WireframeMaterial({
    this.color = const [1.0, 1.0, 1.0, 1.0],
    this.lineWidth = 1.0,
    String? name,
    bool doubleSided = false,
    double opacity = 1.0,
  }) : super(name: name, doubleSided: doubleSided, opacity: opacity);

  final List<double> color;
  final double lineWidth;

  @override
  Material3D toMaterial3D() {
    return Material3D(
      baseColor: [color[0], color[1], color[2]],
      metallic: 0.0,
      roughness: 1.0,
      opacity: opacity,
      name: name,
    );
  }
}

/// Gradient material for color transitions based on position or value.
class GradientMaterial extends Material {
  const GradientMaterial({
    required this.gradient,
    this.gradientType = GradientType.linear,
    this.direction = const [0.0, 1.0, 0.0],
    String? name,
    bool doubleSided = false,
    double opacity = 1.0,
  }) : super(name: name, doubleSided: doubleSided, opacity: opacity);

  final List<List<double>> gradient;
  final GradientType gradientType;
  final List<double> direction;

  @override
  Material3D toMaterial3D() {
    // Use first gradient color as base
    return Material3D(
      baseColor: gradient.isNotEmpty ? gradient[0] : [1.0, 1.0, 1.0],
      metallic: 0.0,
      roughness: 0.5,
      opacity: opacity,
      name: name,
    );
  }
}

/// Type of gradient interpolation.
enum GradientType { linear, radial, spherical }

/// Heatmap material for data visualization.
class HeatmapMaterial extends Material {
  const HeatmapMaterial({
    required this.minValue,
    required this.maxValue,
    this.colorMap = ColorMap.viridis,
    String? name,
    bool doubleSided = false,
    double opacity = 1.0,
  }) : super(name: name, doubleSided: doubleSided, opacity: opacity);

  final double minValue;
  final double maxValue;
  final ColorMap colorMap;

  @override
  Material3D toMaterial3D() {
    // Return middle of colormap as base
    final midColor = colorMap.getColorAt(0.5);
    return Material3D(
      baseColor: [midColor[0], midColor[1], midColor[2]],
      metallic: 0.0,
      roughness: 0.5,
      opacity: opacity,
      name: name,
    );
  }

  /// Gets color for a specific value.
  List<double> getColorForValue(double value) {
    final t = ((value - minValue) / (maxValue - minValue)).clamp(0.0, 1.0);
    return colorMap.getColorAt(t);
  }
}

/// Predefined color maps for heatmaps.
enum ColorMap { viridis, plasma, inferno, magma, rainbow, coolwarm }

extension ColorMapExtension on ColorMap {
  /// Gets a color at position t (0.0 to 1.0) in this colormap.
  List<double> getColorAt(double t) {
    switch (this) {
      case ColorMap.viridis:
        return _viridis(t);
      case ColorMap.plasma:
        return _plasma(t);
      case ColorMap.inferno:
        return _inferno(t);
      case ColorMap.magma:
        return _magma(t);
      case ColorMap.rainbow:
        return _rainbow(t);
      case ColorMap.coolwarm:
        return _coolwarm(t);
    }
  }

  // Simplified color map approximations
  static List<double> _viridis(double t) {
    return [0.267 + t * 0.5, 0.0048 + t * 0.7, 0.329 + t * 0.3];
  }

  static List<double> _plasma(double t) {
    return [0.05 + t * 0.9, 0.0 + t * 0.5, 0.3 + t * 0.6];
  }

  static List<double> _inferno(double t) {
    return [0.0 + t * 0.8, t * 0.3, t * 0.2];
  }

  static List<double> _magma(double t) {
    return [0.0 + t * 0.7, 0.0 + t * 0.4, 0.2 + t * 0.6];
  }

  static List<double> _rainbow(double t) {
    return [t, (1.0 - (2.0 * (t - 0.5)).abs()).abs(), 1.0 - t];
  }

  static List<double> _coolwarm(double t) {
    return [t, 0.5, 1.0 - t];
  }
}

/// Material library for managing collections of materials.
class MaterialLibrary {
  final Map<String, Material> _materials = {};

  /// Adds a material to the library.
  void add(String name, Material material) {
    _materials[name] = material;
  }

  /// Gets a material by name.
  Material? get(String name) {
    return _materials[name];
  }

  /// Gets or creates a material by name.
  Material getOrCreate(String name, Material Function() creator) {
    return _materials.putIfAbsent(name, creator);
  }

  /// Removes a material from the library.
  void remove(String name) {
    _materials.remove(name);
  }

  /// Clears all materials.
  void clear() {
    _materials.clear();
  }

  /// Lists all material names.
  Iterable<String> get names => _materials.keys;

  /// Gets all materials.
  Iterable<Material> get materials => _materials.values;
}
