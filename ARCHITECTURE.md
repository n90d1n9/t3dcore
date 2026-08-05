# Tenun 3D Core - Architecture Evolution

This document describes the architectural improvements implemented in `tenun_3d_core` to evolve it from a simple chart-to-GLB generator into a general-purpose 3D scene engine.

## Current State (v1)

The original implementation was organized around:
- **MeshBuilder**: Procedural mesh generation
- **Scene3D/Node3D**: Monolithic scene graph
- **GlbWriter**: glTF export
- **CameraSpec**: Simple orbit-based camera presets

This worked well for basic bar and pie charts but would become difficult to maintain as the package scales to support:
- Surface/volume charts
- Network graphs and Sankey diagrams
- Terrain and GIS visualizations
- Digital twins and BIM
- Scientific visualization with millions of points

## New Architecture (v2)

The evolved architecture follows modern rendering engine patterns (Filament, SceneKit, Unity DOTS, VTK):

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

## Key Improvements

### 1. Entity Component System (ECS)

**Before:** `Node3D` with fixed properties (mesh, material, translation, rotation)

**After:** Flexible entity-component architecture

```dart
// Old approach
class Node3D {
  final String name;
  final MeshData mesh;
  final Material3D material;
  final Vec3 translation;
  final List<double>? rotation;
  // ... continuously growing list of properties
}

// New approach
class Entity {
  final EntityId id;
  final Map<Type, Component> _components;
  
  void addComponent<T extends Component>(T component);
  T? getComponent<T extends Component>();
  bool hasComponent<T extends Component>();
}

// Components are modular
class TransformComponent implements Component { ... }
class MeshComponent implements Component { ... }
class MaterialComponent implements Component { ... }
class MetadataComponent implements Component { ... }
class VisibilityComponent implements Component { ... }
class BoundsComponent implements Component { ... }
class AnimationComponent implements Component { ... }
class SelectableComponent implements Component { ... }
```

**Benefits:**
- Extensible without modifying core classes
- Better memory layout for cache efficiency
- Enables system-based processing
- Supports arbitrary entity types beyond just meshes

### 2. Geometry Cache

**Before:** Every rebuild creates new meshes

```dart
// Inefficient: regenerates identical meshes
for (var i = 0; i < data.length; i++) {
  final mesh = MeshBuilder.cuboid(...);
}
```

**After:** Shared geometry cache

```dart
final cache = GeometryCache();
final cubeMesh = cache.cube; // Reused across all instances

for (var i = 0; i < data.length; i++) {
  // Just apply different transforms to the same mesh
}
```

**Benefits:**
- Reduced memory usage
- Faster scene generation
- Enables GPU instancing (future)

### 3. Chart Compiler Pipeline

**Before:** Widgets manually build scenes

```dart
class BarChartWidget {
  Scene3D _buildScene() {
    // Manual scene construction
  }
}
```

**After:** Compiler pipeline with passes

```dart
abstract class ChartCompiler<T> {
  Scene3D compile(T chartConfig, CompileContext context);
}

abstract class CompilerPass {
  void execute(Scene3D scene, CompileContext context);
}

// Modular passes
class LayoutPass extends CompilerPass { ... }
class GeometryPass extends CompilerPass { ... }
class MaterialPass extends CompilerPass { ... }
class AnimationPass extends CompilerPass { ... }
class OptimizationPass extends CompilerPass { ... }
```

**Benefits:**
- Reusable compilation logic
- Testable individual passes
- Optimizable before export
- Easy to add new chart types

### 4. Material System Hierarchy

**Before:** Single `Material3D` class

```dart
class Material3D {
  final List<double> baseColor;
  final double metallic;
  final double roughness;
  final double opacity;
}
```

**After:** Material hierarchy

```dart
abstract class Material {
  Material3D toMaterial3D();
}

class PBRMaterial extends Material { ... }
class PhongMaterial extends Material { ... }
class UnlitMaterial extends Material { ... }
class WireframeMaterial extends Material { ... }
class GradientMaterial extends Material { ... }
class HeatmapMaterial extends Material { ... }
```

**Benefits:**
- Charts don't know material implementation
- Easy to add new material types
- Backend can choose optimal representation

### 5. Renderer Backend Abstraction

**Before:** Tied to `flutter_3d_controller` / model-viewer

```dart
// Only one backend possible
final glb = GlbWriter.build(scene);
controller.loadGlb(glb);
```

**After:** Multiple backend support

