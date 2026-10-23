import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/mascot_animations.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/localization/app_dates.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../mascot/presentation/providers/mascot_provider.dart';
import '../../domain/journal_feed.dart';
import '../providers/journal_provider.dart';
import 'journal_sheets.dart';

/// The board's writing fields have no box, fill or underline.
InputDecoration _bare(String hint, TextStyle hintStyle) => InputDecoration(
  hintText: hint,
  hintStyle: hintStyle,
  isCollapsed: true,
  filled: false,
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  contentPadding: EdgeInsets.zero,
);

/// The only Journal editor: the Journal, the Accueil and the Coach open it
/// with [showJournalEditor]. It autosaves, keeps an encrypted draft per
/// account and creates each entry once.
class JournalEditorSheet extends StatefulWidget {
  final JournalProvider provider;
  final JournalEntry? entry;

  /// The writing prompt shown above the page of a new entry.
  final String? initialPrompt;
  final MoodType? initialMood;

  const JournalEditorSheet({
    super.key,
    required this.provider,
    this.entry,
    this.initialPrompt,
    this.initialMood,
  });

  @override
  State<JournalEditorSheet> createState() => _JournalEditorSheetState();
}

class _JournalEditorSheetState extends State<JournalEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late String _lastTitle;
  late String _lastContent;
  Timer? _autoSaveTimer;
  Timer? _draftTimer;
  String _clientRequestId = const Uuid().v4();
  bool _hasChanges = false;
  bool _isSaving = false;
  String? _createdEntryId;
  Future<void>? _saveInFlight;
  bool _saveFailed = false;
  int _revision = 0;
  late String? _prompt = widget.initialPrompt;
  MoodType? _mood;
  bool _moodResolved = false;
  String get _draftKey => widget.entry?.id ?? 'new';
  late final String? _draftOwner;
  bool get _sameAccount => widget.provider.owner == _draftOwner;
  bool get _isNew => widget.entry == null;

  Future<void> _persistDraft() async {
    if (!_sameAccount) return;
    try {
      await widget.provider.saveDraft(_draftKey, {
        'title': _titleController.text,
        'content': _contentController.text,
        'entryId': _createdEntryId,
        'clientRequestId': _clientRequestId,
        'mood': _mood?.name,
        'prompt': _prompt,
      });
    } catch (_) {
      if (mounted) setState(() => _saveFailed = true);
    }
  }

  Future<void> _restoreDraft() async {
    try {
      final draft = await widget.provider.readDraft(_draftKey);
      if (!mounted || !_sameAccount || _revision != 0 || draft == null) return;
      final title = draft['title'] as String? ?? '';
      final content = draft['content'] as String? ?? '';
      if (title.isEmpty && content.isEmpty) return;
      _titleController.text = title;
      _contentController.text = content;
      _createdEntryId = draft['entryId'] as String?;
      _clientRequestId =
          draft['clientRequestId'] as String? ?? _clientRequestId;
      _mood = parseJournalMood(draft['mood'] as String?) ?? _mood;
      _prompt = draft['prompt'] as String? ?? _prompt;
      setState(() => _hasChanges = true);
    } catch (_) {
      if (mounted) setState(() => _saveFailed = true);
    }
  }

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _draftOwner = widget.provider.owner;
    _titleController = TextEditingController(text: entry?.title ?? '');
    _contentController = TextEditingController(text: entry?.content ?? '');
    _lastTitle = _titleController.text;
    _lastContent = _contentController.text;
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
    unawaited(_restoreDraft());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_moodResolved) return;
    _moodResolved = true;
    _mood = widget.entry != null
        ? parseJournalMood(widget.entry!.mood)
        : widget.initialMood ??
              context.read<DashboardProvider?>()?.selectedMood;
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _draftTimer?.cancel();
    if (_hasChanges) unawaited(_persistDraft());
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final title = _titleController.text;
    final content = _contentController.text;
    if (title == _lastTitle && content == _lastContent) return;
    _lastTitle = title;
    _lastContent = content;
    _onChanged();
  }

  void _onChanged() {
    _revision++;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 200), _persistDraft);
    if (!_hasChanges) setState(() => _hasChanges = true);
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), _autoSave);
  }

  Future<void> _autoSave() =>
      _saveInFlight ??= _save().whenComplete(() => _saveInFlight = null);

  String get _effectiveTitle {
    final title = _titleController.text.trim();
    if (title.isNotEmpty) return title;
    return _isNew ? (_prompt ?? journalFallbackTitle) : widget.entry!.title;
  }

  Future<void> _save() async {
    if (!_sameAccount ||
        !_hasChanges ||
        _contentController.text.trim().isEmpty) {
      return;
    }
    final revision = _revision;
    bool success;
    setState(() => _isSaving = true);

    final title = _effectiveTitle;
    final content = _contentController.text.trim();
    // An unknown historical mood stays as written until the user picks one.
    final mood = _mood?.name ?? widget.entry?.mood;

    final id = widget.entry?.id ?? _createdEntryId;
    if (id != null) {
      success = await widget.provider.updateEntry(
        id,
        title: title,
        content: content,
        mood: mood,
      );
    } else {
      try {
        await widget.provider.saveDraft(_draftKey, {
          'title': _titleController.text,
          'content': content,
          'clientRequestId': _clientRequestId,
          'mood': _mood?.name,
          'prompt': _prompt,
        });
      } catch (_) {
        if (mounted) {
          setState(() {
            _saveFailed = true;
            _isSaving = false;
          });
        }
        return;
      }
      final created = await widget.provider.createEntry(
        clientRequestId: _clientRequestId,
        title: title,
        content: content,
        mood: mood,
      );
      _createdEntryId = created?.id;
      success = created != null;
      // A retried creation may return the earlier acknowledged snapshot.
      // Subsequent edits must be patched before reporting the draft as saved.
      if (created != null &&
          (created.content != content || created.title != title)) {
        _revision++;
      }
      if (created != null && mounted) {
        // The first save is a small victory the Accueil mascot can play even
        // after the sheet closes.
        context.read<MascotProvider>().react(MascotAnimations.cozy);
      }
    }

    if (!_sameAccount || !mounted) return;
    _draftTimer?.cancel();
    try {
      if (success && revision == _revision) {
        await widget.provider.deleteDraft(_draftKey);
      } else {
        await _persistDraft();
      }
    } catch (_) {
      // A local cleanup failure does not invalidate the server acknowledgement.
    }
    if (!mounted) return;
    setState(() {
      _hasChanges = !success || revision != _revision;
      _saveFailed = !success;
      _isSaving = false;
    });
    if (success && _hasChanges) {
      _autoSaveTimer?.cancel();
      _autoSaveTimer = Timer(const Duration(milliseconds: 500), _autoSave);
    }
  }

  Future<bool> _confirmClose() async {
    if (!_sameAccount ||
        !_hasChanges ||
        _contentController.text.trim().isEmpty) {
      return true;
    }
    final result = await showAppDialog<String>(
      context: context,
      title: 'Modifications non sauvegardées',
      child: const Text(
        'Veux-tu sauvegarder tes modifications avant de fermer ?',
      ),
      actions: [
        AppDialogAction(
          label: 'Annuler',
          onPressed: () => Navigator.pop(context, 'cancel'),
        ),
        AppDialogAction(
          label: 'Abandonner les modifications',
          isDestructive: true,
          onPressed: () => Navigator.pop(context, 'discard'),
        ),
        AppDialogAction(
          label: 'Sauvegarder',
          isDefault: true,
          onPressed: () => Navigator.pop(context, 'save'),
        ),
      ],
    );
    if (result == 'save') await _autoSave();
    if (result == 'discard') {
      _hasChanges = false;
      _draftTimer?.cancel();
      _autoSaveTimer?.cancel();
      await widget.provider.deleteDraft(_draftKey);
    }
    return (result == 'save' && !_hasChanges) || result == 'discard';
  }

  Future<void> _close() async {
    ElyriiHaptics.light();
    if (await _confirmClose() && mounted) Navigator.of(context).pop();
  }

  Future<void> _done() async {
    ElyriiHaptics.light();
    if (_contentController.text.trim().isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    await _autoSave();
    // A save already in flight leaves the newest words for one more pass.
    if (mounted && _hasChanges && !_saveFailed) await _autoSave();
    if (!mounted || _hasChanges) return;
    final navigator = Navigator.of(context);
    if (_createdEntryId != null || widget.entry != null) {
      showJournalToast(
        context,
        _isNew
            ? 'Ton entrée est enregistrée.'
            : 'Tes changements sont enregistrés.',
      );
    }
    navigator.pop();
  }

  Future<void> _pickMood() async {
    final mood = await showJournalMoodPicker(context);
    if (mood == null || !mounted) return;
    setState(() => _mood = mood);
    _onChanged();
  }

  Future<void> _pickPrompt() async {
    final prompt = await showJournalPromptPicker(context);
    if (prompt != null && mounted) setState(() => _prompt = prompt);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final date = AppDates.format(
      (widget.entry?.createdAt ?? DateTime.now()).toLocal(),
      'EEEE d MMMM',
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmClose() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Padding(
        padding: EdgeInsets.only(
          top: media.padding.top + AppDimensions.accueilBarHeight,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxContentWidth,
            ),
            child: Material(
              color: AppColors.sheetSurface(dark),
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppDimensions.radius30),
                ),
                side: dark
                    ? BorderSide.none
                    : const BorderSide(color: AppColors.borderLight),
              ),
              clipBehavior: Clip.antiAlias,
              child: Semantics(
                scopesRoute: true,
                namesRoute: true,
                explicitChildNodes: true,
                label: 'Écrire dans le journal',
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppDimensions.spacing20,
                    AppDimensions.spacing8,
                    AppDimensions.spacing20,
                    media.viewInsets.bottom +
                        media.padding.bottom +
                        AppDimensions.spacing24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: AppDimensions.spacing8,
                    children: [
                      const JournalGrabber(),
                      _head(dark, date),
                      if (_isNew) _promptChip(dark),
                      Expanded(child: _page(dark)),
                      _toolbar(dark),
                      _status(dark),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _head(bool dark, String date) => Row(
    spacing: AppDimensions.spacing4,
    children: [
      IconButton(
        tooltip: 'Fermer l’éditeur',
        onPressed: _close,
        constraints: const BoxConstraints.tightFor(
          width: AppDimensions.journalTool,
          height: AppDimensions.journalTool,
        ),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: dark ? AppColors.cardDark : AppColors.cardLight,
        ),
        icon: Icon(
          Symbols.close_rounded,
          size: AppDimensions.iconSm,
          color: context.textPrimary,
        ),
      ),
      Expanded(
        child: Text(
          '${date[0].toUpperCase()}${date.substring(1)}',
          textAlign: TextAlign.center,
          style: AppTextStyles.editorDate(color: context.textPrimary),
        ),
      ),
      TextButton(
        onPressed: _done,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing4,
          ),
          foregroundColor: AppColors.primaryText(dark),
          textStyle: AppTextStyles.buttonSmall(),
        ),
        child: const Text('Terminé'),
      ),
    ],
  );

  Widget _promptChip(bool dark) => Material(
    color: AppColors.journalPrompt(dark),
    borderRadius: BorderRadius.circular(AppDimensions.radius14),
    child: InkWell(
      onTap: _pickPrompt,
      borderRadius: BorderRadius.circular(AppDimensions.radius14),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing12,
          vertical: AppDimensions.spacing8,
        ),
        child: Row(
          spacing: AppDimensions.spacing8,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Symbols.lightbulb_rounded,
              size: AppDimensions.iconSm,
              color: AppColors.journalAccent(dark),
            ),
            Expanded(
              child: Text(
                _prompt ?? journalFreePrompt,
                style: AppTextStyles.promptChip(
                  color: AppColors.journalAccent(dark),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _page(bool dark) {
    final hint = context.textTertiary;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: 'Titre optionnel',
            child: TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              style: AppTextStyles.titleLarge(color: context.textPrimary),
              cursorColor: AppColors.primaryText(dark),
              decoration: _bare(
                'Titre (optionnel)',
                AppTextStyles.bodyLarge(color: hint),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacing20),
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppDimensions.journalBodyMinHeight,
            ),
            child: Semantics(
              label: 'Ton entrée',
              child: TextField(
                controller: _contentController,
                autofocus: _isNew,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: AppTextStyles.writingBody(color: context.textPrimary),
                cursorColor: AppColors.primaryText(dark),
                decoration: _bare(
                  'Exprime ce que tu ressens…',
                  AppTextStyles.writingBody(color: hint),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar(bool dark) {
    final mood = _mood;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark
            ? AppColors.glassBackgroundDark
            : AppColors.glassBackgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.radius24),
        border: Border.all(
          color: dark ? AppColors.glassBorderDark : AppColors.borderLight,
          width: .5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing8,
          vertical: AppDimensions.spacing4,
        ),
        child: Row(
          children: [
            ActionChip(
              onPressed: _pickMood,
              tooltip: 'Choisir une humeur',
              avatar: mood == null
                  ? Icon(
                      Symbols.sentiment_calm_rounded,
                      size: AppDimensions.iconSm,
                      color: AppColors.primaryText(dark),
                    )
                  : JournalMoodDot(mood),
              label: Text(mood?.label ?? 'Humeur'),
              labelStyle: AppTextStyles.labelMedium(color: context.textPrimary),
              backgroundColor: dark ? AppColors.cardDark : AppColors.cardLight,
              side: BorderSide.none,
              shape: const StadiumBorder(),
            ),
            const Spacer(),
            ValueListenableBuilder(
              valueListenable: _contentController,
              builder: (context, value, _) {
                final words = journalWordCount(value.text);
                return Text(
                  '$words ${words == 1 ? 'mot' : 'mots'}',
                  style: AppTextStyles.labelSmall(color: context.textTertiary),
                );
              },
            ),
            const SizedBox(width: AppDimensions.spacing8),
          ],
        ),
      ),
    );
  }

  Widget _status(bool dark) {
    final warning = widget.provider.storageWarning;
    final saved =
        !_hasChanges && (widget.entry != null || _createdEntryId != null);
    final text =
        warning ??
        (_isSaving
            ? 'Enregistrement…'
            : _hasChanges && _saveFailed
            ? 'Échec de sauvegarde — réessaie'
            : _hasChanges
            ? 'Modifications non sauvegardées'
            : saved
            ? 'Enregistré automatiquement'
            : '');
    return Semantics(
      liveRegion: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: AppDimensions.spacing4,
        children: [
          if (saved && warning == null && !_isSaving)
            Icon(
              Symbols.check_circle_rounded,
              size: AppDimensions.spacing16,
              color: context.textTertiary,
            ),
          Text(
            text,
            style: AppTextStyles.labelSmall(
              color: _saveFailed
                  ? AppColors.errorText(dark)
                  : context.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
