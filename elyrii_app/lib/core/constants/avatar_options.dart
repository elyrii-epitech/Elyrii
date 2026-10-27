/// Available user profile avatars. The Elyrii mascot is the default; other
/// options are soothing DiceBear avatars with soft, warm styles matching the
/// wellness setting. The backend receives a URL stored in `pfp`; the mascot
/// uses null.
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

/// Special marker indicating that the user uses the mascot avatar.
const String kMascotAvatarId = '__mascotte__';

/// Preset avatars offered during onboarding and editing.
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

/// Whether [pfp] selects the mascot: null, empty, or the mascot marker.
bool isMascotAvatar(String? pfp) {
  if (pfp == null || pfp.isEmpty) return true;
  return pfp == kMascotAvatarId;
}

bool isLocalAvatarPath(String pfp) {
  return pfp.startsWith('/') ||
      pfp.startsWith('file://') ||
      pfp.startsWith('data:image/');
}

String localAvatarFilePath(String pfp) {
  if (pfp.startsWith('file://')) {
    return Uri.parse(pfp).toFilePath();
  }
  return pfp;
}

/// Sentinel returned by AvatarPickerPage on cancellation/back navigation.
/// Distinguishes cancellation, which changes nothing, from explicitly selecting
/// the mascot with null pfp.
const String kAvatarPickerCancelled = '__avatar_picker_cancelled__';

/// Finds a preset ID from its URL. Returns [kMascotAvatarId] when no preset
/// matches, including mascot and custom images.
String avatarIdFromPfp(String? pfp) {
  if (isMascotAvatar(pfp)) return kMascotAvatarId;
  // pfp peut etre une URL de preset
  for (final option in kAvatarOptions) {
    if (option.url == pfp) return option.id;
  }
  // Sinon c'est une image custom (path local ou autre URL)
  return '__custom__';
}
