# Tenun 3D Core Architecture

## Overview

`tenun_3d_core` is a lightweight 3D rendering engine for data visualization, designed to serve as the 3D rendering foundation for every Tenun visualization. It has evolved from a simple wrapper around `flutter_3d_controller` into a complete rendering pipeline with backend independence.

## Architecture Principles

1. **Separation of Concerns**: Scene generation is completely separated from rendering
2. **Backend Independence**: Same scene can target multiple rendering backends
3. **Component-Based Design**: ECS architecture for extensibility
4. **Pluggable Pipeline**: Each stage of the rendering pipeline is modular
5. **Zero Transitive Dependencies**: No external 3D/math packages required

## Rendering Pipeline

```
Chart Spec
     │
     ▼
Chart Compiler
     │
     ▼
Layout Engine
     │
     ▼
Scene Graph (ECS)
     │
     ├──────────────┐
     │              │
Geometry        Material
Engine          System
     │              │
     └──────┬───────┘
            ▼
     Animation System
            ▼
      Lighting System
            ▼
      Camera System
            ▼
     Optimization Pass
            ▼
      Renderer Backend
      ├── GLTF Export
      ├── Flutter3DController
      ├── ThreeJS (future)
      ├── Filament (future)
      ├── Babylon (future)
      └── WebGPU (future)
```

## Package Structure

```
tenun_3d_core/
│
├── animation/           # Animation system
│   └── animation.dart   # Tracks, keyframes, players, timelines
│
├── backend/             # Renderer backend abstraction
│   └── renderer_backend.dart  # Multiple backend support
│
├── camera/              # Camera abstractions
│   └── camera_preset.dart     # Perspective, orthographic, orbit
│
├── compiler/            # Chart compilation pipeline
│   └── chart_compiler.dart    # Compiler passes, context
│
├── ecs/                 # Entity Component System
│   └── entity_component_system.dart  # Entities, components, world
│
├── geometry/            # Geometry management
│   └── geometry_cache.dart    # Cached primitive meshes
│
├── interaction/         # Picking and selection
│   └── picker.dart            # Raycasting, selection, tooltips
│
├── layout/              # Layout engines
│   └── layout_engine.dart     # Cartesian, polar, geo, tree, etc.
│
├── lighting/            # Lighting system
│   └── lighting.dart          # Ambient, directional, point, spot, HDRI
│
├── material/            # Material system
│   └── material_system.dart   # PBR, Phong, Unlit, Heatmap, etc.
│
├── scene/               # Core scene graph
│   ├── scene_graph.dart       # Vec3, Material3D, MeshData, Node3D, Scene3D
│   └── mesh_builder.dart      # Procedural mesh generators
│
├── glb_writer.dart      # glTF/GLB export
│
└── tenun_3d_core.dart   # Main library exports
```

## Key Components

### 1. Entity Component System (ECS)

Replaces monolithic `Node3D` with flexible component-based architecture:

```dart
class Entity {
  EntityId id;
  Map<Type, Component> components;
}

// Components
TransformComponent  // position, rotation, scale
MeshComponent       // mesh reference
MaterialComponent   // material reference
MetadataComponent   // chart data linkage
VisibilityComponent // visibility control
BoundsComponent     // spatial bounds
AnimationComponent  // animation state
SelectableComponent // interaction state
```

### 2. Chart Compiler Pipeline

Modular compilation through composable passes:

```dart
abstract class ChartCompiler<T> {
  Scene3D compile(T config, CompileContext context);
}

abstract class CompilerPass {
  void execute(Scene3D scene, CompileContext context);
}

// Built-in passes
LayoutPass      // Position elements
GeometryPass    // Generate meshes
MaterialPass    // Assign materials
AnimationPass   // Setup animations
OptimizationPass // Optimize scene
```

### 3. Geometry Cache

Shared geometry prevents redundant mesh generation:

```dart
class GeometryCache {
  MeshData cube;      // Reusable unit cube
  MeshData sphere;    // Reusable unit sphere
  MeshData cylinder;  // Reusable unit cylinder
  MeshData plane;     // Reusable unit plane
}
```

### 4. Material System

Hierarchical material types:

```dart
abstract class Material {
  Material3D toMaterial3D();
}

class PBRMaterial extends Material {}      // Physically based
class PhongMaterial extends Material {}    // Classic Blinn-Phong
class UnlitMaterial extends Material {}    // Flat shading
class WireframeMaterial extends Material {} // Technical viz
class GradientMaterial extends Material {}  // Color transitions
class HeatmapMaterial extends Material {}   // Data-driven colors
```

### 5. Renderer Backend Abstraction

Same scene, multiple targets:

