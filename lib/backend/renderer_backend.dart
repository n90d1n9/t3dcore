/// Renderer backend abstraction for targeting multiple rendering technologies.
///
/// This is the most important architectural enhancement: separating scene
/// generation from rendering allows the same Scene3D to target multiple
/// backends (Flutter3DController, ThreeJS, Filament, Babylon, WebGPU, etc.)
/// without changing chart code.
library;

import 'dart:typed_data';

import '../scene/scene_graph.dart';

/// Abstract base class for renderer backends.
///
/// Each backend implementation knows how to convert a Scene3D into
/// its own native representation.
abstract class RendererBackend {
  const RendererBackend();

  /// Builds a render object from a scene.
  ///
  /// The return type depends on the backend implementation:
  /// - GLTFBackend: Uint8List (GLB bytes)
  /// - FlutterBackend: ModelViewer configuration
  /// - ThreeJSBackend: JavaScript scene object
  /// etc.
  Future<dynamic> build(Scene3D scene);

  /// Gets the backend name for debugging/logging.
  String get name;
}

/// GLTF/GLB export backend.
///
/// Converts Scene3D into glTF 2.0 binary format.
class GLTFBackend extends RendererBackend {
  const GLTFBackend({this.prettyPrint = false});

  final bool prettyPrint;

  @override
  Future<Uint8List> build(Scene3D scene) async {
    // Import here to avoid circular dependency at compile time
    // In actual implementation, this would call GlbWriter.build(scene)
    throw UnimplementedError(
      'GLTFBackend.build() should delegate to GlbWriter',
    );
  }

  @override
  String get name => 'GLTF';
}

/// Flutter 3D Controller backend.
///
/// Targets flutter_3d_controller's model-viewer wrapper.
class FlutterBackend extends RendererBackend {
  const FlutterBackend({this.autoOrbit = false, this.rotationSpeed = 12});

  final bool autoOrbit;
  final int rotationSpeed;

  @override
  Future<Map<String, dynamic>> build(Scene3D scene) async {
    // Returns configuration for flutter_3d_controller
    return {
      'scene': scene,
      'autoOrbit': autoOrbit,
      'rotationSpeed': rotationSpeed,
    };
  }

  @override
  String get name => 'Flutter3DController';
}

/// Placeholder for future Three.js backend.
///
/// Would export scene as Three.js JSON or JavaScript code.
class ThreeJSBackend extends RendererBackend {
  const ThreeJSBackend();

  @override
  Future<String> build(Scene3D scene) async {
    throw UnimplementedError('ThreeJSBackend not yet implemented');
  }

  @override
  String get name => 'ThreeJS';
}

/// Placeholder for future Filament backend.
///
/// Filament is Google's real-time physically-based rendering engine.
class FilamentBackend extends RendererBackend {
  const FilamentBackend();

  @override
  Future<void> build(Scene3D scene) async {
    throw UnimplementedError('FilamentBackend not yet implemented');
  }

  @override
  String get name => 'Filament';
}

/// Placeholder for future Babylon.js backend.
class BabylonBackend extends RendererBackend {
  const BabylonBackend();

  @override
  Future<String> build(Scene3D scene) async {
    throw UnimplementedError('BabylonBackend not yet implemented');
  }

  @override
  String get name => 'Babylon';
}

/// Placeholder for future WebGPU backend.
class WebGPUBackend extends RendererBackend {
  const WebGPUBackend();

  @override
  Future<void> build(Scene3D scene) async {
    throw UnimplementedError('WebGPUBackend not yet implemented');
  }

  @override
  String get name => 'WebGPU';
}

/// Backend registry for runtime backend selection.
class BackendRegistry {
  static final BackendRegistry _instance = BackendRegistry._internal();

  factory BackendRegistry() {
    return _instance;
  }

  BackendRegistry._internal();

  final Map<String, RendererBackend> _backends = {};

  /// Registers a backend with a name.
  void register(String name, RendererBackend backend) {
    _backends[name] = backend;
  }

  /// Gets a registered backend by name.
  RendererBackend? get(String name) {
    return _backends[name];
  }

  /// Lists all registered backend names.
  Iterable<String> get registeredNames => _backends.keys;

  /// Clears all registered backends.
  void clear() {
    _backends.clear();
  }
}
