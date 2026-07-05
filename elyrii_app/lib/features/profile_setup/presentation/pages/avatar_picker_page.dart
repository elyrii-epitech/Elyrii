import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/liquid_glass_kit.dart';
import '../../../../core/constants/avatar_options.dart';

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
        HapticFeedback.lightImpact();
        setState(() {
          _customImagePath = cropped.path;
          _customAvatarUrl = null;
          // Deselectionner les presets
          _selectedId = '__custom__';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Impossible de charger l\'image'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _confirm() {
    HapticFeedback.lightImpact();
    Navigator.pop(context, _resultValue);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.scaffoldDark
          : AppColors.scaffoldLight,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: topPadding + 70)),

              // Aperçu
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
                        HapticFeedback.selectionClick();
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

          // Top bar
          Positioned(
            top: topPadding + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _BackButton(
                  isDark: isDark,
                  onTap: () => Navigator.pop(context, kAvatarPickerCancelled),
                ),
                Expanded(
                  child: Text(
                    'Mon avatar',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 44),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        child: Column(
          children: [
            Container(
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
                    color: isDark
                        ? AppColors.surfaceDark
                        : AppColors.surfaceLight,
                  ),
                  child: ClipOval(
                    child: _customImagePath != null
                        ? Image.file(File(_customImagePath!), fit: BoxFit.cover)
                        : _customAvatarUrl != null
                        ? Image.network(
                            _customAvatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Image.asset(
                              'assets/mascotte.png',
                              fit: BoxFit.cover,
                            ),
                          )
                        : (_resultValue == null
                              ? Image.asset(
                                  'assets/mascotte.png',
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  _resultValue!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Image.asset(
                                    'assets/mascotte.png',
                                    fit: BoxFit.cover,
                                  ),
                                )),
                  ),
                ),
              ),
            ),
          ],
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
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
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
                      errorBuilder: (_, _, _) =>
                          Image.asset('assets/mascotte.png', fit: BoxFit.cover),
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
