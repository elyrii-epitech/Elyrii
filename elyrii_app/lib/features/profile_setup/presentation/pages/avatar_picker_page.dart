import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/media/avatar_files.dart';
import '../../../../core/diagnostics/app_diagnostics.dart';
import '../../../../core/services/secure_storage_service.dart';

import 'package:provider/provider.dart';

import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';

import '../../../../core/widgets/accessible_action.dart';

import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/avatar_options.dart';
import '../../../../core/widgets/pushed_page.dart';
import '../widgets/profile_controls.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';

/// Avatar selection page opened by tapping the avatar. Choose a mascot/Doux
/// DiceBear preset, or import and crop a personal gallery image. Returns the
/// selection through [Navigator.pop] as a nullable String: null for the default
/// mascot, a DiceBear URL for a preset, or a local image path uploaded on save.
class AvatarPickerPage extends StatefulWidget {
  /// Current avatar, used for preselection.
  final String? currentPfp;

  const AvatarPickerPage({super.key, this.currentPfp});

  @override
  State<AvatarPickerPage> createState() => _AvatarPickerPageState();
}

class _AvatarPickerPageState extends State<AvatarPickerPage> {
  late String _selectedId;
  String? _customImagePath;
  String? _customAvatarUrl;
  bool _isProcessing = false;
  String? _owner;

  @override
  void initState() {
    super.initState();
    _selectedId = avatarIdFromPfp(widget.currentPfp);
    unawaited(
      _restorePhoto().catchError(
        (Object e) => AppDiagnostics.record('avatar_restore_failed', e),
      ),
    );
    // Si l'utilisateur avait une image custom, la conserver pour l'apercu
    if (_selectedId == '__custom__' && widget.currentPfp != null) {
      if (isLocalAvatarPath(widget.currentPfp!)) {
        _customImagePath = localAvatarFilePath(widget.currentPfp!);
      } else {
        _customAvatarUrl = widget.currentPfp;
      }
    }
  }

  Future<void> _restorePhoto() async {
    final storage = context.read<SecureStorageService>();
    _owner = await storage.getUserId();
    if (_owner == null) return;
    await AvatarFiles.recover(_owner!);
    final path = await AvatarFiles.pending(_owner!);
    if (mounted && path != null) {
      setState(() {
        _customImagePath = path;
        _customAvatarUrl = null;
        _selectedId = '__custom__';
      });
    }
  }

  String? get _resultValue {
    if (_customImagePath != null) return _customImagePath;
    if (_customAvatarUrl != null) return _customAvatarUrl;
    if (_selectedId == kMascotAvatarId) return null;
    final option = kAvatarOptions.firstWhere(
      (o) => o.id == _selectedId,
      orElse: () => AvatarOption.mascot,
    );
    return option.url;
  }

  Future<void> _pickAndCropImage() async {
    setState(() => _isProcessing = true);
    try {
      final owner =
          _owner ?? await context.read<SecureStorageService>().getUserId();
      if (owner == null) return;
      await AvatarFiles.begin(owner);
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (!mounted) return;
      if (picked == null) {
        setState(() => _isProcessing = false);
        return;
      }

      // Recadrage carre
      final cropped = (await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 80,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recadrer mon avatar',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: AppColors.primary,
            lockAspectRatio: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
          IOSUiSettings(
            title: 'Recadrer mon avatar',
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
        ],
      ))?.path;

      if (!mounted) return;
      if (cropped != null) {
        if (await context.read<SecureStorageService>().getUserId() != owner) {
          return;
        }
        final ownedPath = await AvatarFiles.adopt(cropped, owner);
        if (!mounted) {
          await AvatarFiles.release(ownedPath);
          return;
        }
        ElyriiHaptics.light();
        setState(() {
          _customImagePath = ownedPath;
          _customAvatarUrl = null;
          // Deselectionner les presets
          _selectedId = '__custom__';
        });
      }
    } catch (e) {
      if (mounted) {
        showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Image indisponible'),
            content: const Text(
              'Impossible de charger l\'image sélectionnée. '
              'Essaie avec une autre photo.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _confirm() {
    ElyriiHaptics.light();
    Navigator.pop(context, _resultValue);
  }

  void _cancel() {
    final path = _customImagePath;
    if (path != null && path != widget.currentPfp) {
      unawaited(AvatarFiles.release(path));
    }
    Navigator.pop(context, kAvatarPickerCancelled);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _cancel();
      },
      child: PushedPage(
        title: 'Mon avatar',
        onBack: _cancel,
        children: [
          Center(
            child: Container(
              width: AppDimensions.profileAvatarPreview,
              height: AppDimensions.profileAvatarPreview,
              padding: const EdgeInsets.all(AppDimensions.spacing12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.profileAvatar(dark),
              ),
              child: UserAvatar(
                pfp: _resultValue,
                size:
                    AppDimensions.profileAvatarPreview -
                    AppDimensions.spacing24,
                showBorder: false,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacing24),
          ProfileGroup(
            children: [
              ProfileRow(
                title: 'Importer une photo',
                icon: Icons.add_a_photo_rounded,
                color: AppColors.pink(dark),
                trailing: _isProcessing
                    ? const CupertinoActivityIndicator()
                    : null,
                onTap: _isProcessing ? null : _pickAndCropImage,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing24),
          Text(
            'Un avatar qui te ressemble',
            style: AppTextStyles.bodySmall(color: context.textTertiary),
          ),
          const SizedBox(height: AppDimensions.spacing16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: AppDimensions.spacing16,
            crossAxisSpacing: AppDimensions.spacing12,
            children: [
              for (final option in kAvatarOptions)
                Center(
                  child: AccessibleAction(
                    label: option.isMascot ? 'Elyrii' : 'Avatar ${option.id}',
                    selected:
                        _customImagePath == null &&
                        _customAvatarUrl == null &&
                        _selectedId == option.id,
                    onPressed: _isProcessing
                        ? null
                        : () {
                            ElyriiHaptics.selection();
                            setState(() {
                              _customImagePath = null;
                              _customAvatarUrl = null;
                              _selectedId = option.id;
                            });
                          },
                    child: Container(
                      width: AppDimensions.profileAvatarTile,
                      height: AppDimensions.profileAvatarTile,
                      padding: const EdgeInsets.all(AppDimensions.spacing8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.profileAvatar(dark),
                        border: Border.all(
                          width: AppDimensions.borderWidthMedium,
                          color:
                              _customImagePath == null &&
                                  _customAvatarUrl == null &&
                                  _selectedId == option.id
                              ? AppColors.primaryText(dark)
                              : Colors.transparent,
                        ),
                      ),
                      child: UserAvatar(
                        pfp: option.url,
                        size:
                            AppDimensions.profileAvatarTile -
                            AppDimensions.spacing16,
                        showBorder: false,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing24),
          ProfileButton(
            label: 'Choisir cet avatar',
            onPressed: _isProcessing ? null : _confirm,
          ),
          const SizedBox(height: AppDimensions.spacing12),
          Text(
            'Tu peux en changer quand tu veux.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall(color: context.textTertiary),
          ),
        ],
      ),
    );
  }
}
