/// Entity Component System (ECS) foundation for tenun_3d_core.
///
/// This replaces the monolithic [Node3D] with a flexible component-based
/// architecture, allowing extensibility without continuously expanding
/// a single class. Charts and compilers work with entities that can have
/// any combination of components.
library;

import '../scene/scene_graph.dart';


/// Marker interface for all ECS components.
abstract class Component {
  const Component();
}

/// Unique identifier for an entity.
class EntityId {
  const EntityId._(this._value);

  final int _value;

  static int _nextId = 0;

  /// Creates a new unique entity ID.
  factory EntityId.newId() {
    return EntityId._(_nextId++);
  }

  /// Creates an entity ID from an existing value (for deserialization).
  factory EntityId.fromValue(int value) {
    return EntityId._(value);
  }

  int get value => _value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntityId && runtimeType == other.runtimeType && _value == other._value;

  @override
  int get hashCode => _value.hashCode;

  @override
  String toString() => 'EntityId($_value)';
}

/// Transform component: position, rotation, scale in local space.
///
/// Uses quaternion rotation for gimbal-lock-free orientation.
/// Quaternion format is [x, y, z, w] matching glTF convention.
class TransformComponent implements Component {
  const TransformComponent({
    this.position = const Vec3.zero,
    this.rotation = const [0, 0, 0, 1],
    this.scale = const Vec3.one,
    this.pivot = Vec3.zero,
  });

  final Vec3 position;
  final List<double> rotation; // quaternion [x, y, z, w]
  final Vec3 scale;
  final Vec3 pivot;

  TransformComponent copyWith({
    Vec3? position,
    List<double>? rotation,
    Vec3? scale,
    Vec3? pivot,
  }) {
    return TransformComponent(
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      pivot: pivot ?? this.pivot,
    );
  }

  /// Returns true if this transform is identity (no transformation).
  bool get isIdentity =>
      position == Vec3.zero &&
      rotation.every((v) => (v - (v == rotation[3] ? 1.0 : 0.0)).abs() < 1e-10) &&
      scale == Vec3.one;
}

/// Mesh reference component.
class MeshComponent implements Component {
  const MeshComponent({required this.mesh});

  final MeshData mesh;

  MeshComponent copyWith({MeshData? mesh}) {
    return MeshComponent(mesh: mesh ?? this.mesh);
  }
}

/// Material reference component.
class MaterialComponent implements Component {
  const MaterialComponent({required this.material});

  final Material3D material;

  MaterialComponent copyWith({Material3D? material}) {
    return MaterialComponent(material: material ?? this.material);
  }
}

/// Metadata component for linking entities to chart data.
class MetadataComponent implements Component {
  const MetadataComponent({
    this.datumId,
    this.seriesId,
    this.category,
    this.value,
    this.customData,
  });

  final String? datumId;
  final String? seriesId;
  final String? category;
  final double? value;
  final Map<String, dynamic>? customData;

  MetadataComponent copyWith({
    String? datumId,
    String? seriesId,
    String? category,
    double? value,
    Map<String, dynamic>? customData,
  }) {
    return MetadataComponent(
      datumId: datumId ?? this.datumId,
      seriesId: seriesId ?? this.seriesId,
      category: category ?? this.category,
      value: value ?? this.value,
      customData: customData ?? this.customData,
    );
  }
}

/// Visibility component for controlling entity visibility.
class VisibilityComponent implements Component {
  const VisibilityComponent({
    this.visible = true,
    this.castShadow = true,
    this.receiveShadow = true,
  });

  final bool visible;
  final bool castShadow;
  final bool receiveShadow;

  VisibilityComponent copyWith({
    bool? visible,
    bool? castShadow,
    bool? receiveShadow,
  }) {
    return VisibilityComponent(
      visible: visible ?? this.visible,
      castShadow: castShadow ?? this.castShadow,
      receiveShadow: receiveShadow ?? this.receiveShadow,
    );
  }
}

/// Bounding box component for spatial queries and frustum culling.
class BoundsComponent implements Component {
  const BoundsComponent({
    required this.min,
    required this.max,
  });

  final Vec3 min;
  final Vec3 max;

  Vec3 get center => Vec3(
        (min.x + max.x) / 2,
        (min.y + max.y) / 2,
        (min.z + max.z) / 2,
      );

  Vec3 get size => Vec3(
        max.x - min.x,
        max.y - min.y,
        max.z - min.z,
      );

