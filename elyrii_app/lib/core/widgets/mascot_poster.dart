import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../diagnostics/app_diagnostics.dart';
import 'mascot_look.dart';

final class MascotPosterFrame {
  const MascotPosterFrame(this.bytes, this.pose);
  final Uint8List bytes;
  final List<List<double>> pose;

  factory MascotPosterFrame.fromJson(Map<String, dynamic> json) {
    final bytes = base64Decode(json['png'] as String);
    if (bytes.length < 24 ||
        bytes[0] != 137 ||
        bytes[1] != 80 ||
        bytes[2] != 78 ||
        bytes[3] != 71) {
      throw const FormatException('Invalid mascot PNG');
    }
    final raw = json['pose'];
    if (raw is! List || raw.isEmpty || raw.length > 64) {
      throw const FormatException('Invalid mascot pose');
    }
    final pose = <List<double>>[];
    for (final channel in raw) {
      if (channel is! List || channel.isEmpty || channel.length > 16) {
        throw const FormatException('Invalid mascot pose channel');
      }
      final values = <double>[];
      for (final value in channel) {
        if (value is! num || !value.isFinite) {
          throw const FormatException('Invalid mascot pose value');
        }
        values.add(value.toDouble());
      }
      pose.add(List.unmodifiable(values));
    }
    return MascotPosterFrame(bytes, List.unmodifiable(pose));
  }

  Map<String, Object> toJson() => {'png': base64Encode(bytes), 'pose': pose};
}

abstract final class MascotPosterStore {
  static const asset = 'assets/optimized/mascot_poster.png';
  static const _preference = 'elyrii_mascot_posters_v1';
  static const _maxEntries = 6;
  static const _maxBytes = 3 * 1024 * 1024;
  static final _frames = <String, MascotPosterFrame>{};
  static SharedPreferences? _preferences;
  static final _purgedScopes = <String>{};
  static Future<void> _writes = Future<void>.value();

  static Future<void> initialize() async {
    if (_preferences != null) return;
    final preferences = await SharedPreferences.getInstance();
    _preferences = preferences;
    try {
      final encoded = preferences.getString(_preference);
      if (encoded == null) return;
      final entries = jsonDecode(encoded) as Map<String, dynamic>;
      for (final entry in entries.entries) {
        final key = jsonDecode(entry.key);
        if (key is! List || key.length != 5 || key[1] is! String) {
          throw const FormatException('Invalid mascot poster key');
        }
        _frames[entry.key] = MascotPosterFrame.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
      _trim();
    } catch (error) {
      _frames.clear();
      AppDiagnostics.record('mascot_poster_cache_invalid', error);
    }
  }

  static String key({
    required String scope,
    required String assetPath,
    required MascotLook look,
    required double aspect,
  }) =>
      jsonEncode(['wardrobe-pose-v1', scope, assetPath, aspect, look.toJson()]);

  static MascotPosterFrame? read(String key) => _frames[key];
  static Iterable<MemoryImage> get images =>
      _frames.values.map((frame) => MemoryImage(frame.bytes));

  static Future<void> save(String key, MascotPosterFrame frame) async {
    if (frame.bytes.length > _maxBytes) return;
    await initialize();
    if (_purgedScopes.contains((jsonDecode(key) as List)[1])) return;
    _frames.remove(key);
    _frames[key] = frame;
    _trim();
    await _persist();
  }

  static Future<void> purgeScope(String scope) async {
    await initialize();
    _purgedScopes.add(scope);
    _frames.removeWhere((key, _) => (jsonDecode(key) as List)[1] == scope);
    await _persist(required: true);
  }

  static Future<void> _persist({bool required = false}) async {
    final encoded = jsonEncode({
      for (final entry in _frames.entries) entry.key: entry.value.toJson(),
    });
    final operation = _writes.then((_) async {
      if (!await _preferences!.setString(_preference, encoded)) {
        throw StateError('Could not persist mascot posters');
      }
    });
    _writes = operation.catchError((Object error) {
      AppDiagnostics.record('mascot_poster_cache_write_failed', error);
    });
    await (required ? operation : _writes);
  }

  static void _trim() {
    var bytes = _frames.values.fold<int>(
      0,
      (sum, frame) => sum + frame.bytes.length,
    );
    while (_frames.length > _maxEntries || bytes > _maxBytes) {
      bytes -= _frames.remove(_frames.keys.first)!.bytes.length;
    }
  }
}

class MascotPoster extends StatelessWidget {
  const MascotPoster({
    super.key,
    required this.width,
    required this.height,
    this.frame,
  });

  final double width;
  final double height;
  final MascotPosterFrame? frame;

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(MascotPosterStore.asset, fit: BoxFit.contain);
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: frame == null
            ? fallback
            : Image.memory(
                frame!.bytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                frameBuilder: (_, child, frame, synchronous) =>
                    synchronous || frame != null ? child : fallback,
              ),
      ),
    );
  }
}
