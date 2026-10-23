import 'package:elyrii_app/core/widgets/error_boundary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _application(String owner) => MaterialApp(
  home: GlobalErrorBoundary(
    key: ValueKey(owner),
    child: const SizedBox.shrink(),
  ),
);

void main() {
  testWidgets('account replacement keeps the current error boundary active', (
    tester,
  ) async {
    final original = ErrorWidget.builder;
    try {
      await tester.pumpWidget(_application('guest'));
      await tester.pumpWidget(_application('account'));
      expect(ErrorWidget.builder, isNot(same(original)));
      expect(
        ErrorWidget.builder(
          FlutterErrorDetails(exception: StateError('Fixture error')),
        ),
        isA<Material>(),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(ErrorWidget.builder, same(original));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      ErrorWidget.builder = original;
    }
  });

  testWidgets('disposing a boundary preserves a newer external error builder', (
    tester,
  ) async {
    final original = ErrorWidget.builder;
    Widget external(FlutterErrorDetails details) => const SizedBox.shrink();
    try {
      await tester.pumpWidget(_application('account'));
      ErrorWidget.builder = external;
      await tester.pumpWidget(const SizedBox.shrink());
      expect(ErrorWidget.builder, same(external));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      ErrorWidget.builder = original;
    }
  });
}
