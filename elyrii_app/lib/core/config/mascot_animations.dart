import 'dart:math';

class MascotAnimation {
  final String id;
  final String assetPath;
  final int durationSeconds;
  final bool loop;
  final int weight;
  final bool playOnOpen;
  final bool playOnInactivity;

  const MascotAnimation({
    required this.id,
    required this.assetPath,
    this.durationSeconds = 3,
    this.loop = false,
    this.weight = 1,
    this.playOnOpen = false,
    this.playOnInactivity = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MascotAnimation &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class MascotAnimations {
  MascotAnimations._();

  static const MascotAnimation idle = MascotAnimation(
    id: 'breath',
    assetPath: 'assets/animations/breath.json',
    loop: true,
  );

  static const MascotAnimation coucou = MascotAnimation(
    id: 'coucou',
    assetPath: 'assets/animations/Coucou.json',
    durationSeconds: 3,
    loop: false,
    weight: 1,
    playOnOpen: true,
    playOnInactivity: true,
  );

  static const List<MascotAnimation> specialAnimations = [coucou];

  static List<MascotAnimation> get openingAnimations =>
      specialAnimations.where((a) => a.playOnOpen).toList();

  static List<MascotAnimation> get inactivityAnimations =>
      specialAnimations.where((a) => a.playOnInactivity).toList();

  static MascotAnimation? selectWeightedRandom(
    List<MascotAnimation> animations,
  ) {
    if (animations.isEmpty) return null;

    final totalWeight = animations.fold<int>(0, (sum, a) => sum + a.weight);
    final random = Random();
    var randomValue = random.nextInt(totalWeight);

    for (final animation in animations) {
      randomValue -= animation.weight;
      if (randomValue < 0) {
        return animation;
      }
    }

    return animations.first;
  }

  static MascotAnimation? getById(String id) {
    if (id == idle.id) return idle;
    try {
      return specialAnimations.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }
}
