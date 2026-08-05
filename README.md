# Tenun 3D Core

3D chart rendering for [`tenun_core`](https://pub.dev/packages/tenun_core).
A `bar3d` chart is registered into Tenun's normal `ChartRegistry` / JSON pipeline exactly like any
other chart type — the only thing that changes is what happens after layout.

```
ChartSpec (JSON)
      │
      ▼
Bar3DChartConfig            (extends tenun_core's BaseChartConfig — see "Extending Tenun")
      │
      ▼
Scene3D                     (lib/src/scene) — nodes: ground plate + one cuboid per data point
      │
      ▼
GlbWriter                   (lib/src/gltf) — hand-rolled glTF 2.0 binary (.glb), no external 3D deps
      │
      ▼
LocalModelServer             (lib/src/hosting) — serves the bytes over loopback HTTP
      │
      ▼
Flutter3DViewer / Flutter3DController   (flutter_3d_controller, backed by <model-viewer>)
```

## What's implemented

- **`bar3d` chart type**, registered via `register3DCharts()` / `bar3dChartRegistration`, using the
  exact "subclass `BaseChartConfig`, tag `ChartType.custom`, override `buildChart()`" pattern from
  tenun_core's own "Extending Tenun (Custom Charts)" guide.
- **Multi-series grouped 3D bars** — each series gets its own row along Z, each category its own
  column along X, so `{"series": [{"data":[...]}, {"data":[...]}]}` renders as a proper grouped 3D
  bar chart, not just a single row.
- **A real glTF/GLB writer** (`GlbWriter`) — positions/normals/indices packed into one binary buffer
  per the GLB container spec (12-byte header + JSON chunk + BIN chunk), each bar exported as its own
  mesh + PBR material (`baseColorFactor`/`metallicFactor`/`roughnessFactor`). No third-party glTF
  package — just `dart:convert` + `dart:typed_data`.
- **Camera presets** (`perspective` / `isometric` / `top`) mapped onto `flutter_3d_controller`'s real
  API — `controller.setCameraOrbit(theta, phi, radius)` — with the radius scaled to the scene's own
  bounding size so the same preset frames a 3-bar chart and a 30-bar chart sensibly.
- **Auto-orbit** via `camera.orbit: true` → `controller.startRotation(rotationSpeed: 12)`.

## Deliberately *not* implemented (and why)

- **In-scene picking/tap-to-select.** The architecture note describes `Tap -> Selection Event`, but
  `flutter_3d_controller` wraps Google's `<model-viewer>` and does not expose raycasting or per-mesh
  hit-testing — the viewer "handles touch events internally" for camera control only. Faking this with
  screen-space math would require reimplementing the viewer's camera projection, which is out of scope
  for a first pass. Instead, `Bar3DChartWidget` renders a row of tappable category chips
  below the viewport (`onCategoryTap`) as an honest, working substitute — see `_CategoryLegend`.
- **Studio/HDRI lighting, per-material textures.** `<model-viewer>` applies its own default environment
  lighting; the package sets material color/roughness/metalness per bar, but doesn't attempt the
  `lighting: { preset: studio }` / custom HDRI knobs from the original note, since that's a `<model-viewer>`
  environment-image feature, not something the Dart-side controller exposes.
- **Pie/line/scatter 3D meshes.** Only the bar → cuboid path is built. Adding a pie (cylinder-segment)
  or scatter (sphere) chart is the same three steps — new `MeshBuilder` method, new `*ChartConfig`,
  new registration — the scene/GLB/hosting layers are already shape-agnostic.

## Platform setup

`flutter_3d_controller` is a transitive dependency, so its install steps apply to any app using this
package:

- **Android**: add `<uses-permission android:name="android.permission.INTERNET"/>` and
  `android:usesCleartextTraffic="true"` — required both by the viewer itself and by this package's
  loopback HTTP server (`http://127.0.0.1:...`, not HTTPS).
- **iOS**: set `io.flutter.embedded_views_preview` to `true` in `Info.plist`.
- **Web**: load `assets/packages/flutter_3d_controller/assets/model_viewer.min.js` in `web/index.html`.

See `flutter_3d_controller`'s own docs for the full details.

## Usage

```dart
import 'package:tenun_core/tenun_core.dart';
import 'package:tenun_3d/tenun_3d.dart';

void main() {
  register3DCharts();
  runApp(const MyApp());
}
```

```dart
TenunChartFromJson(
  jsonConfig: {
    'type': 'bar3d',
    'xAxis': {'data': ['Jan', 'Feb', 'Mar', 'Apr']},
    'series': [
      {'name': 'Revenue', 'data': [120, 180, 260, 320]},
    ],
    'camera': {'preset': 'isometric', 'orbit': true},
    'bar': {'size': 0.6, 'gap': 0.35},
  },
)
```

See `example/lib/main.dart` for a full runnable app.

## Files

```
lib/
  tenun_3d.dart                        barrel + register3DCharts()
  src/
    scene/scene_graph.dart             Vec3, MeshData, Material3D, Node3D, Scene3D
    scene/mesh_builder.dart            cuboid() + groundPlane()
    gltf/glb_writer.dart               Scene3D -> .glb bytes
    camera/camera_preset.dart          preset -> orbit angles
    hosting/local_model_server.dart    loopback HTTP server for generated .glb bytes
    chart/bar_chart_3d_config.dart     Bar3DChartConfig (BaseChartConfig subclass)
    chart/bar_chart_3d_widget.dart     Bar3DChartWidget (the actual pipeline)
example/lib/main.dart                  runnable demo
```
