/// Lighting system for tenun_3d_core.
///
/// Provides abstract lighting types matching modern rendering engines:
/// Ambient, Directional, Point, Spot, Hemisphere, and HDRI.
library;

import '../scene/scene_graph.dart';

/// Base class for all light types.
abstract class Light {
  const Light({
    required this.color,
    required this.intensity,
    this.name,
    this.castShadow = false,
  });

  /// RGB color [r, g, b] in 0..1 range.
  final List<double> color;

  /// Light intensity (brightness multiplier).
  final double intensity;

  /// Optional name for identification.
  final String? name;

  /// Whether this light casts shadows.
  final bool castShadow;
}

/// Ambient light - uniform illumination from all directions.
class AmbientLight extends Light {
  const AmbientLight({
    super.color = const [1.0, 1.0, 1.0],
    super.intensity = 1.0,
    super.name,
  });
}

/// Directional light - simulates distant light source like the sun.
/// All rays are parallel.
class DirectionalLight extends Light {
  const DirectionalLight({
    required this.direction,
    super.color = const [1.0, 1.0, 1.0],
    super.intensity = 1.0,
    super.name,
    super.castShadow = true,
  });

  /// Direction the light is pointing (normalized vector).
  final Vec3 direction;
}

/// Point light - omnidirectional light source at a position.
class PointLight extends Light {
  const PointLight({
    required this.position,
    this.distance = 10.0,
    this.decay = 2.0,
    super.color = const [1.0, 1.0, 1.0],
    super.intensity = 1.0,
    super.name,
    super.castShadow = true,
  });

  /// Position of the light in 3D space.
  final Vec3 position;

  /// Maximum distance the light reaches.
  final double distance;

  /// How quickly the light intensity decays with distance.
  /// 1.0 = linear, 2.0 = quadratic (physically accurate).
  final double decay;
}

/// Spot light - directional light with a cone shape.
class SpotLight extends Light {
  const SpotLight({
    required this.position,
    required this.direction,
    this.angle = 0.785, // 45 degrees in radians
    this.penumbra = 0.0,
    this.distance = 10.0,
    this.decay = 2.0,
    super.color = const [1.0, 1.0, 1.0],
    super.intensity = 1.0,
    super.name,
    super.castShadow = true,
  });

  /// Position of the light.
  final Vec3 position;

  /// Direction the spot is pointing.
  final Vec3 direction;

  /// Maximum angle of the light cone in radians.
  final double angle;

  /// Percent of the light cone where there is a smooth falloff (0.0 to 1.0).
  final double penumbra;

  /// Maximum distance the light reaches.
  final double distance;

  /// How quickly the light intensity decays with distance.
  final double decay;
}

/// Hemisphere light - sky and ground color blend based on direction.
class HemisphereLight extends Light {
  const HemisphereLight({
    required this.skyColor,
    required this.groundColor,
    this.direction = const Vec3(0, 1, 0),
    super.intensity = 1.0,
    super.name,
  });

  /// Color of the sky (top hemisphere).
  final List<double> skyColor;

  /// Color of the ground (bottom hemisphere).
  final List<double> groundColor;

  /// Direction defining the up axis for the hemisphere.
  final Vec3 direction;
}

/// HDRI environment light - image-based lighting.
class HDRILight extends Light {
  const HDRILight({
    required this.environmentMap,
    super.intensity = 1.0,
    super.name,
    this.rotation = const [0, 0, 0, 1],
  }) : super(color: const [1.0, 1.0, 1.0]);

  /// Path or data for the HDRI environment map.
  final String environmentMap;

  /// Rotation quaternion for the environment map.
  final List<double> rotation;
}

/// Lighting configuration for a scene.
class LightingConfig {
  const LightingConfig({
    this.ambientLight,
    this.directionalLights = const [],
    this.pointLights = const [],
    this.spotLights = const [],
    this.hemisphereLight,
    this.hdriLight,
    this.shadowsEnabled = true,
  });

