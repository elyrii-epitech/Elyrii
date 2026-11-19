Map<String, Object?> journeyPathJson({String pathId = 'calm'}) => {
  'pathId': pathId,
  'contentVersion': 1,
  'title': 'Un moment pour soi',
  'description': 'Deux gestes à son rythme.',
  'topic': 'calm',
  'steps': [
    {
      'stepId': 'first',
      'title': 'Se poser',
      'instructions': 'Prendre un instant pour observer son environnement.',
      'durationMinutes': 1,
      'action': {'kind': 'none'},
    },
    {
      'stepId': 'second',
      'title': 'Écrire',
      'instructions': 'Noter une pensée si on le souhaite.',
      'durationMinutes': 2,
      'action': {'kind': 'journal', 'prompt': 'Comment je me sens ?'},
    },
  ],
};

const firstEnrollmentId = '10000000-0000-4000-8000-000000000001';

Map<String, Object?> journeyEnrollmentJson({
  String enrollmentId = firstEnrollmentId,
  String status = 'active',
  int count = 0,
  int revision = 1,
}) => {
  'enrollmentId': enrollmentId,
  'path': journeyPathJson(),
  'status': status,
  'completedStepCount': count,
  'revision': revision,
  'startedAt': '2026-10-23T08:00:00.000Z',
  'updatedAt': '2026-10-23T09:00:00.000Z',
  'completedAt': status == 'completed' ? '2026-10-23T09:00:00.000Z' : null,
};

Map<String, Object?> journeyDocumentJson({
  String owner = 'alice',
  Object? current,
}) => {'schemaVersion': 1, 'owner': owner, 'current': current};
