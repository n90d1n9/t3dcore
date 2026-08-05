# Tenun 3D Core

**A lightweight 3D rendering engine for data visualization.**

Tenun 3D Core has evolved from a simple chart-to-GLB generator into a general-purpose 3D scene engine with:

- **Entity Component System (ECS)** - Flexible, extensible scene graph
- **Geometry Cache** - Reusable mesh primitives for performance
- **Compiler Pipeline** - Modular chart compilation with passes
- **Material System** - PBR, Phong, Unlit, Wireframe, Gradient, Heatmap materials
- **Renderer Backend Abstraction** - Target multiple rendering technologies
- **Scene Graph** - Complete 3D scene representation
- **glTF/GLB Export** - Hand-rolled writer, no external dependencies
- **Camera System** - Orbit-based presets (perspective, isometric, top)

## Architecture

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
     Optimization Pass
            ▼
      Renderer Backend
      ├── GLTF Export
      ├── Flutter3DController
      └── Future: ThreeJS, Filament, Babylon, WebGPU
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed documentation.

## Current Implementation (v1)

The original implementation focused on bar charts and is still fully functional:

```
ChartSpec (JSON)
      │
      ▼
Bar3DChartConfig
      │
      ▼
Scene3D                     (lib/scene/)
      │
      ▼
GlbWriter                   (lib/glb_writer.dart)
      │
      ▼
LocalModelServer            (lib/hosting/)
      │
      ▼
Flutter3DViewer             (flutter_3d_controller)
```

### What's Implemented

- **`bar3d` chart type** with multi-series grouped 3D bars
- **glTF/GLB writer** - positions/normals/indices packed per GLB spec
- **Camera presets** - perspective / isometric / top
- **Auto-orbit** camera rotation
- **Legend integration** - tappable category chips for selection

### New in v2 (Foundation)

- **ECS** - Entity-component architecture replacing monolithic Node3D
- **Geometry Cache** - Shared mesh primitives (cube, sphere, cylinder, plane)
- **Compiler Pipeline** - ChartCompiler, CompilerPass, CompileContext
- **Material System** - Material hierarchy with PBR, Phong, Unlit, etc.
- **Backend Abstraction** - RendererBackend interface for multiple targets

## Usage

### Basic (v1 API - Still Supported)

```dart
import 'package:tenun_core/tenun_core.dart';
import 'package:tenun_3d_core/tenun_3d_core.dart';

void main() {
  register3DCharts();
  runApp(const MyApp());
}

TenunChartFromJson(
  jsonConfig: {
    'type': 'bar3d',
    'xAxis': {'data': ['Jan', 'Feb', 'Mar', 'Apr']},
    'series': [
      {'name': 'Revenue', 'data': [120, 180, 260, 320]},
    ],
    'camera': {'preset': 'isometric', 'orbit': true},
  },
)
```

### Advanced (v2 API - New)

```dart
import 'package:tenun_3d_core/tenun_3d_core.dart';

// Create ECS world and entities
final world = World();
final entity = world.createEntity();

// Add components
entity.addComponent(TransformComponent(
  position: Vec3(0, 0, 0),
  scale: Vec3(1, 2, 1),
));

entity.addComponent(MeshComponent(
  mesh: sharedGeometryCache.cube,
));

entity.addComponent(MaterialComponent(
  material: PBRMaterial(
    baseColor: [1, 0, 0, 1],
    metallic: 0.5,
    roughness: 0.5,
  ),
));

// Use compiler pipeline
final context = CompileContext(
  geometryCache: sharedGeometryCache,
  renderSettings: RenderSettings(
    enableAnimations: true,
    instancingEnabled: false,
  ),
);

// Export via backend
final backend = GLTFBackend();
final glbBytes = await backend.build(scene);
```

## Package Structure

```
lib/
├── animation/           # (Future) Animation system
├── backend/             # Renderer backend abstraction
│   └── renderer_backend.dart
├── camera/              # Camera presets
│   └── camera_preset.dart
├── compiler/            # Chart compilation pipeline
│   └── chart_compiler.dart
├── ecs/                 # Entity Component System
│   └── entity_component_system.dart
├── exporter/            # (Future) Multi-format export
├── geometry/            # Geometry cache
│   └── geometry_cache.dart
├── gltf/                # glTF writer
│   └── glb_writer.dart
├── hosting/             # Local model server
│   └── local_model_server.dart
├── interaction/         # (Future) Picking, selection
├── layout/              # (Future) Layout engines
├── legend/              # Chart legend
│   └── chart_3d_legend.dart
├── lighting/            # (Future) Lighting system
├── material/            # Material system
│   └── material_system.dart
├── math/                # (Future) Coordinate systems
├── optimizer/           # (Future) Scene optimization
├── renderer/            # (Future) Render orchestration
├── scene/               # Core scene graph
│   ├── scene_graph.dart
│   └── mesh_builder.dart
└── utils/               # Utilities
    └── color_scale.dart
```

## Platform Setup

`flutter_3d_controller` is a transitive dependency:

- **Android**: Add `<uses-permission android:name="android.permission.INTERNET"/>` and `android:usesCleartextTraffic="true"`
- **iOS**: Set `io.flutter.embedded_views_preview` to `true` in `Info.plist`
- **Web**: Load `assets/packages/flutter_3d_controller/assets/model_viewer.min.js` in `web/index.html`

## Migration Path

| Phase | Status | Focus |
|-------|--------|-------|
| 1. Foundation | ✅ Complete | ECS, Geometry Cache, Compiler, Materials, Backends |
| 2. Enhancement | 🔄 Next | Implement passes, connect backends |
| 3. Advanced Features | ⏳ Planned | Animation, Lighting, Labels, Layout Engines |
| 4. Multiple Backends | ⏳ Planned | ThreeJS, Filament, Babylon, WebGPU |
| 5. Production Ready | ⏳ Planned | Tests, Benchmarks, Documentation |

## Benefits

This evolution transforms `tenun_3d_core` from a **chart-to-GLB generator** into a **general-purpose 3D scene engine**:

1. **Scalability** - Handles millions of elements via instancing and LOD
2. **Flexibility** - New chart types are just new compilers
3. **Performance** - Geometry caching and optimization passes
4. **Extensibility** - ECS allows unlimited entity types
5. **Future-proof** - Backend independence enables multiple rendering targets
6. **Maintainability** - Separated concerns, modular design
7. **Testability** - Each component/pass can be tested independently

## Use Cases Enabled

Beyond bar/pie charts, this architecture supports:

- Dashboards with multiple coordinated 3D views
- CAD-like visualizations with precise geometry
- Scientific plots (volume rendering, isosurfaces)
- Digital twins with real-time data
- GIS viewers with geographic coordinates
- Network graphs with force-directed layouts
- Sankey diagrams for flow visualization
- BIM (Building Information Modeling)
- Game-style interactive 3D experiences

## License

See [LICENSE](LICENSE) file.
