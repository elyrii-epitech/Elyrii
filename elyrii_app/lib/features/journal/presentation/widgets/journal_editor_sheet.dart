import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../providers/journal_provider.dart';
import 'glass_text_field.dart';

/// Bottom sheet modal pour créer/éditer une entrée du journal
class JournalEditorSheet extends StatefulWidget {
  final JournalProvider provider;
  final JournalEntry? entry;

  const JournalEditorSheet({
    super.key,
    required this.provider,
    this.entry,
  });

  @override
  State<JournalEditorSheet> createState() => _JournalEditorSheetState();
}

class _JournalEditorSheetState extends State<JournalEditorSheet> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  Timer? _autoSaveTimer;
  bool _hasChanges = false;
  bool _isSaving = false;
  String? _createdEntryId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry?.title ?? '');
    _contentController =
        TextEditingController(text: widget.entry?.content ?? '');

    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), _autoSave);
  }

  void _autoSave() {
    if (!_hasChanges || _contentController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (widget.entry != null) {
      widget.provider.updateEntry(widget.entry!.id, title: title, content: content);
    } else if (_createdEntryId != null) {
      widget.provider.updateEntry(_createdEntryId!, title: title, content: content);
    } else {
      widget.provider.createEntry(title: title, content: content);
      final entries = widget.provider.entries;
      if (entries.isNotEmpty) {
        _createdEntryId = entries.first.id;
      }
    }

    setState(() {
      _hasChanges = false;
      _isSaving = false;
    });
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges || _contentController.text.trim().isEmpty) return true;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => _buildConfirmationDialog(),
    );

    if (result == 'save') _autoSave();
    return result == 'save' || result == 'discard';
  }

  Widget _buildConfirmationDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF2A2A2D) : const Color(0xFFFAFAFA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      title: Text(
        'Modifications non sauvegardées',
        style: TextStyle(
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        ),
      ),
      content: Text(
        'Voulez-vous sauvegarder vos modifications avant de fermer ?',
        style: TextStyle(
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'cancel'),
          child: Text(
            'Annuler',
            style: TextStyle(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'discard'),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Supprimer'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'save'),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          child: const Text('Sauvegarder'),
        ),
      ],
    );
  }

  void _deleteEntry() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : const Color(0xFFE0D4FF).withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Supprimer cette note ?',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Cette action est irréversible.',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : Colors.black.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Annuler',
                                      style: TextStyle(
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    final idToDelete = widget.entry?.id ?? _createdEntryId;
                                    if (idToDelete != null) {
                                      widget.provider.deleteEntry(idToDelete);
                                    }
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Supprimer',
                                      style: TextStyle(
                                        color: AppColors.error,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final canPop = await _onWillPop();
        if (canPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [
                            const Color(0xFF1E1E21),
                            const Color(0xFF171719),
                          ]
                        : [
                            const Color(0xFFF8F8FB),
                            const Color(0xFFE8E8EB),
                          ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : const Color(0xFFE0D4FF).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    // Drag handle
                    _buildDragHandle(isDark),
                    // AppBar
                    _buildAppBar(isDark),
                    // Contenu
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: EdgeInsets.fromLTRB(
                          AppDimensions.pageHorizontalPadding,
                          8,
                          AppDimensions.pageHorizontalPadding,
                          bottomInset + 24,
                        ),
                        child: Column(
                          children: [
                            // Champ titre
                            GlassTextField(
                              controller: _titleController,
                              hint: 'Titre (optionnel)',
                              isDark: isDark,
                              maxLines: 1,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            )
                                .animate()
                                .fadeIn(
                                  duration: 300.ms,
                                  delay: 100.ms,
                                  curve: Curves.easeOutCubic,
                                )
                                .slideY(
                                  begin: 0.1,
                                  duration: 300.ms,
                                  delay: 100.ms,
                                  curve: Curves.easeOutCubic,
                                ),
                            const SizedBox(height: 16),
                            // Champ contenu
                            GlassTextField(
                              controller: _contentController,
                              hint: 'Exprime ce que tu ressens...',
                              isDark: isDark,
                              maxLines: null,
                              minLines: 12,
                              fontSize: 16,
                            )
                                .animate()
                                .fadeIn(
                                  duration: 300.ms,
                                  delay: 200.ms,
                                  curve: Curves.easeOutCubic,
                                )
                                .slideY(
                                  begin: 0.1,
                                  duration: 300.ms,
                                  delay: 200.ms,
                                  curve: Curves.easeOutCubic,
                                ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDragHandle(bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.pageHorizontalPadding,
        0,
        AppDimensions.pageHorizontalPadding,
        16,
      ),
      child: Row(
        children: [
          // Bouton fermer
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              final canPop = await _onWillPop();
              if (canPop && mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.close_rounded,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Status
          Expanded(
            child: _buildStatusIndicator(isDark),
          ),
          // Bouton ajouter/sauvegarder
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (_contentController.text.trim().isNotEmpty) {
                _autoSave();
                Navigator.of(context).pop();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.entry != null ? 'Modifier' : 'Ajouter',
                style: AppTextStyles.labelMedium(
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Menu supprimer (si édition)
          if (widget.entry != null || _createdEntryId != null)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _deleteEntry();
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                  size: 22,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(bool isDark) {
    if (_isSaving) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Sauvegarde...',
            style: AppTextStyles.labelMedium(
              color: AppColors.primary,
            ),
          ),
        ],
      );
    }

    if (_hasChanges) {
      return Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Modifications non sauvegardées',
            style: AppTextStyles.labelSmall(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 16,
        ),
        const SizedBox(width: 6),
        Text(
          'Sauvegardé',
          style: AppTextStyles.labelMedium(
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}
