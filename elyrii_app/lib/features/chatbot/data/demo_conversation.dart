import 'dart:math';

/// Local, scripted French conversation for demonstrations only.
class DemoConversation {
  DemoConversation({Random? random}) : _random = random ?? Random();

  final Random _random;
  final Map<String, int> _lastReplies = {};
  bool _offeredExercise = false;

  static const _replies = <String, List<String>>{
    'greeting': [
      'Salut ! Je suis là pour t’écouter. Comment se passe ta journée ?',
      'Bonjour ! Prenons un petit moment pour toi. Comment te sens-tu aujourd’hui ?',
      'Coucou ! Qu’est-ce que tu aimerais partager avec moi aujourd’hui ?',
    ],
    'stress': [
      'Ça semble te mettre beaucoup de pression. On peut avancer un petit pas à la fois. Tu veux essayer un court exercice de respiration ?',
      'Merci de m’en parler. Une échéance peut prendre beaucoup de place dans la tête. Tu aimerais faire une petite pause pour respirer ensemble ?',
      'Je t’écoute. Tu n’as pas besoin de tout régler d’un coup. On commence par un petit exercice de respiration ?',
    ],
    'exercise': [
      'Installe-toi confortablement. Inspire doucement, puis expire lentement, sans forcer. Recommence trois fois à ton rythme. Comment te sens-tu après cette pause ?',
      'Pose les pieds au sol et relâche les épaules. Prends trois respirations tranquilles, à ton rythme. Qu’est-ce que tu remarques maintenant ?',
      'Prenons une courte pause : relâche la mâchoire, inspire doucement et laisse l’air ressortir lentement. Répète si tu en as envie. Comment te sens-tu ?',
    ],
    'sleep': [
      'Les soirées peuvent être difficiles quand les pensées continuent de tourner. Qu’est-ce qui te garde éveillé en ce moment ?',
      'Tu as surtout du mal à t’endormir, ou tu te réveilles pendant la nuit ?',
      'On peut imaginer un petit rituel calme pour ce soir. Qu’est-ce qui t’aide habituellement à ralentir avant de dormir ?',
    ],
    'lonely': [
      'Ça peut être pesant de se sentir seul. Tu veux me raconter à quel moment ce sentiment est le plus présent ?',
      'Merci de me le dire. Y a-t-il quelqu’un avec qui tu aimerais reprendre contact, même avec un petit message ?',
      'Je suis là pour t’écouter. Est-ce plutôt un manque de compagnie, ou le sentiment de ne pas être compris ?',
    ],
    'better': [
      'C’est une bonne nouvelle. Qu’est-ce qui t’a le plus aidé dans cette petite pause ?',
      'Garde ce petit moment pour toi. Tu aimerais noter ce qui t’a fait du bien dans ton journal ?',
      'Un peu de calme, c’est déjà quelque chose. Quel petit pas te ferait du bien pour la suite de ta journée ?',
    ],
    'thanks': [
      'Avec plaisir. Tu peux revenir en parler quand tu en as envie. Prends soin de toi !',
      'Merci à toi d’avoir pris ce moment. On peut continuer à discuter si tu le souhaites.',
      'Je suis là pour t’écouter. Garde un peu de temps pour toi aujourd’hui.',
    ],
    'talk': [
      'Je t’écoute. Qu’est-ce qui te préoccupe le plus aujourd’hui ?',
      'Prends ton temps. Tu peux commencer par ce qui te vient à l’esprit.',
      'Tu peux m’en parler à ton rythme. Qu’est-ce qui s’est passé ?',
    ],
    'fallback': [
      'Tu peux m’en dire un peu plus sur ce que tu ressens ?',
      'Qu’est-ce qui est le plus important pour toi dans ce que tu viens de partager ?',
      'Je t’écoute. Tu préfères en parler ou essayer une petite pause de respiration ?',
    ],
  };

  String reply(String message) {
    final text = normalize(message);
    bool has(String pattern) => RegExp(pattern).hasMatch(text);
    final String intent;
    if (has(r'\b(respir\w*|exercice\w*|pause)\b') ||
        (_offeredExercise &&
            has(r'\b(oui|ok|okay|accord|volontiers|essayons|vas y)\b'))) {
      intent = 'exercise';
    } else if (has(r'\b(mieux|apaise\w*|calme|detendu\w*)\b') &&
        !has(r'\b(pas|jamais)\b')) {
      intent = 'better';
    } else if (has(r'\b(dorm\w*|sommeil|insomni\w*|nuit\w*|endorm\w*)\b')) {
      intent = 'sleep';
    } else if (has(r'\b(seul\w*|solitude|isol\w*)\b')) {
      intent = 'lonely';
    } else if (has(
      r'\b(stress\w*|angoiss\w*|anx\w*|pression|examen\w*|demain|soutenance|presentation|peur|debord\w*)\b',
    )) {
      intent = 'stress';
    } else if (has(r'\b(merci|remerc\w*)\b')) {
      intent = 'thanks';
    } else if (has(r'\b(parler|ecoute\w*|triste|difficile)\b')) {
      intent = 'talk';
    } else if (has(
      r'\b(bonjour|salut|coucou|hello|comment tu te sens|ca va)\b',
    )) {
      intent = 'greeting';
    } else {
      intent = 'fallback';
    }
    final pool = _replies[intent]!;
    final previous = _lastReplies[intent];
    var index = _random.nextInt(pool.length - (previous == null ? 0 : 1));
    if (previous != null && index >= previous) index++;
    _lastReplies[intent] = index;
    _offeredExercise =
        intent == 'stress' || (intent == 'fallback' && index == 2);
    return pool[index];
  }

  /// A brief thinking pause plus length-dependent typing time and jitter.
  Duration delayFor(String reply) => Duration(
    milliseconds: (650 + reply.length * 8 + _random.nextInt(451)).clamp(
      1100,
      2800,
    ),
  );

  void reset() {
    _lastReplies.clear();
    _offeredExercise = false;
  }

  static String normalize(String text) {
    var result = text.toLowerCase();
    const accents = {
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'î': 'i',
      'ï': 'i',
      'ô': 'o',
      'ö': 'o',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
      'œ': 'oe',
    };
    accents.forEach((from, to) => result = result.replaceAll(from, to));
    return result.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }
}
