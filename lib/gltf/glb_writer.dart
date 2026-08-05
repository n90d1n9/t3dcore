import 'dart:convert';
import 'dart:typed_data';

import '../scene/scene_graph.dart';

/// Serializes a [Scene3D] into a valid glTF 2.0 binary (`.glb`) blob.
///
/// This is the "Scene Builder -> Mesh Generator -> GLTF Scene" step from
/// the architecture note, made concrete: every [Node3D] becomes one glTF
/// mesh (with its own POSITION/NORMAL/indices accessors and material),
/// packed into a single binary buffer per the GLB container spec
/// (header + JSON chunk + BIN chunk). No external glTF/3D package is
/// used — this only depends on `dart:convert` and `dart:typed_data`.
class GlbWriter {
  static const int _magic = 0x46546C67; // 'glTF'
  static const int _jsonChunkType = 0x4E4F534A; // 'JSON'
  static const int _binChunkType = 0x004E4942; // 'BIN\0'
  static const int _componentTypeFloat = 5126;
  static const int _componentTypeUnsignedInt = 5125;

  /// Builds the `.glb` bytes for [scene]. Every node is exported as an
  /// independent mesh — simplest possible mapping, and more than fast
  /// enough for chart-sized geometry (tens to low hundreds of bars).
  static Uint8List build(Scene3D scene) {
    final binBuilder = BytesBuilder();
    final accessors = <Map<String, dynamic>>[];
    final bufferViews = <Map<String, dynamic>>[];
    final meshes = <Map<String, dynamic>>[];
    final materials = <Map<String, dynamic>>[];
    final nodes = <Map<String, dynamic>>[];
    final materialIndexByMaterial = <Material3D, int>{};
    var byteOffset = 0;

    int pushBufferView(List<int> bytes, {required int target}) {
      // Every bufferView starts 4-byte aligned; glTF requires this for
      // FLOAT/UNSIGNED_INT accessors and it's simplest to always pad.
      final pad = (4 - (byteOffset % 4)) % 4;
      if (pad != 0) {
        binBuilder.add(List<int>.filled(pad, 0));
        byteOffset += pad;
      }
      binBuilder.add(bytes);
      final view = {
        'buffer': 0,
        'byteOffset': byteOffset,
        'byteLength': bytes.length,
        'target': target,
      };
      bufferViews.add(view);
      byteOffset += bytes.length;
      return bufferViews.length - 1;
    }

    int materialIndexFor(Material3D m) {
      return materialIndexByMaterial.putIfAbsent(m, () {
        materials.add({
          'name': m.name ?? 'material_${materials.length}',
          'pbrMetallicRoughness': {
            'baseColorFactor': [
              m.baseColor[0],
              m.baseColor[1],
              m.baseColor[2],
              m.baseColor.length > 3 ? m.baseColor[3] : m.opacity,
            ],
            'metallicFactor': m.metallic,
            'roughnessFactor': m.roughness,
          },
          if (m.opacity < 1.0) 'alphaMode': 'BLEND',
        });
        return materials.length - 1;
      });
    }

    for (final node in scene.nodes) {
      final mesh = node.mesh;

      // POSITION accessor (needs min/max per spec).
      final posBytes = Float32List.fromList(
        mesh.positions.map((v) => v.toDouble()).toList(),
      ).buffer.asUint8List();
      final posViewIdx = pushBufferView(posBytes, target: 34962); // ARRAY_BUFFER
      final mins = [double.infinity, double.infinity, double.infinity];
      final maxs = [double.negativeInfinity, double.negativeInfinity, double.negativeInfinity];
      for (var i = 0; i < mesh.positions.length; i += 3) {
        for (var k = 0; k < 3; k++) {
          final v = mesh.positions[i + k];
          if (v < mins[k]) mins[k] = v;
          if (v > maxs[k]) maxs[k] = v;
        }
      }
      final posAccessorIdx = accessors.length;
      accessors.add({
        'bufferView': posViewIdx,
        'componentType': _componentTypeFloat,
        'count': mesh.vertexCount,
        'type': 'VEC3',
        'min': mins,
        'max': maxs,
      });

      // NORMAL accessor.
      final normBytes = Float32List.fromList(
        mesh.normals.map((v) => v.toDouble()).toList(),
      ).buffer.asUint8List();
      final normViewIdx = pushBufferView(normBytes, target: 34962);
      final normAccessorIdx = accessors.length;
      accessors.add({
        'bufferView': normViewIdx,
        'componentType': _componentTypeFloat,
        'count': mesh.vertexCount,
        'type': 'VEC3',
      });

      // Indices accessor (UNSIGNED_INT — simplest to keep correct for
      // any mesh size without a 65k-vertex ceiling per mesh).
      final idxBytes = Uint32List.fromList(mesh.indices).buffer.asUint8List();
      final idxViewIdx = pushBufferView(idxBytes, target: 34963); // ELEMENT_ARRAY_BUFFER
      final idxAccessorIdx = accessors.length;
      accessors.add({
        'bufferView': idxViewIdx,
        'componentType': _componentTypeUnsignedInt,
        'count': mesh.indices.length,
        'type': 'SCALAR',
      });

      final matIdx = materialIndexFor(node.material);

      final meshIdx = meshes.length;
      meshes.add({
        'name': node.name,
        'primitives': [
          {
            'attributes': {'POSITION': posAccessorIdx, 'NORMAL': normAccessorIdx},
            'indices': idxAccessorIdx,
            'material': matIdx,
          },
        ],
      });

      nodes.add({
        'name': node.name,
        'mesh': meshIdx,
        'translation': [node.translation.x, node.translation.y, node.translation.z],
      });
    }

    final bin = binBuilder.toBytes();

    final gltfJson = <String, dynamic>{
      'asset': {'version': '2.0', 'generator': 'tenun_3d GlbWriter'},
      'scene': 0,
      'scenes': [
        {'name': scene.name, 'nodes': List<int>.generate(nodes.length, (i) => i)},
      ],
      'nodes': nodes,
      'meshes': meshes,
      'accessors': accessors,
      'bufferViews': bufferViews,
      'materials': materials,
      'buffers': [
        {'byteLength': bin.length},
      ],
    };

    return _pack(gltfJson, bin);
  }

