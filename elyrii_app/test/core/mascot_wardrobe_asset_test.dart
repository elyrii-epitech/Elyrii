import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:elyrii_app/features/mascot/data/models/mascot_accessory.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> readGlb(String path) {
  final bytes = File(path).readAsBytesSync();
  final header = ByteData.sublistView(bytes);
  expect(header.getUint32(0, Endian.little), 0x46546c67);
  expect(header.getUint32(4, Endian.little), 2);
  expect(header.getUint32(8, Endian.little), bytes.length);
  final length = header.getUint32(12, Endian.little);
  return jsonDecode(utf8.decode(bytes.sublist(20, 20 + length)))
      as Map<String, dynamic>;
}

void main() {
  test(
    'all unlockable pieces have hidden defaults and an animated attachment',
    () {
      const path = 'assets/optimized/mascot_wardrobe.glb';
      final document = readGlb(path);
      final base = readGlb('assets/optimized/mascot.glb');
      final nodes = document['nodes'] as List;
      final meshes = document['meshes'] as List;
      final materials = document['materials'] as List;
      final accessors = document['accessors'] as List;
      final variants =
          document['extensions']['KHR_materials_variants']['variants'] as List;
      expect(MascotAccessories.all, hasLength(15));
      expect(variants, hasLength(319));
      expect(
        variants
            .where((variant) => !(variant['name'] as String).contains('+'))
            .map((variant) => variant['name']),
        unorderedEquals(MascotAccessories.all.map((accessory) => accessory.id)),
      );
      expect(document['skins'], hasLength((base['skins'] as List).length));
      expect(
        (document['animations'] as List).map((animation) => animation['name']),
        unorderedEquals(
          (base['animations'] as List).map((animation) => animation['name']),
        ),
      );
      final baseTriangles = (base['meshes'] as List).fold<int>(
        0,
        (sum, mesh) =>
            sum +
            (mesh['primitives'] as List).fold<int>(
              0,
              (sum, primitive) =>
                  sum +
                  (base['accessors'][primitive['indices']]['count'] as int) ~/
                      3,
            ),
      );
      var accessoryTriangles = 0;
      final trianglesByPiece = <String, int>{};
      for (final accessory in MascotAccessories.all) {
        final attachmentIndex = nodes.indexWhere(
          (node) => node['name'] == 'Accessory_${accessory.id}',
        );
        expect(attachmentIndex, greaterThanOrEqualTo(0), reason: accessory.id);
        final attachment = nodes[attachmentIndex];
        final parentName = attachment['extras']['attachment'];
        expect(parentName, isIn(['CTRL_head', 'CTRL_chest']));
        final parent = nodes.firstWhere((node) => node['name'] == parentName);
        expect(parent['children'], contains(attachmentIndex));
        final variantIndex = variants.indexWhere(
          (variant) => variant['name'] == accessory.id,
        );
        var triangles = 0;
        void checkNode(int index) {
          final node = nodes[index];
          if (node.containsKey('mesh')) {
            for (final primitive
                in meshes[node['mesh']]['primitives'] as List) {
              triangles +=
                  (accessors[primitive['indices']]['count'] as int) ~/ 3;
              final hidden = materials[primitive['material']];
              expect(hidden['alphaMode'], 'MASK');
              expect(hidden['pbrMetallicRoughness']['baseColorFactor'][3], 0);
              final mappings =
                  primitive['extensions']['KHR_materials_variants']['mappings']
                      as List;
              expect(mappings, hasLength(1));
              expect(mappings.single['variants'], contains(variantIndex));
              for (final index in mappings.single['variants'] as List) {
                expect(
                  (variants[index]['name'] as String).split('+'),
                  contains(accessory.id),
                );
              }
              expect(mappings.single['material'], isNot(primitive['material']));
            }
          }
          for (final child in node['children'] as List? ?? []) {
            checkNode(child as int);
          }
        }

        checkNode(attachmentIndex);
        expect(triangles, greaterThan(0), reason: accessory.id);
        expect(
          baseTriangles + triangles,
          lessThan(70000),
          reason: accessory.id,
        );
        accessoryTriangles += triangles;
        trianglesByPiece[accessory.id] = triangles;
      }
      for (final variant in variants) {
        final ids = (variant['name'] as String).split('+');
        expect(
          baseTriangles +
              ids.fold<int>(0, (sum, id) => sum + trianglesByPiece[id]!),
          lessThan(70000),
          reason: variant['name'] as String,
        );
        expect(
          ids.map((id) => MascotAccessories.byId(id)!.category).toSet(),
          hasLength(ids.length),
        );
        expect(MascotAccessories.variantFor(ids), variant['name']);
      }
      expect(baseTriangles + accessoryTriangles, lessThan(85000));
      expect(File(path).lengthSync(), lessThan(4000000));
    },
  );
}
