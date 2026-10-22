import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_button.dart';
import '../../data/entities/chat_message.dart';

class AiReportSheet extends StatefulWidget {
  final ChatMessage message;
  final String conversationId;
  const AiReportSheet({
    super.key,
    required this.message,
    required this.conversationId,
  });
  @override
  State<AiReportSheet> createState() => _AiReportSheetState();
}

class _AiReportSheetState extends State<AiReportSheet> {
  String _reason = 'DANGEROUS';
  bool _sending = false;
  bool _sent = false;
  String? _error;
  int? _ownerRevision;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ownerRevision ??= context.read<ApiClient>().sessionGeneration;
  }

  static const reasons = {
    'DANGEROUS': 'Conseil dangereux',
    'INACCURATE': 'Information inexacte',
    'OFFENSIVE': 'Contenu offensant',
    'PRIVACY': 'Atteinte à la confidentialité',
    'OTHER': 'Autre problème',
  };
  Future<void> _send() async {
    if (_sending) return;
    final api = context.read<ApiClient>();
    if (api.sessionGeneration != _ownerRevision) {
      setState(
        () => _error = 'La session a changé. Ferme ce formulaire et reviens à la conversation actuelle.',
      );
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final revision = api.sessionGeneration;
    try {
      await api.post(
        '${ApiConfig.baseUrl}/user/ai-reports',
        body: {
          'messageId': widget.message.id,
          'conversationId': widget.conversationId,
          'reason': _reason,
          'content': widget.message.content.length > 16000
              ? widget.message.content.substring(0, 16000)
              : widget.message.content,
        },
      );
      if (mounted && revision == api.sessionGeneration) {
        setState(() => _sent = true);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Le signalement n’a pas pu être envoyé. Réessaie.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Signaler une réponse IA',
              style: AppTextStyles.titleLarge(),
            ),
          ),
          const SizedBox(height: 16),
          if (_sent)
            Semantics(
              liveRegion: true,
              child: const Text(
                'Signalement enregistré pour examen. En cas d’urgence, utilise les ressources d’aide.',
              ),
            )
          else ...[
            const Text(
              'Seule la réponse sélectionnée, son motif et les identifiants nécessaires sont transmis à l’équipe de modération. Cela ne déclenche pas une aide d’urgence.',
            ),
            if (widget.message.content.length > 16000)
              const Text(
                'La réponse est très longue : seuls ses 16 000 premiers caractères seront transmis.',
              ),
            const SizedBox(height: 16),
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (value) {
                if (!_sending && value != null) setState(() => _reason = value);
              },
              child: Column(
                children: [
                  for (final reason in reasons.entries)
                    RadioListTile<String>(
                      title: Text(reason.value),
                      value: reason.key,
                      enabled: !_sending,
                    ),
                ],
              ),
            ),
            if (_error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: AppTextStyles.bodySmall(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            LiquidGlassButton(
              label: 'Envoyer le signalement',
              isLoading: _sending,
              onPressed: _sending ? null : _send,
            ),
          ],
          TextButton(
            onPressed: _sending ? null : () => Navigator.pop(context),
            child: Text(_sent ? 'Fermer' : 'Annuler'),
          ),
        ],
      ),
    ),
  );
}
