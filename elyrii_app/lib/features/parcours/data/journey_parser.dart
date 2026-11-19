import '../domain/journey.dart';

final class JourneyDocument {
  final String owner;
  final JourneyEnrollment? current;

  const JourneyDocument({required this.owner, required this.current});

  factory JourneyDocument.fromJson(Object? value, {required String owner}) {
    final json = _object(value);
    if (json['schemaVersion'] is! int || json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported journey document.');
    }
    if (json['owner'] != owner || !json.containsKey('current')) {
      throw const FormatException('Journey document account mismatch.');
    }
    return JourneyDocument(
      owner: owner,
      current: json['current'] == null
          ? null
          : parseJourneyEnrollment(json['current']),
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'owner': owner,
    'current': current == null ? null : journeyEnrollmentToJson(current!),
  };
}

JourneyPath parseJourneyPath(Object? value) {
  final json = _object(value);
  final topic = switch (json['topic']) {
    'connection' => JourneyTopic.connection,
    'calm' => JourneyTopic.calm,
    'sleep' => JourneyTopic.sleep,
    _ => throw const FormatException('Invalid journey topic.'),
  };
  final steps = _list(json['steps']).map(_step).toList();
  if (steps.isEmpty ||
      steps.map((step) => step.stepId).toSet().length != steps.length) {
    throw const FormatException('Invalid journey steps.');
  }
  return JourneyPath(
    pathId: _text(json['pathId']),
    title: _text(json['title']),
    description: _text(json['description']),
    contentVersion: _integer(json['contentVersion'], minimum: 1),
    topic: topic,
    steps: steps,
  );
}

JourneyEnrollment parseJourneyEnrollment(Object? value) {
  final json = _object(value);
  final enrollmentId = _text(json['enrollmentId']);
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(enrollmentId)) {
    throw const FormatException('Invalid journey enrollment identity.');
  }
  final path = parseJourneyPath(json['path']);
  final status = switch (json['status']) {
    'active' => JourneyStatus.active,
    'paused' => JourneyStatus.paused,
    'completed' => JourneyStatus.completed,
    _ => throw const FormatException('Invalid journey status.'),
  };
  final count = _integer(json['completedStepCount']);
  final startedAt = _date(json['startedAt']);
  final updatedAt = _date(json['updatedAt']);
  if (!json.containsKey('completedAt')) {
    throw const FormatException('Missing journey completion date.');
  }
  final completedAt = json['completedAt'] == null
      ? null
      : _date(json['completedAt']);
  final terminal = status == JourneyStatus.completed;
  if (count > path.steps.length ||
      terminal != (count == path.steps.length) ||
      terminal != (completedAt != null) ||
      updatedAt.isBefore(startedAt) ||
      (completedAt != null &&
          (completedAt.isBefore(startedAt) ||
              completedAt.isAfter(updatedAt)))) {
    throw const FormatException('Inconsistent journey progress.');
  }
  return JourneyEnrollment(
    enrollmentId: enrollmentId,
    path: path,
    status: status,
    completedStepCount: count,
    revision: _integer(json['revision'], minimum: 1),
    startedAt: startedAt,
    updatedAt: updatedAt,
    completedAt: completedAt,
  );
}

Map<String, Object?> journeyEnrollmentToJson(JourneyEnrollment enrollment) => {
  'enrollmentId': enrollment.enrollmentId,
  'path': {
    'pathId': enrollment.path.pathId,
    'contentVersion': enrollment.path.contentVersion,
    'title': enrollment.path.title,
    'description': enrollment.path.description,
    'topic': enrollment.path.topic.name,
    'steps': [
      for (final step in enrollment.path.steps)
        {
          'stepId': step.stepId,
          'title': step.title,
          'instructions': step.instructions,
          'durationMinutes': step.durationMinutes,
          'action': switch (step.action) {
            JourneyNoAction() => {'kind': 'none'},
            JourneyJournalAction(:final prompt) => {
              'kind': 'journal',
              'prompt': prompt,
            },
            JourneyMeditationAction(:final programId, :final durationMinutes) =>
              {
                'kind': 'meditation',
                'programId': programId,
                'durationMinutes': durationMinutes,
              },
          },
        },
    ],
  },
  'status': enrollment.status.name,
  'completedStepCount': enrollment.completedStepCount,
  'revision': enrollment.revision,
  'startedAt': enrollment.startedAt.toUtc().toIso8601String(),
  'updatedAt': enrollment.updatedAt.toUtc().toIso8601String(),
  'completedAt': enrollment.completedAt?.toUtc().toIso8601String(),
};

JourneyStep _step(Object? value) {
  final json = _object(value);
  final action = _object(json['action']);
  final parsedAction = switch (action['kind']) {
    'none' => const JourneyNoAction(),
    'journal' => JourneyJournalAction(prompt: _text(action['prompt'])),
    'meditation' => JourneyMeditationAction(
      programId: _text(action['programId']),
      durationMinutes: _integer(action['durationMinutes'], minimum: 1),
    ),
    _ => throw const FormatException('Invalid journey action.'),
  };
  return JourneyStep(
    stepId: _text(json['stepId']),
    title: _text(json['title']),
    instructions: _text(json['instructions']),
    durationMinutes: _integer(json['durationMinutes'], minimum: 1),
    action: parsedAction,
  );
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('Expected journey object.');
  }
  return value;
}

List<Object?> _list(Object? value) {
  if (value is! List<Object?>) {
    throw const FormatException('Expected journey list.');
  }
  return value;
}

String _text(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Expected nonempty journey text.');
  }
  return value;
}

int _integer(Object? value, {int minimum = 0}) {
  if (value is! int || value < minimum) {
    throw const FormatException('Invalid journey integer.');
  }
  return value;
}

DateTime _date(Object? value) {
  if (value is! String ||
      !RegExp(
        r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|\+00:00)$',
      ).hasMatch(value)) {
    throw const FormatException('Expected UTC journey date.');
  }
  final date = DateTime.tryParse(value);
  if (date == null ||
      date.year != int.parse(value.substring(0, 4)) ||
      date.month != int.parse(value.substring(5, 7)) ||
      date.day != int.parse(value.substring(8, 10)) ||
      date.hour != int.parse(value.substring(11, 13)) ||
      date.minute != int.parse(value.substring(14, 16)) ||
      date.second != int.parse(value.substring(17, 19))) {
    throw const FormatException('Invalid journey date.');
  }
  return date;
}
