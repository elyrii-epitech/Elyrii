enum JourneyTopic { connection, calm, sleep }

enum JourneyStatus { active, paused, completed }

enum JourneyCommandResult { changed, unchanged, failed }

sealed class JourneyAction {
  const JourneyAction();
}

final class JourneyNoAction extends JourneyAction {
  const JourneyNoAction();
}

final class JourneyJournalAction extends JourneyAction {
  final String prompt;

  const JourneyJournalAction({required this.prompt});
}

final class JourneyMeditationAction extends JourneyAction {
  final String programId;
  final int durationMinutes;

  const JourneyMeditationAction({
    required this.programId,
    required this.durationMinutes,
  });
}

final class JourneyStep {
  final String stepId;
  final String title;
  final String instructions;
  final int durationMinutes;
  final JourneyAction action;

  const JourneyStep({
    required this.stepId,
    required this.title,
    required this.instructions,
    required this.durationMinutes,
    required this.action,
  });
}

final class JourneyPath {
  final String pathId;
  final String title;
  final String description;
  final int contentVersion;
  final JourneyTopic topic;
  final List<JourneyStep> steps;

  JourneyPath({
    required this.pathId,
    required this.title,
    required this.description,
    required this.contentVersion,
    required this.topic,
    required List<JourneyStep> steps,
  }) : steps = List.unmodifiable(steps);
}

final class JourneyEnrollment {
  final String enrollmentId;
  final JourneyPath path;
  final JourneyStatus status;
  final int completedStepCount;
  final int revision;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  const JourneyEnrollment({
    required this.enrollmentId,
    required this.path,
    required this.status,
    required this.completedStepCount,
    required this.revision,
    required this.startedAt,
    required this.updatedAt,
    required this.completedAt,
  });

  JourneyStep? get currentStep =>
      status == JourneyStatus.completed ? null : path.steps[completedStepCount];

  int get currentStepNumber => status == JourneyStatus.completed
      ? path.steps.length
      : completedStepCount + 1;
}
