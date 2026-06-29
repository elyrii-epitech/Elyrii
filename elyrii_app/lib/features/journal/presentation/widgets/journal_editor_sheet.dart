import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/liquid_glass_kit.dart';
import 'package:provider/provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../providers/journal_provider.dart';
import 'glass_text_field.dart';

/// Bottom sheet modal pour créer/éditer une entrée du journal
class JournalEditorSheet extends StatefulWidget {
  final JournalProvider provider;
  final JournalEntry? entry;

  /// Prompt d'inspiration optionnel pour pré-remplir le titre.
  final String? initialPrompt;

  const JournalEditorSheet({
    super.key,
    required this.provider,
    this.entry,
    this.initialPrompt,
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
    final entry = widget.entry;
    _titleController = TextEditingController(
      text: entry?.title ?? widget.initialPrompt ?? '',
    );
    _contentController = TextEditingController(text: entry?.content ?? '');

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

  Future<void> _autoSave() async {
    if (!_hasChanges || _contentController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final dashboardProvider = context.read<DashboardProvider>();
    final currentMood = dashboardProvider.selectedMood?.name;

    if (widget.entry != null) {
      await widget.provider.updateEntry(
        widget.entry!.id,
        title: title,
        content: content,
        mood: currentMood,
      );
    } else if (_createdEntryId != null) {
      await widget.provider.updateEntry(
        _createdEntryId!,
        title: title,
        content: content,
        mood: currentMood,
      );
    } else {
      final created = await widget.provider.createEntry(
        title: title,
        content: content,
        mood: currentMood,
      );
      _createdEntryId = created?.id;
    }

    if (!mounted) return;
    setState(() {
      _hasChanges = false;
      _isSaving = false;
    });
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges || _contentController.text.trim().isEmpty) return true;

    final result = await showLiquidGlassDialog<String>(
      context: context,
      title: 'Modifications non sauvegardées',
      child: const Text(
        'Voulez-vous sauvegarder vos modifications avant de fermer ?',
      ),
      actions: [
        LiquidGlassDialogAction(
          label: 'Annuler',
          onPressed: () => Navigator.pop(context, 'cancel'),
        ),
        LiquidGlassDialogAction(
          label: 'Supprimer',
          isDestructive: true,
          onPressed: () => Navigator.pop(context, 'discard'),
        ),
        LiquidGlassDialogAction(
          label: 'Sauvegarder',
          isDefault: true,
          onPressed: () => Navigator.pop(context, 'save'),
        ),
      ],
    );

    if (result == 'save') await _autoSave();
    return result == 'save' || result == 'discard';
  }

  void _deleteEntry() {
    showLiquidGlassDialog(
      context: context,
      title: 'Supprimer cette note ?',
      child: const Text('Cette action est irréversible.'),
      actions: [
        LiquidGlassDialogAction(
          label: 'Annuler',
          onPressed: () => Navigator.pop(context),
        ),
        LiquidGlassDialogAction(
          label: 'Supprimer',
          isDestructive: true,
          onPressed: () {
            final idToDelete = widget.entry?.id ?? _createdEntryId;
            if (idToDelete != null) {
              widget.provider.deleteEntry(idToDelete);
            }
            Navigator.pop(context);
            Navigator.pop(context);
          },
        ),
      ],
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // AppBar
          _buildAppBar(isDark),
          // Contenu
          Padding(
            padding: EdgeInsets.fromLTRB(0, 8, 0, bottomInset + 24),
            child: Column(
              children: [
                // Badge d'inspiration
                if (widget.initialPrompt != null && widget.entry == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.lightbulb_rounded,
                                size: 14,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Inspiration',
                                style: AppTextStyles.labelSmall(
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.1),
                  ),
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
        ],
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
          Expanded(child: _buildStatusIndicator(isDark)),
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
                style: AppTextStyles.labelMedium(color: AppColors.primary),
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
                child: const Icon(
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
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Sauvegarde...',
              style: AppTextStyles.labelMedium(color: AppColors.primary),
              overflow: TextOverflow.ellipsis,
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
            decoration: const BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Modifications non sauvegardées',
              style: AppTextStyles.labelSmall(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 16,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Sauvegardé',
            style: AppTextStyles.labelMedium(color: AppColors.success),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
