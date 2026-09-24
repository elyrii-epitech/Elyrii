import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final name in ['mascot', 'mascot_graduate']) {
    test('$name keeps the rig and all clips within the geometry budget', () {
      final bytes = File('assets/optimized/$name.glb').readAsBytesSync();
      final header = ByteData.sublistView(bytes);
      expect(header.getUint32(0, Endian.little), 0x46546c67);
      final jsonLength = header.getUint32(12, Endian.little);
      final data =
          jsonDecode(utf8.decode(bytes.sublist(20, 20 + jsonLength))) as Map;
      final accessors = data['accessors'] as List;
      var triangles = 0;
      for (final mesh in data['meshes'] as List) {
        for (final primitive in mesh['primitives'] as List) {
          triangles += (accessors[primitive['indices']]['count'] as int) ~/ 3;
        }
      }
      expect(triangles, lessThan(75000));
      expect(bytes.length, lessThan(3600000));
      expect(
        (data['animations'] as List).map((a) => a['name']),
        containsAll([
          'idle',
          'greet',
          'attentive',
          'thinking',
          'celebrate',
          'breathe',
          'curious',
          'cozy',
          'acknowledge',
          'reassure',
          'delight',
          'nuzzle',
          'proud',
          'stretch',
          'settle',
          'invite',
        ]),
      );
      expect(data['skins'], hasLength(2));
      if (name == 'mascot_graduate') {
        final nodes = data['nodes'] as List;
        final head = nodes.firstWhere((n) => n['name'] == 'CTRL_head');
        expect(
          (head['children'] as List).map((i) => nodes[i]['name']),
          contains('Accessory_custom1'),
        );
      }
    });
  }
}