  /// Ambient light component.
  final AmbientLight? ambientLight;

  /// List of directional lights.
  final List<DirectionalLight> directionalLights;

  /// List of point lights.
  final List<PointLight> pointLights;

  /// List of spot lights.
  final List<SpotLight> spotLights;

  /// Hemisphere light (only one allowed).
  final HemisphereLight? hemisphereLight;

  /// HDRI environment light (only one allowed).
  final HDRILight? hdriLight;

  /// Whether shadows are enabled globally.
  final bool shadowsEnabled;

  /// Creates a default lighting setup with ambient + one directional light.
  factory LightingConfig.defaultSetup() {
    return LightingConfig(
      ambientLight: const AmbientLight(
        color: [0.4, 0.4, 0.4],
        intensity: 1.0,
      ),
      directionalLights: [
        const DirectionalLight(
          direction: Vec3(-1, -1, -1),
          color: [1.0, 1.0, 1.0],
          intensity: 1.0,
          castShadow: true,
        ),
      ],
      shadowsEnabled: true,
    );
  }

  /// Creates a studio lighting setup (three-point lighting).
  factory LightingConfig.studio() {
    return LightingConfig(
      ambientLight: const AmbientLight(
        color: [0.2, 0.2, 0.2],
        intensity: 0.5,
      ),
      directionalLights: [
        // Key light
        const DirectionalLight(
          direction: Vec3(-1, -1, -0.5),
          color: [1.0, 1.0, 1.0],
          intensity: 1.0,
          castShadow: true,
        ),
        // Fill light
        const DirectionalLight(
          direction: Vec3(1, -0.5, -0.5),
          color: [0.8, 0.9, 1.0],
          intensity: 0.5,
          castShadow: false,
        ),
        // Rim light
        const DirectionalLight(
          direction: Vec3(0, -0.5, 1),
          color: [1.0, 1.0, 1.0],
          intensity: 0.3,
          castShadow: false,
        ),
      ],
      shadowsEnabled: true,
    );
  }

  /// Creates a flat lighting setup (minimal shadows).
  factory LightingConfig.flat() {
    return LightingConfig(
      ambientLight: const AmbientLight(
        color: [0.6, 0.6, 0.6],
        intensity: 1.0,
      ),
      directionalLights: [
        const DirectionalLight(
          direction: Vec3(0, -1, 0),
          color: [1.0, 1.0, 1.0],
          intensity: 0.5,
          castShadow: false,
        ),
      ],
      shadowsEnabled: false,
    );
  }

  /// Creates a dramatic lighting setup (high contrast).
  factory LightingConfig.dramatic() {
    return LightingConfig(
      ambientLight: const AmbientLight(
        color: [0.1, 0.1, 0.1],
        intensity: 0.3,
      ),
      directionalLights: [
        const DirectionalLight(
          direction: Vec3(-0.5, -1, -0.5),
          color: [1.0, 0.95, 0.9],
          intensity: 1.5,
          castShadow: true,
        ),
      ],
      spotLights: [
        const SpotLight(
          position: Vec3(2, 3, 2),
          direction: Vec3(-1, -1, -1),
          angle: 0.5,
          penumbra: 0.3,
          color: [1.0, 0.8, 0.6],
          intensity: 2.0,
          castShadow: true,
        ),
      ],
      shadowsEnabled: true,
    );
  }

  /// Gets total number of lights.
  int get totalLights => 
      (ambientLight != null ? 1 : 0) +
      directionalLights.length +
      pointLights.length +
      spotLights.length +
      (hemisphereLight != null ? 1 : 0) +
      (hdriLight != null ? 1 : 0);

  /// Gets whether any light casts shadows.
  bool get hasShadowCasters => shadowsEnabled && (
      directionalLights.any((l) => l.castShadow) ||
      pointLights.any((l) => l.castShadow) ||
      spotLights.any((l) => l.castShadow));
}
