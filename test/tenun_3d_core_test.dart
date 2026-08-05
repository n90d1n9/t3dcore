import 'package:flutter_test/flutter_test.dart';
import 'package:tenun_3d_core/camera/camera_preset.dart';

void main() {
  test('CameraPreset.isometric exists', () {
    expect(CameraSpec.isometric(), isA<CameraSpec>());
  });
}
