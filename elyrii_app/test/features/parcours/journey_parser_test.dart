import 'dart:convert';

import 'package:elyrii_app/features/parcours/data/journey_parser.dart';
import 'package:elyrii_app/features/parcours/domain/journey.dart';
import 'package:flutter_test/flutter_test.dart';

import 'journey_test_data.dart';

void main() {
  test('parses frozen content into immutable typed paths and actions', () {
    final document = JourneyDocument.fromJson(
      journeyDocumentJson(current: journeyEnrollmentJson(count: 1)),
      owner: 'alice',
    );
    final enrollment = document.current!;
    expect(enrollment.path.topic, JourneyTopic.calm);
    expect(enrollment.currentStep!.stepId, 'second');
    expect(enrollment.currentStepNumber, 2);
    expect(enrollment.currentStep!.action, isA<JourneyJournalAction>());
    expect(enrollment.startedAt.isUtc, isTrue);
    expect(() => enrollment.path.steps.clear(), throwsUnsupportedError);
  });

  test('completed enrollment has no next step or out-of-bounds number', () {
    final enrollment = parseJourneyEnrollment(
      journeyEnrollmentJson(status: 'completed', count: 2, revision: 3),
    );
    expect(enrollment.currentStep, isNull);
    expect(enrollment.currentStepNumber, 2);
    expect(enrollment.completedAt, DateTime.utc(2026, 10, 23, 9));
  });

  test('full frozen path content survives document JSON serialization', () {
    final enrollment = parseJourneyEnrollment(journeyEnrollmentJson(count: 1));
    final document = JourneyDocument(owner: 'alice', current: enrollment);
    final restored = JourneyDocument.fromJson(
      jsonDecode(jsonEncode(document.toJson())),
      owner: 'alice',
    );
    expect(restored.current!.enrollmentId, firstEnrollmentId);
    expect(restored.current!.path.contentVersion, 1);
    expect(
      restored.current!.path.steps.first.instructions,
      'Prendre un instant pour observer son environnement.',
    );
    expect(restored.current!.completedStepCount, 1);
    expect(restored.current!.updatedAt, DateTime.utc(2026, 10, 23, 9));
  });

  test(
    'all supported action variants can be persisted without UI dependencies',
    () {
      final path = journeyPathJson();
      path['steps'] = [
        {
          'stepId': 'meditation',
          'title': 'Pratiquer',
          'instructions': 'Ouvrir une pratique si on le souhaite.',
          'durationMinutes': 3,
          'action': {
            'kind': 'meditation',
            'programId': 'body-scan',
            'durationMinutes': 3,
          },
        },
      ];
      final enrollment = parseJourneyEnrollment(
        journeyEnrollmentJson()..['path'] = path,
      );
      final restored = parseJourneyEnrollment(
        journeyEnrollmentToJson(enrollment),
      );
      final action = restored.path.steps.single.action;
      expect(action, isA<JourneyMeditationAction>());
      if (action case JourneyMeditationAction(
        :final programId,
        :final durationMinutes,
      )) {
        expect(programId, 'body-scan');
        expect(durationMinutes, 3);
      }
      expect(
        parseJourneyPath(journeyPathJson()).steps.first.action,
        isA<JourneyNoAction>(),
      );
    },
  );

  test('missing current differs from an explicit absence of enrollment', () {
    expect(
      JourneyDocument.fromJson(journeyDocumentJson(), owner: 'alice').current,
      isNull,
    );
    expect(
      () => JourneyDocument.fromJson({
        'schemaVersion': 1,
        'owner': 'alice',
      }, owner: 'alice'),
      throwsFormatException,
    );
  });

  test('rejects unsupported schemas and a mismatched document owner', () {
    final invalid = <Object?>[
      null,
      [],
      journeyDocumentJson()..['schemaVersion'] = 2,
      journeyDocumentJson()..['schemaVersion'] = '1',
      journeyDocumentJson(owner: 'bob'),
      journeyDocumentJson()..remove('owner'),
    ];
    for (final value in invalid) {
      expect(
        () => JourneyDocument.fromJson(value, owner: 'alice'),
        throwsFormatException,
      );
    }
  });

  test('rejects malformed catalog values within a frozen snapshot', () {
    final invalid = [
      journeyPathJson()..['topic'] = 'unknown',
      journeyPathJson()..['steps'] = [],
      journeyPathJson()..['contentVersion'] = 0,
      journeyPathJson()..['title'] = ' ',
    ];
    for (final value in invalid) {
      expect(() => parseJourneyPath(value), throwsFormatException);
    }
  });

  test(
    'rejects malformed actions, durations and duplicate step identities',
    () {
      Map<String, Object?> step() => {
        'stepId': 'one',
        'title': 'Un pas',
        'instructions': 'Prendre son temps.',
        'durationMinutes': 1,
        'action': {'kind': 'none'},
      };
      final invalidSteps = [
        [
          step()..['action'] = {'kind': 'unknown'},
        ],
        [
          step()..['action'] = {'kind': 'journal'},
        ],
        [
          step()
            ..['action'] = {
              'kind': 'meditation',
              'programId': 'scan',
              'durationMinutes': 0,
            },
        ],
        [step()..['durationMinutes'] = '1'],
        [step()..['durationMinutes'] = 0],
        [step(), step()],
      ];
      for (final steps in invalidSteps) {
        expect(
          () => parseJourneyPath(journeyPathJson()..['steps'] = steps),
          throwsFormatException,
        );
      }
    },
  );

  test('rejects impossible progress and malformed enrollment identities', () {
    final invalid = [
      journeyEnrollmentJson()..['enrollmentId'] = 'not-a-uuid',
      journeyEnrollmentJson()..['revision'] = -1,
      journeyEnrollmentJson(count: -1),
      journeyEnrollmentJson(count: 3),
      journeyEnrollmentJson(count: 2),
      journeyEnrollmentJson(status: 'completed', count: 1),
      journeyEnrollmentJson(status: 'completed', count: 2)
        ..['completedAt'] = null,
      journeyEnrollmentJson()..['completedAt'] = '2026-10-23T08:30:00Z',
      journeyEnrollmentJson()..remove('completedAt'),
      journeyEnrollmentJson(status: 'unknown'),
    ];
    for (final value in invalid) {
      expect(() => parseJourneyEnrollment(value), throwsFormatException);
    }
  });

  test('rejects local, normalized invalid and inconsistent dates', () {
    final invalidDates = [
      '2026-10-23T08:00:00',
      '2026-10-23T08:00:00+02:00',
      '2026-02-30T08:00:00Z',
      '2026-10-23T25:00:00Z',
      'not-a-date',
    ];
    for (final date in invalidDates) {
      expect(
        () => parseJourneyEnrollment(
          journeyEnrollmentJson()..['startedAt'] = date,
        ),
        throwsFormatException,
      );
    }
    expect(
      () => parseJourneyEnrollment(
        journeyEnrollmentJson()..['updatedAt'] = '2026-10-22T08:00:00Z',
      ),
      throwsFormatException,
    );
  });
}
