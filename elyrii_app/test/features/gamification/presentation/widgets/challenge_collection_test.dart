import 'dart:async';

import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/network/api_exception.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/features/gamification/data/models/gamification_models.dart';
import 'package:elyrii_app/features/gamification/data/repositories/gamification_repository.dart';
import 'package:elyrii_app/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:elyrii_app/features/gamification/presentation/widgets/challenge_collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ChallengeTemplate _idea(String id, String title, {String source = 'SYSTEM'}) =>
    ChallengeTemplate(
      id: id,
      title: title,
      description: 'Un petit geste pour toi.',
      source: source,
      rewardPoints: 0,
      aggregator: 'ALL',
      createdAt: DateTime(2026, 10, 23),
      updatedAt: DateTime(2026, 10, 23),
    );

UserChallenge _assignment(
  String id,
  ChallengeTemplate template,
  String status, {
  Object? progress,
}) => UserChallenge(
  id: id,
  userId: 'alice',
  challengeId: template.id,
  status: status,
  progress: progress,
  createdAt: DateTime(2026, 10, 23),
  updatedAt: DateTime(2026, 10, 23),
  template: template,
);

class _Repository extends GamificationRepository {
  _Repository() : super(client: ApiClient(storage: SecureStorageService()));
  List<ChallengeTemplate> available = [];
  List<UserChallenge> active = [];
  List<UserChallenge> proposals = [];
  final commands = <String>[];
  bool loadError = false;
  bool startError = false;
  Completer<void>? loadGate;
  Completer<void>? startGate;

  @override
  Future<List<UserChallenge>> getCompletedChallenges() async {
    await loadGate?.future;
    if (loadError) {
      throw const ApiException(statusCode: 503, message: 'Défis indisponibles');
    }
    return [];
  }

  @override
  Future<List<UserChallenge>> getActiveChallenges() async => active;
  @override
  Future<List<UserChallenge>> getProposals() async => proposals;
  @override
  Future<List<ChallengeTemplate>> getAvailableChallenges() async => available;

  @override
  Future<UserChallenge> startChallenge(String challengeId) async {
    commands.add('start:$challengeId');
    await startGate?.future;
    if (startError) {
      throw const ApiException(statusCode: 503, message: 'Défi non enregistré');
    }
    final template = available.firstWhere((idea) => idea.id == challengeId);
    available = available.where((idea) => idea.id != challengeId).toList();
    final started = _assignment('active-$challengeId', template, 'ACTIVE');
    active = [...active, started];
    return started;
  }

  @override
  Future<UserChallenge> acceptChallenge(String challengeId) async {
    commands.add('accept:$challengeId');
    final proposal = proposals.firstWhere((idea) => idea.id == challengeId);
    proposals = proposals.where((idea) => idea.id != challengeId).toList();
    final accepted = _assignment(proposal.id, proposal.template!, 'ACTIVE');
    active = [...active, accepted];
    return accepted;
  }

  @override
  Future<UserChallenge> rejectChallenge(String challengeId) async {
    commands.add('reject:$challengeId');
    final proposal = proposals.firstWhere((idea) => idea.id == challengeId);
    proposals = proposals.where((idea) => idea.id != challengeId).toList();
    return _assignment(proposal.id, proposal.template!, 'REJECTED');
  }
}

