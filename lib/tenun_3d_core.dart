/// Tenun 3D Core - A lightweight 3D rendering engine for data visualization.
///
/// This package provides a complete 3D scene graph, mesh builders, glTF/GLB
/// export, camera abstractions, and chart integration utilities.
library tenun_3d_core;

// Core scene graph
export 'scene/scene_graph.dart';
export 'scene/mesh_builder.dart';

// GLB writer
export 'glb_writer.dart';

// Camera
export 'camera/camera_preset.dart';

// Hosting
export 'hosting/local_model_server.dart';

// Legend
export 'legend/chart_3d_legend.dart';

// Color utilities
export 'utils/color_scale.dart';

// ECS (Entity Component System) - NEW
export 'ecs/entity_component_system.dart';

// Geometry cache - NEW
export 'geometry/geometry_cache.dart';

// Compiler pipeline - NEW
export 'compiler/chart_compiler.dart';

// Material system - NEW
export 'material/material_system.dart';

// Renderer backends - NEW
export 'backend/renderer_backend.dart';
