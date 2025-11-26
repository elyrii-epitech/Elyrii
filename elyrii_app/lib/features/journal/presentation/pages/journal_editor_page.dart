import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../providers/journal_provider.dart';
import '../widgets/glass_text_field.dart';

class JournalEditorPage extends StatefulWidget {
  final JournalProvider provider;
  final JournalEntry? entry;

  const JournalEditorPage({
    super.key,
    required this.provider,
    this.entry,
  });

  @override
  State<JournalEditorPage> createState() => _JournalEditorPageState();
}

class _JournalEditorPageState extends State<JournalEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  Timer? _autoSaveTimer;
  bool _hasChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry?.title ?? '');
    _contentController = TextEditingController(text: widget.entry?.content ?? '');

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
    setState(() => _hasChanges = true);
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), _autoSave);
  }

  void _autoSave() {
    if (!_hasChanges) return;
    if (_contentController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);

    if (widget.entry != null) {
      // Mise à jour
      widget.provider.updateEntry(
        widget.entry!.id,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
      );
    } else {
      // Création
      widget.provider.createEntry(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
      );
    }

    setState(() {
      _hasChanges = false;
      _isSaving = false;
    });
  }

  void _deleteEntry() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette note'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer cette note ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              widget.provider.deleteEntry(widget.entry!.id);
              Navigator.pop(context); // Ferme le dialog
              Navigator.pop(context); // Retourne à la liste
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        if (_hasChanges) {
          _autoSave();
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF171719) : const Color(0xFFE8E8EB),
        body: SafeArea(
          child: Column(
            children: [
              // AppBar personnalisé
              _buildAppBar(isDark),
              const SizedBox(height: 24),
              // Champs de saisie
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.pageHorizontalPadding,
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
                      ),
                      const SizedBox(height: 16),
                      // Champ contenu
                      GlassTextField(
                        controller: _contentController,
                        hint: 'Exprime ce que tu ressens...',
                        isDark: isDark,
                        maxLines: null,
                        minLines: 10,
                        fontSize: 16,
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.pageHorizontalPadding),
      child: Row(
        children: [
          // Bouton retour
          IconButton(
            onPressed: () {
              if (_hasChanges) {
                _autoSave();
              }
              Navigator.pop(context);
            },
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(width: 8),
          // Status
          Expanded(
            child: _isSaving
                ? Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
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
                  )
                : _hasChanges
                    ? Text(
                        'Modifications non sauvegardées',
                        style: AppTextStyles.labelMedium(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      )
                    : Text(
                        'Sauvegardé',
                        style: AppTextStyles.labelMedium(
                          color: AppColors.success,
                        ),
                      ),
          ),
          // Menu
          if (widget.entry != null)
            PopupMenuButton(
              icon: Icon(
                Icons.more_vert_rounded,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  onTap: _deleteEntry,
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                      const SizedBox(width: 8),
                      const Text(
                        'Supprimer',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