void main() {
  late _Repository repository;
  late GamificationProvider provider;

  setUp(() {
    repository = _Repository();
    provider = GamificationProvider(repository: repository)
      ..onUserChanged(userId: 'alice');
  });

  tearDown(() => provider.dispose());

  Future<void> open(WidgetTester tester, {bool settle = true}) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ChallengeCollection(provider: provider),
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await Scrollable.ensureVisible(tester.element(target), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows server progress and starts, accepts or refuses challenges',
    (tester) async {
      repository.active = [
        _assignment(
          'active-walk',
          _idea('walk', 'Marcher à mon rythme'),
          'ACTIVE',
          progress: {
            'walk': {'current': 2, 'target': 7},
          },
        ),
      ];
      repository.available = [_idea('journal', 'Un moment pour écrire')];
      repository.proposals = [
        _assignment(
          'proposal-calm',
          _idea('calm', 'Une pause douce', source: 'AI'),
          'PENDING',
        ),
        _assignment(
          'proposal-music',
          _idea('music', 'Une chanson pour moi', source: 'AI'),
          'PENDING',
        ),
      ];
      await open(tester);
      expect(find.text('Marcher à mon rythme'), findsOneWidget);
      expect(find.text('2 / 7'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(2 / 7, .0001),
      );
      await tap(tester, find.text('Commencer'));
      expect(repository.commands, ['start:journal']);
      expect(provider.availableChallenges, isEmpty);
      expect(provider.activeChallenges.map((item) => item.challengeId), [
        'walk',
        'journal',
      ]);
      await tap(tester, find.text('Accepter').first);
      expect(provider.activeChallenges.map((item) => item.challengeId), [
        'walk',
        'journal',
        'calm',
      ]);
      await tap(tester, find.text('Refuser'));
      expect(repository.commands, [
        'start:journal',
        'accept:proposal-calm',
        'reject:proposal-music',
      ]);
      expect(provider.proposals, isEmpty);
      expect(provider.completedChallenges, isEmpty);
      expect(find.text('Une chanson pour moi'), findsNothing);
      expect(find.text('2 / 7'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('loads itself and retries a server failure without fake lists', (
    tester,
  ) async {
    repository.loadGate = Completer<void>();
    repository.loadError = true;
    await open(tester, settle: false);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Commencer'), findsNothing);
    repository.loadGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Défis indisponibles'), findsOneWidget);
    repository.loadError = false;
    repository.available = [_idea('journal', 'Un moment pour écrire')];
    await tap(tester, find.text('Réessayer'));
    expect(find.text('Défis indisponibles'), findsNothing);
    expect(find.text('Un moment pour écrire'), findsOneWidget);
    expect(find.text('Commencer'), findsOneWidget);
    expect(repository.commands, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a failed command preserves confirmed data and can be retried', (
    tester,
  ) async {
    repository.active = [
      _assignment(
        'active-walk',
        _idea('walk', 'Marcher à mon rythme'),
        'ACTIVE',
        progress: {
          'walk': {'current': 2, 'target': 7},
        },
      ),
    ];
    repository.available = [_idea('journal', 'Un moment pour écrire')];
    repository.startError = true;
    await open(tester);
    await tap(tester, find.text('Commencer'));
    expect(find.text('Défi non enregistré'), findsOneWidget);
    expect(find.text('Marcher à mon rythme'), findsOneWidget);
    expect(find.text('2 / 7'), findsOneWidget);
    expect(provider.activeChallenges.single.challengeId, 'walk');
    expect(provider.availableChallenges, hasLength(1));
    expect(provider.completedChallenges, isEmpty);
    repository.startError = false;
    await tap(tester, find.text('Réessayer'));
    await tap(tester, find.text('Commencer'));
    expect(repository.commands, ['start:journal', 'start:journal']);
    expect(provider.activeChallenges.map((item) => item.challengeId), [
      'walk',
      'journal',
    ]);
    expect(provider.completedChallenges, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('refresh keeps confirmed challenges readable while waiting', (
    tester,
  ) async {
    repository.active = [
      _assignment(
        'active-walk',
        _idea('walk', 'Marcher à mon rythme'),
        'ACTIVE',
      ),
    ];
    await open(tester);
    repository.loadGate = Completer<void>();
    final refresh = provider.loadAll(force: true);
    await tester.pump();
    expect(find.text('Marcher à mon rythme'), findsOneWidget);
    repository.loadGate!.complete();
    await refresh;
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pending commands disable all realization choices', (
    tester,
  ) async {
    repository.available = [_idea('journal', 'Un moment pour écrire')];
    repository.proposals = [
      _assignment('proposal', _idea('music', 'Une chanson'), 'PENDING'),
    ];
    repository.startGate = Completer<void>();
    await open(tester);
    await Scrollable.ensureVisible(
      tester.element(find.text('Commencer')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Commencer'));
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Commencer'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Refuser'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Accepter'))
          .onPressed,
      isNull,
    );
    expect(repository.commands, ['start:journal']);
    repository.startGate!.complete();
    await tester.pumpAndSettle();
    expect(provider.activeChallenges.single.challengeId, 'journal');
    expect(provider.completedChallenges, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
}
