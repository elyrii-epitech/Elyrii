import 'dart:async';
import 'dart:convert';

import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/storage/content_cipher.dart';
import 'package:elyrii_app/features/parcours/data/journey_parser.dart';
import 'package:elyrii_app/features/parcours/data/journey_repository.dart';
import 'package:elyrii_app/features/parcours/domain/journey.dart';
import 'package:elyrii_app/features/parcours/presentation/providers/journey_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SecureStorage extends SecureStorageService {
  final values = <String, String>{};

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

class _Preferences implements SharedPreferences {
  final SharedPreferences delegate;
  bool refuseWrites = false;
  bool refuseRemoval = false;
  Completer<void>? nextReload;
  Completer<void>? nextWrite;
  Completer<void>? writeStarted;

  _Preferences(this.delegate);

  @override
  String? getString(String key) => delegate.getString(key);

  @override
  Future<void> reload() async {
    final pending = nextReload;
    nextReload = null;
    if (pending != null) await pending.future;
    await delegate.reload();
  }

  @override
  Future<bool> setString(String key, String value) async {
    final pending = nextWrite;
    nextWrite = null;
    final started = writeStarted;
    if (started != null && !started.isCompleted) started.complete();
    if (pending != null) await pending.future;
    if (refuseWrites) return false;
    return delegate.setString(key, value);
  }

