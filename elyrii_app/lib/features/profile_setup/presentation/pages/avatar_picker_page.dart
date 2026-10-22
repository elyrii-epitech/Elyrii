import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/media/avatar_files.dart';
import '../../../../core/diagnostics/app_diagnostics.dart';
import '../../../../core/services/secure_storage_service.dart';

import 'package:provider/provider.dart';

import 'dart:async';

import 'package:flutter/cupertino.dart'
    show
        CupertinoActivityIndicator,
        CupertinoAlertDialog,
        CupertinoDialogAction,
        showCupertinoDialog;
import 'package:flutter/material.dart';

import '../../../../core/widgets/accessible_action.dart';
import '../../../../core/widgets/elyrii_page_header.dart';

import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/elyrii_back_button.dart';
import '../../../../core/widgets/glass/liquid_glass_kit.dart';
import '../../../../core/constants/avatar_options.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../widgets/mascot_avatar_preview.dart';
import '../../../../core/config/mascot_animations.dart';

/// Page de selection d'avatar proposee au tap sur l'avatar.
///
/// Deux options :
/// 1. Choisir un avatar preset (mascotte ou avatars Doux DiceBear)
/// 2. Importer une image personnelle depuis la galerie, puis la recadrer
///
/// La selection est retournee via [Navigator.pop] sous forme de [String?]:
/// - null => mascotte par defaut
/// - URL DiceBear => avatar preset
/// - chemin local => image importee, uploadee au moment de la sauvegarde
class AvatarPickerPage extends StatefulWidget {
  /// Avatar actuel (pour pre-selectionner)
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
        // Dialogue d'alerte iOS en cas d'échec de sélection/recadrage.
        showCupertinoDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: const Text('Image indisponible'),
            content: const Text(
              'Impossible de charger l\'image sélectionnée. '
              'Essaie avec une autre photo.',
            ),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _cancel();
      },
      child: Scaffold(
        backgroundColor: isDark
            ? AppColors.scaffoldDark
            : AppColors.scaffoldLight,
        body: ElyriiPageFrame.detail(
          title: 'Mon avatar',
          leading: ElyriiBackButton(onPressed: _cancel),
          slivers: [
            SliverToBoxAdapter(child: _buildPreview(isDark)),

            SliverToBoxAdapter(child: _buildImportCard()),

            SliverToBoxAdapter(child: _buildPresetsHeader()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.pageHorizontalPadding,
                AppDimensions.spacing8,
                AppDimensions.pageHorizontalPadding,
                0,
              ),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: AppDimensions.spacing16,
                  crossAxisSpacing: AppDimensions.spacing16,
                  childAspectRatio: 1,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final option = kAvatarOptions[index];
                  final isSelected =
                      _customImagePath == null &&
                      _customAvatarUrl == null &&
                      _selectedId == option.id;
                  return _PresetAvatarTile(
                    option: option,
                    isSelected: isSelected,
                    isDark: isDark,
                    onTap: () {
                      ElyriiHaptics.selection();
                      setState(() {
                        _customImagePath = null;
                        _customAvatarUrl = null;
                        _selectedId = option.id;
                      });
                    },
                  );
                }, childCount: kAvatarOptions.length),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.pageHorizontalPadding,
                  AppDimensions.spacing32,
                  AppDimensions.pageHorizontalPadding,
                  0,
                ),
                child: LiquidGlassButton(
                  label: 'Choisir cet avatar',
                  icon: Icons.check_rounded,
                  isExpanded: true,
                  onPressed: _confirm,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(bool isDark) {
    final isMascot =
        _customImagePath == null &&
        _customAvatarUrl == null &&
        _selectedId == kMascotAvatarId;

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(
          top: AppDimensions.spacing12,
          bottom: AppDimensions.spacing24,
        ),
        child: SizedBox(
          height: 220,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: isMascot
                  ? MascotAvatarPreview(
                      key: const ValueKey('mascot_preview_3d'),
                      width: 200,
                      height: 200,
                      isDark: isDark,
                      animation: MascotAnimations.proud,
                    )
                  : _buildCircularImagePreview(isDark),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircularImagePreview(bool isDark) {
    final imageUrl = _customAvatarUrl ?? _resultValue;

    return Container(
      key: const ValueKey('custom_image_preview'),
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.3),
            AppColors.secondary.withValues(alpha: 0.3),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing2),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          ),
          child: ClipOval(
            child: _customImagePath != null
                ? UserAvatar(
                    pfp: _customImagePath,
                    size: 120,
                    showBorder: false,
                  )
                : (imageUrl != null
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: isDark
                                ? AppColors.surfaceDark
                                : AppColors.surfaceLight,
                            child: Icon(
                              Icons.person_rounded,
                              size: 48,
                              color: context.textSecondary,
                            ),
                          ),
                        )
                      : const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }

  Widget _buildImportCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.pageHorizontalPadding,
        0,
        AppDimensions.pageHorizontalPadding,
        AppDimensions.spacing24,
      ),
      child: LiquidGlassCard(
        padding: EdgeInsets.zero,
        child: LiquidGlassListTile(
          title: _isProcessing ? 'Chargement...' : 'Importer une photo',
          subtitle: 'Choisis une image depuis ta galerie',
          leadingIcon: Icons.photo_library_rounded,
          trailing: _isProcessing
              ? const CupertinoActivityIndicator(radius: 10)
              : null,
          onTap: _isProcessing ? null : _pickAndCropImage,
        ),
      ),
    );
  }

  Widget _buildPresetsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.pageHorizontalPadding,
        0,
        AppDimensions.pageHorizontalPadding,
        AppDimensions.spacing8,
      ),
      child: Text(
        'Avatars Elyrii',
        style: AppTextStyles.overline(color: context.textSecondary),
      ),
    );
  }
}

// ==================== Preset Avatar Tile ====================

class _PresetAvatarTile extends StatelessWidget {
  final AvatarOption option;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _PresetAvatarTile({
    required this.option,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AccessibleAction(
      label: option.isMascot
          ? 'Choisir la mascotte comme avatar'
          : 'Choisir l’avatar ${option.id}',
      onPressed: onTap,
      child: AnimatedScale(
        scale: isSelected ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 3,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            ),
            child: ClipOval(
              child: option.isMascot
                  ? Image.asset('assets/splash_icon.png', fit: BoxFit.cover)
                  : Image.network(
                      option.url!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: isDark
                            ? AppColors.surfaceDark
                            : AppColors.surfaceLight,
                        child: Icon(
                          Icons.person_rounded,
                          color: context.textSecondary,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