```dart
abstract class RendererBackend {
  Future<dynamic> build(Scene3D scene);
}

class GLTFBackend extends RendererBackend { ... }
class FlutterBackend extends RendererBackend { ... }
class ThreeJSBackend extends RendererBackend { ... }
class FilamentBackend extends RendererBackend { ... }
class BabylonBackend extends RendererBackend { ... }
class WebGPUBackend extends RendererBackend { ... }

// Usage
final backend = GLTFBackend();
final result = await backend.build(scene);
```

**Benefits:**
- Same scene targets multiple renderers
- Future-proof architecture
- Backend-specific optimizations possible
- No chart code changes needed when adding backends

### 6. Compile Context

Centralized configuration passed through the compilation pipeline:

```dart
class CompileContext {
  final Theme3D? theme;
  final dynamic geometryCache;
  final RenderSettings renderSettings;
}

class RenderSettings {
  final bool enableAnimations;
  final bool enableShadows;
  final bool lodEnabled;
  final bool instancingEnabled;
  final int maxLOD;
}
```

**Benefits:**
- Consistent configuration across passes
- Easy to add new settings
- Theme support built-in

## Package Structure

```
tenun_3d_core/
│
├── animation/           # Animation clips, timelines, keyframes
├── backend/             # Renderer backend abstraction
│   └── renderer_backend.dart
├── camera/              # Camera systems (existing + enhanced)
├── compiler/            # Chart compilation pipeline
│   └── chart_compiler.dart
├── ecs/                 # Entity Component System
│   └── entity_component_system.dart
├── exporter/            # Multi-format export (GLB, glTF, OBJ, etc.)
├── geometry/            # Mesh builders and cache
│   └── geometry_cache.dart
├── interaction/         # Picking, hit testing, selection
├── layout/              # Layout engines (Cartesian, Polar, Geo, etc.)
├── lighting/            # Light types and systems
├── material/            # Material hierarchy
│   └── material_system.dart
├── math/                # Coordinate systems, transforms
├── optimizer/           # Scene optimization passes
├── renderer/            # High-level render orchestration
├── scene/               # Scene graph (existing)
└── utils/               # Utilities
```

## Migration Path

### Phase 1: Foundation (Current)
- [x] ECS implementation
- [x] Geometry cache
- [x] Compiler pipeline skeleton
- [x] Material system
- [x] Backend abstraction

### Phase 2: Enhancement
- [ ] Implement actual compiler passes
- [ ] Add more geometry primitives
- [ ] Complete material conversions
- [ ] Connect GLTFBackend to GlbWriter

### Phase 3: Advanced Features
- [ ] Animation system (timeline, tracks, keyframes)
- [ ] Lighting system (ambient, directional, point, spot)
- [ ] Label engine (billboard, screen-aligned, leader lines)
- [ ] Axis engine (Cartesian, Polar, Geo, Log, Time)
- [ ] Layout engines (Grid, Polar, Tree, Treemap, Force)
- [ ] Scene optimizer (merge meshes, LOD, instance, sort)

### Phase 4: Multiple Backends
- [ ] Three.js backend
- [ ] Filament backend
- [ ] Babylon.js backend
- [ ] WebGPU backend

### Phase 5: Production Ready
- [ ] Comprehensive tests
- [ ] Performance benchmarks
- [ ] Documentation
- [ ] Example applications

## Benefits Summary

This evolution transforms `tenun_3d_core` from a **chart-to-GLB generator** into a **general-purpose 3D scene engine**:

1. **Scalability**: Handles millions of elements via instancing and LOD
2. **Flexibility**: New chart types are just new compilers
3. **Performance**: Geometry caching and optimization passes
4. **Extensibility**: ECS allows unlimited entity types
5. **Future-proof**: Backend independence enables multiple rendering targets
6. **Maintainability**: Separated concerns, modular design
7. **Testability**: Each component/pass can be tested independently

## Use Cases Enabled

Beyond the current bar/pie charts, this architecture supports:

- **Dashboards**: Multiple coordinated 3D views
- **CAD-like visualizations**: Precise geometry with snapping
- **Scientific plots**: Volume rendering, isosurfaces, vector fields
- **Digital twins**: Real-time data-driven 3D models
- **GIS viewers**: Geographic coordinates, terrain, map overlays
- **Network graphs**: Force-directed layouts in 3D
- **Sankey diagrams**: Flow visualization
- **BIM**: Building information modeling
- **Game-style visualizations**: Interactive 3D experiences

## Conclusion

The current implementation already resembles a miniature rendering engine. This architectural evolution makes that explicit and provides the foundation for `tenun_3d_core` to serve not just Tenun charts, but any 3D data visualization need while allowing different rendering backends to evolve independently.