```dart
abstract class RendererBackend {
  Future<dynamic> build(Scene3D scene);
}

class GLTFBackend extends RendererBackend {}    // Export GLB
class FlutterBackend extends RendererBackend {} // flutter_3d_controller
class ThreeJSBackend extends RendererBackend {} // Three.js (future)
class FilamentBackend extends RendererBackend {} // Filament (future)
class WebGPUBackend extends RendererBackend {}  // WebGPU (future)
```

### 6. Animation System

Full animation framework:

```dart
class AnimationClip {
  String name;
  List<AnimationTrack> tracks;
  double duration;
  bool loop;
}

class AnimationTrack<T> {
  String targetPath;
  List<Keyframe<T>> keyframes;
  T getValueAtTime(double time);
}

class AnimationPlayer {
  void play();
  void pause();
  void seek(double time);
  void update(double deltaTime);
}
```

### 7. Lighting System

Multiple light types:

```dart
class AmbientLight extends Light {}       // Uniform illumination
class DirectionalLight extends Light {}   // Sun-like parallel rays
class PointLight extends Light {}         // Omnidirectional point source
class SpotLight extends Light {}          // Cone-shaped spotlight
class HemisphereLight extends Light {}    // Sky/ground blend
class HDRILight extends Light {}          // Image-based lighting
```

### 8. Interaction System

Pluggable picking implementations:

```dart
abstract class Picker {
  PickResult pick(Ray ray, World world);
}

class NullPicker extends Picker {}       // No picking support
class LegendPicker extends Picker {}     // Metadata-based (current)
class RaycastPicker extends Picker {}    // Ray-triangle intersection (future)

class SelectionManager {
  void select(EntityId id);
  void deselect(EntityId id);
  void setHovered(EntityId? id);
}
```

### 9. Layout Engines

Multiple layout algorithms:

```dart
abstract class LayoutEngine {
  List<(Vec3, Map<String, dynamic>)> computeLayout(
    List<Map<String, dynamic>> data,
    LayoutContext context,
  );
}

class CartesianLayout extends LayoutEngine {}  // Bar charts, scatter
class PolarLayout extends LayoutEngine {}      // Pie, radar
class GeoLayout extends LayoutEngine {}        // Map visualizations
class TreeLayout extends LayoutEngine {}       // Hierarchical data
class ForceLayout extends LayoutEngine {}      // Network graphs
class SurfaceLayout extends LayoutEngine {}    // 3D surfaces
class HexLayout extends LayoutEngine {}        // Hexagonal grids
```

## Use Cases

### Current
- Bar charts (cuboid meshes)
- Pie/donut charts (pie slice meshes)
- Line charts (tube segments)
- Scatter plots (spheres)
- Geo charts (radial pins on sphere)

### Future (enabled by this architecture)
- Surface charts
- Volume charts
- Network graphs (force-directed layout)
- Sankey 3D
- Terrain visualization
- Digital twins
- BIM/CAD viewers
- Scientific visualization
- Millions of points (via instancing)

## Migration Path

### From v0.x to v1.0

1. **Existing code continues to work** - `Scene3D`, `Node3D`, `MeshBuilder` remain
2. **Gradual adoption** of new systems:
   - Start using `GeometryCache` for shared primitives
   - Adopt `ChartCompiler` pattern for new chart types
   - Use `LayoutEngine` for automatic positioning
   - Leverage `Material` hierarchy for advanced materials

3. **Future enhancements** without breaking changes:
   - Add GPU instancing support
   - Implement proper raycasting picker
   - Add more renderer backends
   - Extend animation system

## Benefits

1. **Testability**: Compiler passes are isolated and testable
2. **Reusability**: Shared geometry cache reduces memory
3. **Extensibility**: ECS allows adding features without modifying core classes
4. **Performance**: Optimization passes improve rendering efficiency
5. **Flexibility**: Backend independence enables multiple render targets
6. **Maintainability**: Clear separation of concerns

## Example Usage

```dart
// Using the compiler pipeline
final compiler = BarChartCompiler();
final context = CompileContext(
  theme: Theme3D(),
  geometryCache: GeometryCache(),
  renderSettings: RenderSettings(enableAnimations: true),
);

final scene = compiler.compile(chartConfig, context);

// Using different backends
final gltfBackend = GLTFBackend();
final glbBytes = await gltfBackend.build(scene);

final flutterBackend = FlutterBackend();
final viewerConfig = await flutterBackend.build(scene);

// Using animation
final player = AnimationPlayer(
  autoPlay: true,
  onUpdate: (time) => print('Animating at $time'),
);
player.setClip(myAnimationClip);

// Using layout engine
final layout = CartesianLayout(orientation: AxisOrientation.yUp);
final positions = layout.computeLayout(data, LayoutContext());
```
