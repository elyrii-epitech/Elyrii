import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart'
    show
        CupertinoActivityIndicator,
        CupertinoAlertDialog,
        CupertinoDialogAction,
        showCupertinoDialog;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass/liquid_glass_kit.dart';
import '../../../../core/constants/avatar_options.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../widgets/mascot_avatar_preview.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedId = avatarIdFromPfp(widget.currentPfp);
    // Si l'utilisateur avait une image custom, la conserver pour l'apercu
    if (_selectedId == '__custom__' && widget.currentPfp != null) {
      if (isLocalAvatarPath(widget.currentPfp!)) {
        _customImagePath = localAvatarFilePath(widget.currentPfp!);
      } else {
        _customAvatarUrl = widget.currentPfp;
      }
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
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) {
        setState(() => _isProcessing = false);
        return;
      }

      // Recadrage carre
      final cropped = await ImageCropper().cropImage(
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
      );

      if (cropped != null) {
        ElyriiHaptics.light();
        setState(() {
          _customImagePath = cropped.path;
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
        body: CustomScrollView(
          slivers: [
            // Barre de navigation iOS translucide floutée avec grand confort
            // tactile et titre centré standard (pas de Stack bricolé).
            SliverAppBar(
              pinned: true,
              centerTitle: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: Colors.transparent,
              leadingWidth: 64,
              leading: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: _BackButton(isDark: isDark, onTap: _cancel),
              ),
              title: Text(
                'Mon avatar',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              flexibleSpace: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: ColoredBox(
                    color:
                        (isDark
                                ? AppColors.scaffoldDark
                                : AppColors.scaffoldLight)
                            .withValues(alpha: 0.78),
                  ),
                ),
              ),
            ),

            // Aperçu fidèle (3D avec ombre de contact ou photo)
            SliverToBoxAdapter(child: _buildPreview(isDark)),

            // Import depuis galerie
            SliverToBoxAdapter(child: _buildImportCard(isDark)),

            // Presets
            SliverToBoxAdapter(child: _buildPresetsHeader(isDark)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
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

            // Bouton confirmer
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 100),
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
        padding: const EdgeInsets.only(top: 12, bottom: 24),
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
        padding: const EdgeInsets.all(3),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          ),
          child: ClipOval(
            child: _customImagePath != null
                ? Image.file(File(_customImagePath!), fit: BoxFit.cover)
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
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        )
                      : const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }

  Widget _buildImportCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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

  Widget _buildPresetsHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
      child: Text(
        'Avatars Elyrii'.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: isDark
              ? Colors.white.withValues(alpha: 0.5)
              : Colors.black.withValues(alpha: 0.4),
        ),
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
    return GestureDetector(
      onTap: onTap,
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
                  ? Image.asset('assets/mascotte.png', fit: BoxFit.cover)
                  : Image.network(
                      option.url!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: isDark
                            ? AppColors.surfaceDark
                            : AppColors.surfaceLight,
                        child: Icon(
                          Icons.person_rounded,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
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

// ==================== Back Button ====================

class _BackButton extends StatefulWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _BackButton({required this.isDark, required this.onTap});

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: widget.isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}