  @override
  Future<bool> remove(String key) async =>
      refuseRemoval ? false : delegate.remove(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedReadRepository extends JourneyRepository {
  Completer<void>? nextRead;
  Completer<void>? readStarted;
  Object? readError;

  _DelayedReadRepository({required super.cipher, required super.preferences});

  @override
  Future<JourneyEnrollment?> load(String owner) async {
    final current = await super.load(owner);
    final gate = nextRead;
    nextRead = null;
    if (gate != null) {
      readStarted!.complete();
      await gate.future;
    }
    if (readError case final error?) throw error;
    return current;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Preferences preferences;
  late ContentCipher cipher;
  late JourneyRepository repository;
  late JourneyProvider provider;
  var clock = DateTime.utc(2026, 10, 23, 9);

  JourneyProvider fresh() {
    final next = JourneyProvider(
      repository: JourneyRepository(
        cipher: cipher,
        preferences: preferences,
        now: () => clock,
      ),
    );
    addTearDown(next.dispose);
    return next;
  }

  Future<void> open(
    JourneyProvider target,
    String owner, {
    bool demo = false,
  }) async {
    target.onUserChanged(userId: owner, isDemo: demo);
    await target.load();
  }

  Future<void> chooseFirst() async {
    expect(
      await provider.choose(provider.catalog.first),
      JourneyCommandResult.changed,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = _Preferences(await SharedPreferences.getInstance());
    cipher = ContentCipher(_SecureStorage());
    clock = DateTime.utc(2026, 10, 23, 9);
    repository = JourneyRepository(
      cipher: cipher,
      preferences: preferences,
      now: () => clock,
    );
    provider = JourneyProvider(repository: repository);
    addTearDown(provider.dispose);
    await open(provider, 'alice');
  });

  test(
    'a first read has no enrollment until an explicit persisted choice',
    () async {
      expect(provider.hasLoadedData, isTrue);
      expect(provider.current, isNull);
      expect(provider.catalog, isNotEmpty);
      final next = fresh();
      await open(next, 'alice');
      expect(next.current, isNull);
      await chooseFirst();
      expect(provider.current!.completedStepCount, 0);
      await next.load(force: true);
      expect(next.current!.enrollmentId, provider.current!.enrollmentId);
      expect(next.current!.completedStepCount, 0);
    },
  );

  test(
    'progress is encrypted, account scoped and restored by a fresh repository',
    () async {
      await chooseFirst();
      final step = provider.current!.currentStep!.stepId;
      expect(await provider.completeStep(step), JourneyCommandResult.changed);
      final saved = preferences.getString('journey_progress_alice')!;
      expect(saved, startsWith('aesgcm1:'));
      expect(saved, isNot(contains(provider.current!.enrollmentId)));
      expect(saved, isNot(contains(provider.current!.path.title)));
      final clear = await cipher.open('alice', saved, purpose: 'journey:v1');
      final document = JourneyDocument.fromJson(
        jsonDecode(clear),
        owner: 'alice',
      );
      expect(document.current!.completedStepCount, 1);
      final next = fresh();
      await open(next, 'alice');
      expect(next.current!.completedStepCount, 1);
      expect(
        next.current!.path.steps.first.instructions,
        provider.current!.path.steps.first.instructions,
      );
      await open(next, 'bob');
      expect(next.current, isNull);
      await expectLater(
        cipher.open('bob', saved, purpose: 'journey:v1'),
        throwsA(anything),
      );
    },
  );

  test(
    'sequential completion is idempotent and paused paths never auto-resume',
    () async {
      await chooseFirst();
      final path = provider.current!.path;
      final id = provider.current!.enrollmentId;
      expect(
        await provider.completeStep(path.steps.last.stepId),
        JourneyCommandResult.failed,
      );
      expect(provider.current!.completedStepCount, 0);
      expect(await provider.pause(), JourneyCommandResult.changed);
      expect(await provider.choose(path), JourneyCommandResult.unchanged);
      expect(provider.current!.status, JourneyStatus.paused);
      expect(
        await provider.completeStep(path.steps.first.stepId),
        JourneyCommandResult.failed,
      );
      expect(await provider.resume(), JourneyCommandResult.changed);
      final first = provider.completeStep(path.steps.first.stepId);
      final duplicate = provider.completeStep(path.steps.first.stepId);
      expect(provider.isWriting, isTrue);
      expect(provider.canWrite, isFalse);
      expect(await first, JourneyCommandResult.changed);
      expect(await duplicate, JourneyCommandResult.unchanged);
      expect(provider.current!.completedStepCount, 1);
      expect(provider.current!.enrollmentId, id);
      expect(provider.canWrite, isTrue);
    },
  );

  test('terminal progress and completion time survive duplicates and same-path choice', () async {
    await chooseFirst();
    final path = provider.current!.path;
    for (final step in path.steps) {
      clock = clock.add(const Duration(minutes: 1));
      expect(
        await provider.completeStep(step.stepId),
        JourneyCommandResult.changed,
      );
    }
    final completedAt = provider.current!.completedAt;
    final revision = provider.current!.revision;
    clock = clock.add(const Duration(days: 1));
    expect(
      await provider.completeStep(path.steps.last.stepId),
      JourneyCommandResult.unchanged,
    );
    expect(await provider.choose(path), JourneyCommandResult.unchanged);
    expect(await provider.resume(), JourneyCommandResult.failed);
    expect(provider.current!.completedAt, completedAt);
    expect(provider.current!.revision, revision);
    expect(provider.current!.currentStep, isNull);
    final next = fresh();
    await open(next, 'alice');
    expect(next.current!.status, JourneyStatus.completed);
    expect(next.current!.completedAt, completedAt);
    expect(
      await provider.choose(provider.catalog.last),
      JourneyCommandResult.changed,
    );
    expect(provider.current!.completedStepCount, 0);
    expect(provider.current!.completedAt, isNull);
  });

  test('writes are published only after storage confirms them', () async {
    final gate = Completer<void>();
    preferences.nextWrite = gate;
    preferences.writeStarted = Completer<void>();
    final choice = provider.choose(provider.catalog.first);
    await preferences.writeStarted!.future;
    expect(provider.current, isNull);
    expect(provider.isWriting, isTrue);
    gate.complete();
    expect(await choice, JourneyCommandResult.changed);
    expect(provider.current, isNotNull);
  });

  test(
    'refused storage retains confirmed data and requires explicit reread',
    () async {
      await chooseFirst();
      final confirmed = provider.current;
      preferences.refuseWrites = true;
      expect(
        await provider.completeStep(confirmed!.currentStep!.stepId),
        JourneyCommandResult.failed,
      );
      expect(identical(provider.current, confirmed), isTrue);
      expect(provider.canWrite, isFalse);
      expect(provider.error, isNotNull);
      expect(await provider.pause(), JourneyCommandResult.failed);
      preferences.refuseWrites = false;
      await provider.load(force: true);
      expect(provider.current!.completedStepCount, 0);
      expect(provider.canWrite, isTrue);
      expect(
        await provider.completeStep(confirmed.currentStep!.stepId),
        JourneyCommandResult.changed,
      );
    },
  );

  test(
    'corrupt data is not overwritten by a fabricated empty success',
    () async {
      await chooseFirst();
      final confirmed = provider.current;
      await preferences.delegate.setString(
        'journey_progress_alice',
        'not-encrypted',
      );
      await provider.load(force: true);
      expect(provider.current, same(confirmed));
      expect(provider.error, isNotNull);
      expect(provider.canWrite, isFalse);
      expect(
        await provider.choose(provider.catalog.last),
        JourneyCommandResult.failed,
      );
      expect(preferences.getString('journey_progress_alice'), 'not-encrypted');
      final next = fresh();
      await open(next, 'alice');
      expect(next.hasLoadedData, isFalse);
      expect(next.error, isNotNull);
      expect(next.current, isNull);
    },
  );

  test(
    'late reads are single-flight and cannot expose an old account',
    () async {
      await chooseFirst();
      final gate = Completer<void>();
      preferences.nextReload = gate;
      final old = provider.load(force: true);
      expect(identical(old, provider.load(force: true)), isTrue);
      await Future<void>.delayed(Duration.zero);
      provider.onUserChanged(userId: 'bob');
      expect(provider.current, isNull);
      expect(provider.catalog, isEmpty);
      await provider.load();
      expect(provider.hasLoadedData, isTrue);
      gate.complete();
      await old;
      expect(provider.current, isNull);
      expect(provider.error, isNull);
    },
  );

  test(
    'accepted old-account writes settle without updating the new account',
    () async {
      await chooseFirst();
      final gate = Completer<void>();
      preferences.nextWrite = gate;
      preferences.writeStarted = Completer<void>();
      final old = provider.completeStep(provider.current!.currentStep!.stepId);
      await preferences.writeStarted!.future;
      provider.onUserChanged(userId: 'bob');
      expect(provider.current, isNull);
      final nextLoad = provider.load();
      gate.complete();
      expect(await old, JourneyCommandResult.failed);
      await nextLoad;
      expect(provider.current, isNull);
      final previousAccount = fresh();
      await open(previousAccount, 'alice');
      expect(previousAccount.current!.completedStepCount, 1);
    },
  );

  test('a stale refresh cannot overwrite a newer completed step', () async {
    await chooseFirst();
    final delayed = _DelayedReadRepository(
      cipher: cipher,
      preferences: preferences,
    );
    final target = JourneyProvider(repository: delayed);
    addTearDown(target.dispose);
    await open(target, 'alice');
    final gate = Completer<void>();
    delayed.nextRead = gate;
    delayed.readStarted = Completer<void>();
    final refresh = target.load(force: true);
    await delayed.readStarted!.future;
    final completion = target.completeStep(target.current!.currentStep!.stepId);
    expect(await completion, JourneyCommandResult.changed);
    gate.complete();
    await refresh;
    expect(target.current!.completedStepCount, 1);
    expect(target.error, isNull);
  });

  test(
    'a failed stale read cannot disable a successful overlapping write',
    () async {
      await chooseFirst();
      final delayed = _DelayedReadRepository(
        cipher: cipher,
        preferences: preferences,
      );
      final target = JourneyProvider(repository: delayed);
      addTearDown(target.dispose);
      await open(target, 'alice');
      final readGate = Completer<void>();
      final writeGate = Completer<void>();
      delayed.nextRead = readGate;
      delayed.readStarted = Completer<void>();
      preferences.nextWrite = writeGate;
      preferences.writeStarted = Completer<void>();
      final refresh = target.load(force: true);
      final completion = target.completeStep(
        target.current!.currentStep!.stepId,
      );
      await delayed.readStarted!.future;
      await preferences.writeStarted!.future;
      delayed.readError = StateError('Local read interrupted');
      readGate.complete();
      await refresh;
      writeGate.complete();
      expect(await completion, JourneyCommandResult.changed);
      expect(target.current!.completedStepCount, 1);
      expect(target.error, isNull);
      expect(target.canWrite, isTrue);
    },
  );

  test('a queued old-enrollment step cannot affect the replacement', () async {
    await chooseFirst();
    final oldStep = provider.current!.currentStep!.stepId;
    final replacement = provider.choose(provider.catalog.last);
    final stale = provider.completeStep(oldStep);
    expect(await replacement, JourneyCommandResult.changed);
    expect(await stale, JourneyCommandResult.failed);
    expect(provider.current!.path.pathId, provider.catalog.last.pathId);
    expect(provider.current!.completedStepCount, 0);
  });

  test('demo starts empty, records explicit choices and stays separate from real accounts', () async {
    await open(provider, 'ignored', demo: true);
    expect(provider.isDemo, isTrue);
    expect(provider.current, isNull);
    expect(provider.canWrite, isTrue);
    await chooseFirst();
    final demoId = provider.current!.enrollmentId;
    expect(preferences.getString('journey_progress_demo'), isNotNull);
    await open(provider, 'alice');
    expect(provider.current, isNull);
    final next = fresh();
    await open(next, 'ignored-again', demo: true);
    expect(next.current!.enrollmentId, demoId);
    provider.resetSession();
    await provider.load();
    expect(provider.canWrite, isFalse);
    expect(provider.current, isNull);
  });

  test('deletion waits for accepted writes and cannot resurrect the owner document', () async {
    final gate = Completer<void>();
    preferences.nextWrite = gate;
    preferences.writeStarted = Completer<void>();
    final choice = provider.choose(provider.catalog.first);
    await preferences.writeStarted!.future;
    final deletion = provider.deleteOwner('alice');
    gate.complete();
    expect(await choice, JourneyCommandResult.failed);
    await deletion;
    await provider.flushed;
    expect(preferences.getString('journey_progress_alice'), isNull);
    final next = fresh();
    await open(next, 'alice');
    expect(next.current, isNull);
  });

  test(
    'owner export waits for writes and never publishes into another session',
    () async {
      final gate = Completer<void>();
      preferences.nextWrite = gate;
      preferences.writeStarted = Completer<void>();
      final choice = provider.choose(provider.catalog.first);
      await preferences.writeStarted!.future;
      final exported = provider.exportOwner('alice');
      provider.onUserChanged(userId: 'bob');
      gate.complete();
      await choice;
      final document = JourneyDocument.fromJson(await exported, owner: 'alice');
      expect(document.current, isNotNull);
      expect(provider.current, isNull);
      expect(await provider.exportOwner('nobody'), isNull);
    },
  );

  test(
    'deleting one owner preserves the other owner and reports refusal',
    () async {
      await chooseFirst();
      await open(provider, 'bob');
      await chooseFirst();
      final bobId = provider.current!.enrollmentId;
      preferences.refuseRemoval = true;
      await expectLater(provider.deleteOwner('alice'), throwsStateError);
      preferences.refuseRemoval = false;
      await provider.deleteOwner('alice');
      expect(provider.current!.enrollmentId, bobId);
      expect(preferences.getString('journey_progress_bob'), isNotNull);
      expect(preferences.getString('journey_progress_alice'), isNull);
    },
  );

  test(
    'concurrent same-path choices are unchanged after the first confirmation',
    () async {
      final path = provider.catalog.first;
      final first = provider.choose(path);
      final duplicate = provider.choose(path);
      expect(await first, JourneyCommandResult.changed);
      final id = provider.current!.enrollmentId;
      expect(await duplicate, JourneyCommandResult.unchanged);
      expect(provider.current!.enrollmentId, id);
      expect(provider.current!.revision, 1);
    },
  );

  test(
    'a frozen enrolled version is not silently replaced by the current catalog',
    () async {
      await chooseFirst();
      final current = provider.current!;
      final frozen = JourneyEnrollment(
        enrollmentId: current.enrollmentId,
        path: JourneyPath(
          pathId: current.path.pathId,
          contentVersion: current.path.contentVersion,
          title: 'Un titre conservé lors du choix',
          description: current.path.description,
          topic: current.path.topic,
          steps: current.path.steps,
        ),
        status: current.status,
        completedStepCount: current.completedStepCount,
        revision: current.revision,
        startedAt: current.startedAt,
        updatedAt: current.updatedAt,
        completedAt: current.completedAt,
      );
      final encrypted = await cipher.seal(
        'alice',
        jsonEncode(JourneyDocument(owner: 'alice', current: frozen).toJson()),
        purpose: 'journey:v1',
      );
      await preferences.delegate.setString('journey_progress_alice', encrypted);
      final next = fresh();
      await open(next, 'alice');
      expect(next.current!.path.title, 'Un titre conservé lors du choix');
      expect(
        await next.choose(next.catalog.first),
        JourneyCommandResult.unchanged,
      );
      expect(next.current!.path.title, 'Un titre conservé lors du choix');
    },
  );

  test(
    'encoded owner keys and encrypted document ownership are both enforced',
    () async {
      const owner = 'alice/other?device';
      await open(provider, owner);
      await chooseFirst();
      expect(
        preferences.getString('journey_progress_${Uri.encodeComponent(owner)}'),
        isNotNull,
      );
      final wrongOwnerDocument = await cipher.seal(
        owner,
        jsonEncode(
          JourneyDocument(
            owner: 'someone-else',
            current: provider.current,
          ).toJson(),
        ),
        purpose: 'journey:v1',
      );
      await preferences.delegate.setString(
        'journey_progress_${Uri.encodeComponent(owner)}',
        wrongOwnerDocument,
      );
      await provider.load(force: true);
      expect(provider.error, isNotNull);
      expect(provider.canWrite, isFalse);
      expect(provider.current, isNotNull);
    },
  );

  test(
    'queued commands cannot pre-complete a future step or advance from pause',
    () async {
      await chooseFirst();
      final steps = provider.current!.path.steps;
      final first = provider.completeStep(steps.first.stepId);
      final future = provider.completeStep(steps[1].stepId);
      expect(await first, JourneyCommandResult.changed);
      expect(await future, JourneyCommandResult.failed);
      expect(provider.current!.completedStepCount, 1);
      expect(await provider.pause(), JourneyCommandResult.changed);
      final resume = provider.resume();
      final pausedCompletion = provider.completeStep(steps[1].stepId);
      expect(await resume, JourneyCommandResult.changed);
      expect(await pausedCompletion, JourneyCommandResult.failed);
      expect(provider.current!.completedStepCount, 1);
    },
  );
}
