import 'package:flutter/foundation.dart';

enum MascotColorPart { body, details, ears, eyes, accessories }

enum MascotFinish { velours, satin, porcelain }

/// Independent material settings, shared by the studio and every mascot view.
@immutable
class MascotAppearance {
  MascotAppearance({
    Map<String, String> colors = const {},
    this.finish = MascotFinish.velours,
  }) : colors = Map.unmodifiable(colors);
  const MascotAppearance._() : colors = const {}, finish = MascotFinish.velours;
  static const defaults = MascotAppearance._();

  final Map<String, String> colors;
  final MascotFinish finish;

  static String? normalizeHex(String value) {
    final trimmed = value.trim().toUpperCase();
    final hex = trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
    return RegExp(r'^[0-9A-F]{6}$').hasMatch(hex) ? '#$hex' : null;
  }

  String? colorFor(MascotColorPart part) => colors[part.name];

  MascotAppearance withColor(MascotColorPart part, String? hex) {
    final next = Map<String, String>.from(colors);
    if (hex == null) {
      next.remove(part.name);
    } else {
      final normalized = normalizeHex(hex);
      if (normalized == null) return this;
      next[part.name] = normalized;
    }
    return MascotAppearance(colors: Map.unmodifiable(next), finish: finish);
  }

  MascotAppearance withFinish(MascotFinish value) =>
      MascotAppearance(colors: colors, finish: value);

  factory MascotAppearance.fromJson(Map<String, dynamic> json) {
    final colors = <String, String>{};
    final raw = json['colors'];
    if (raw is Map) {
      for (final part in MascotColorPart.values) {
        final value = raw[part.name];
        if (value is String) {
          final hex = normalizeHex(value);
          if (hex != null) colors[part.name] = hex;
        }
      }
    }
    return MascotAppearance(
      colors: Map.unmodifiable(colors),
      finish: MascotFinish.values.firstWhere(
        (value) => value.name == json['finish'],
        orElse: () => MascotFinish.velours,
      ),
    );
  }

  Map<String, dynamic> toJson() => {'colors': colors, 'finish': finish.name};

  @override
  bool operator ==(Object other) =>
      other is MascotAppearance &&
      mapEquals(colors, other.colors) &&
      finish == other.finish;

  @override
  int get hashCode => Object.hash(
    finish,
    Object.hashAll([
      for (final part in MascotColorPart.values) colors[part.name],
    ]),
  );
}