  BoundsComponent copyWith({Vec3? min, Vec3? max}) {
    return BoundsComponent(
      min: min ?? this.min,
      max: max ?? this.max,
    );
  }

  /// Tests if a point is inside this bounding box.
  bool containsPoint(Vec3 point) {
    return point.x >= min.x &&
        point.x <= max.x &&
        point.y >= min.y &&
        point.y <= max.y &&
        point.z >= min.z &&
        point.z <= max.z;
  }

  /// Tests if this bounds intersects another.
  bool intersects(BoundsComponent other) {
    return min.x <= other.max.x &&
        max.x >= other.min.x &&
        min.y <= other.max.y &&
        max.y >= other.min.y &&
        min.z <= other.max.z &&
        max.z >= other.min.z;
  }
}

/// Animation component for entities that can be animated.
class AnimationComponent implements Component {
  const AnimationComponent({
    this.animated = true,
    this.animationClip,
    this.weight = 1.0,
  });

  final bool animated;
  final String? animationClip;
  final double weight;

  AnimationComponent copyWith({
    bool? animated,
    String? animationClip,
    double? weight,
  }) {
    return AnimationComponent(
      animated: animated ?? this.animated,
      animationClip: animationClip ?? this.animationClip,
      weight: weight ?? this.weight,
    );
  }
}

/// Selection component for interactive entities.
class SelectableComponent implements Component {
  const SelectableComponent({
    this.selectable = true,
    this.selected = false,
    this.hoverable = true,
    this.hovered = false,
  });

  final bool selectable;
  final bool selected;
  final bool hoverable;
  final bool hovered;

  SelectableComponent copyWith({
    bool? selectable,
    bool? selected,
    bool? hoverable,
    bool? hovered,
  }) {
    return SelectableComponent(
      selectable: selectable ?? this.selectable,
      selected: selected ?? this.selected,
      hoverable: hoverable ?? this.hoverable,
      hovered: hovered ?? this.hovered,
    );
  }
}

/// An entity in the ECS system.
///
/// Entities are lightweight identifiers that derive their behavior
/// and data from attached components.
class Entity {
  Entity({required this.id}) : _components = <Type, Component>{};

  final EntityId id;
  final Map<Type, Component> _components;

  /// Adds or replaces a component on this entity.
  void addComponent<T extends Component>(T component) {
    _components[T] = component;
  }

  /// Removes a component from this entity.
  void removeComponent<T extends Component>() {
    _components.remove(T);
  }

  /// Gets a component of type T, or null if not present.
  T? getComponent<T extends Component>() {
    return _components[T] as T?;
  }

  /// Checks if this entity has a component of type T.
  bool hasComponent<T extends Component>() {
    return _components.containsKey(T);
  }

  /// Gets all components attached to this entity.
  Iterable<Component> get components => _components.values;

  /// Gets all component types attached to this entity.
  Iterable<Type> get componentTypes => _components.keys;
}

/// The ECS world that manages all entities.
class World {
  World() : _entities = <EntityId, Entity>{};

  final Map<EntityId, Entity> _entities;
  int _entityCount = 0;

  /// Creates a new entity in this world.
  Entity createEntity() {
    final entity = Entity(id: EntityId.newId());
    _entities[entity.id] = entity;
    _entityCount++;
    return entity;
  }

  /// Destroys an entity and removes it from the world.
  void destroyEntity(EntityId id) {
    _entities.remove(id);
    _entityCount--;
  }

  /// Gets an entity by ID, or null if not found.
  Entity? getEntity(EntityId id) {
    return _entities[id];
  }

  /// Gets all entities in this world.
  Iterable<Entity> get entities => _entities.values;

  /// Gets the number of entities in this world.
  int get entityCount => _entityCount;

  /// Queries entities that have all specified component types.
  Iterable<Entity> query<T extends Component>() {
    return _entities.values.where((e) => e.hasComponent<T>());
  }

  /// Queries entities that have all specified component types (multi-component query).
  Iterable<Entity> queryAll<T1 extends Component, T2 extends Component>() {
    return _entities.values.where((e) => e.hasComponent<T1>() && e.hasComponent<T2>());
  }

  /// Queries entities that have all specified component types (three-component query).
  Iterable<Entity> queryAll3<T1 extends Component, T2 extends Component, T3 extends Component>() {
    return _entities.values.where((e) =>
        e.hasComponent<T1>() && e.hasComponent<T2>() && e.hasComponent<T3>());
  }

  /// Clears all entities from the world.
  void clear() {
    _entities.clear();
    _entityCount = 0;
  }
}
