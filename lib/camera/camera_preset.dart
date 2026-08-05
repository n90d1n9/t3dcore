/// Camera configuration parsed from a chart spec's `camera` block.
///
/// `flutter_3d_controller` (backed by `<model-viewer>`) exposes camera
/// control as *orbit + target*, not an arbitrary eye position/FOV matrix:
///   - `controller.setCameraOrbit(theta, phi, radius)` — three numeric
///     args (degrees, degrees, model-space distance).
///   - `controller.setCameraTarget(x, y, z)` — look-at point.
/// So rather than pretending we can set a raw `camera.position` like a
/// full engine, this maps the three named presets from the architecture
/// note onto orbit angles, which is what the underlying viewer actually
/// supports.
class CameraSpec {
  const CameraSpec({
    required this.orbitTheta,
    required this.orbitPhi,
    required this.orbitRadiusMultiplier,
    this.autoOrbit = false,
    this.target = const [0, 0, 0],
  });

  /// Horizontal orbit angle in degrees (0 = looking from +Z toward origin).
  final double orbitTheta;

  /// Vertical orbit angle in degrees (90 = looking straight down).
  final double orbitPhi;

  /// Multiplier applied to the scene's bounding radius to get the
  /// camera's orbit radius, so the same preset frames small and large
  /// charts sensibly instead of using one fixed distance.
  final double orbitRadiusMultiplier;

  final bool autoOrbit;
  final List<double> target;

  factory CameraSpec.fromJson(Map<String, dynamic>? json) {
    if (json == null) return CameraSpec.perspective();
    final preset = json['preset'] as String?;
    final autoOrbit = json['orbit'] == true;
    switch (preset) {
      case 'isometric':
        return CameraSpec.isometric(autoOrbit: autoOrbit);
      case 'top':
        return CameraSpec.top(autoOrbit: autoOrbit);
      case 'perspective':
      default:
        return CameraSpec.perspective(autoOrbit: autoOrbit);
    }
  }

  factory CameraSpec.perspective({bool autoOrbit = false}) => CameraSpec(
    orbitTheta: 35,
    orbitPhi: 65,
    orbitRadiusMultiplier: 2.2,
    autoOrbit: autoOrbit,
  );

  factory CameraSpec.isometric({bool autoOrbit = false}) => CameraSpec(
    orbitTheta: 45,
    orbitPhi: 55,
    orbitRadiusMultiplier: 2.4,
    autoOrbit: autoOrbit,
  );

  factory CameraSpec.top({bool autoOrbit = false}) => CameraSpec(
    orbitTheta: 0,
    orbitPhi: 2,
    orbitRadiusMultiplier: 2.8,
    autoOrbit: autoOrbit,
  );

  /// Orbit radius scaled to fit [sceneRadius] (the scene's own bounding
  /// radius), for direct use as `controller.setCameraOrbit(orbitTheta,
  /// orbitPhi, radiusFor(sceneRadius))`.
  double radiusFor(double sceneRadius) {
    return (sceneRadius * orbitRadiusMultiplier).clamp(0.5, 1000.0).toDouble();
  }
}