  static Uint8List _pack(Map<String, dynamic> gltfJson, Uint8List bin) {
    final jsonBytes = Uint8List.fromList(utf8.encode(jsonEncode(gltfJson)));
    final jsonPad = (4 - (jsonBytes.length % 4)) % 4;
    final paddedJson = Uint8List(jsonBytes.length + jsonPad)
      ..setRange(0, jsonBytes.length, jsonBytes)
      ..fillRange(jsonBytes.length, jsonBytes.length + jsonPad, 0x20); // pad with spaces

    final binPad = (4 - (bin.length % 4)) % 4;
    final paddedBin = Uint8List(bin.length + binPad)
      ..setRange(0, bin.length, bin); // trailing bytes already zero

    final totalLength = 12 + (8 + paddedJson.length) + (8 + paddedBin.length);

    final out = BytesBuilder();

    final header = ByteData(12)
      ..setUint32(0, _magic, Endian.little)
      ..setUint32(4, 2, Endian.little) // glTF version
      ..setUint32(8, totalLength, Endian.little);
    out.add(header.buffer.asUint8List());

    final jsonChunkHeader = ByteData(8)
      ..setUint32(0, paddedJson.length, Endian.little)
      ..setUint32(4, _jsonChunkType, Endian.little);
    out.add(jsonChunkHeader.buffer.asUint8List());
    out.add(paddedJson);

    final binChunkHeader = ByteData(8)
      ..setUint32(0, paddedBin.length, Endian.little)
      ..setUint32(4, _binChunkType, Endian.little);
    out.add(binChunkHeader.buffer.asUint8List());
    out.add(paddedBin);

    return out.toBytes();
  }
}
