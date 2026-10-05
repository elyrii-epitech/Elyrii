/// Options d'avatar disponibles pour le profil utilisateur.
///
/// La mascotte Elyrii est l'avatar par defaut. Les autres options sont
/// des avatars apaisants generes via DiceBear, bases sur des styles doux
/// et chaleureux coherents avec l'univers bien-etre.
///
/// La valeur envoyee au backend est une URL stockee dans `pfp`.
/// Pour la mascotte, `pfp` vaut null.
class AvatarOption {
  final String id;
  final String? url;
  final bool isMascot;

  const AvatarOption({required this.id, this.url, this.isMascot = false});

  static const AvatarOption mascot = AvatarOption(
    id: '__mascotte__',
    isMascot: true,
  );
}

/// Marqueur special indiquant que l'utilisateur utilise la mascotte.
const String kMascotAvatarId = '__mascotte__';

/// Liste des avatars presets proposés lors de l'onboarding et l'edition.
const List<AvatarOption> kAvatarOptions = [
  AvatarOption.mascot,
  AvatarOption(
    id: 'calmlotus',
    url: 'https://api.dicebear.com/9.x/thumbs/png?seed=calmlotus&radius=50',
  ),
  AvatarOption(
    id: 'softbreeze',
    url: 'https://api.dicebear.com/9.x/thumbs/png?seed=softbreeze&radius=50',
  ),
  AvatarOption(
    id: 'gentlesun',
    url: 'https://api.dicebear.com/9.x/thumbs/png?seed=gentlesun&radius=50',
  ),
  AvatarOption(
    id: 'peacedove',
    url: 'https://api.dicebear.com/9.x/thumbs/png?seed=peacedove&radius=50',
  ),
  AvatarOption(
    id: 'warmharbor',
    url: 'https://api.dicebear.com/9.x/thumbs/png?seed=warmharbor&radius=50',
  ),
  AvatarOption(
    id: 'quietsky',
    url: 'https://api.dicebear.com/9.x/thumbs/png?seed=quietsky&radius=50',
  ),
  AvatarOption(
    id: 'kindfern',
    url: 'https://api.dicebear.com/9.x/thumbs/png?seed=kindfern&radius=50',
  ),
  AvatarOption(
    id: 'mellowbloom',
    url: 'https://api.dicebear.com/9.x/thumbs/png?seed=mellowbloom&radius=50',
  ),
];

/// Indique si la valeur [pfp] correspond a la mascotte (null, vide ou marqueur).
bool isMascotAvatar(String? pfp) {
  if (pfp == null || pfp.isEmpty) return true;
  return pfp == kMascotAvatarId;
}

bool isLocalAvatarPath(String pfp) {
  return pfp.startsWith('/') || pfp.startsWith('file://');
}

String localAvatarFilePath(String pfp) {
  if (pfp.startsWith('file://')) {
    return Uri.parse(pfp).toFilePath();
  }
  return pfp;
}

/// Sentinel retournee par AvatarPickerPage quand l'utilisateur annule (back).
/// Permet au caller de distinguer "annulation" (ne rien changer) de
/// "choix explicite de la mascotte" (pfp = null).
const String kAvatarPickerCancelled = '__avatar_picker_cancelled__';

/// Retrouve l'id d'un preset a partir de son URL. Retourne [kMascotAvatarId]
/// si l'URL ne correspond a aucun preset (donc mascotte ou image custom).
String avatarIdFromPfp(String? pfp) {
  if (isMascotAvatar(pfp)) return kMascotAvatarId;
  // pfp peut etre une URL de preset
  for (final option in kAvatarOptions) {
    if (option.url == pfp) return option.id;
  }
  // Sinon c'est une image custom (path local ou autre URL)
  return '__custom__';
}
