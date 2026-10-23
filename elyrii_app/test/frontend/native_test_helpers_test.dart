import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/native_app.dart';

void main() {
  testWidgets('waits for a hidden control before selecting the first match', (
    tester,
  ) async {
    late StateSetter rebuild;
    var visible = false;
    var firstTaps = 0;
    var secondTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Scaffold(
              body: visible
                  ? Column(
                      children: [
                        Semantics(
                          container: true,
                          excludeSemantics: true,
                          label: 'Onglet Méditation, 4 sur 5',
                          child: FilledButton(
                            onPressed: () => firstTaps++,
                            child: const Text('Continue'),
                          ),
                        ),
                        Semantics(
                          container: true,
                          excludeSemantics: true,
                          label: 'Onglet Méditation, 4 sur 5',
                          child: FilledButton(
                            onPressed: () => secondTaps++,
                            child: const Text('Continue'),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
    final timer = Timer(
      const Duration(milliseconds: 300),
      () => rebuild(() => visible = true),
    );
    addTearDown(timer.cancel);
    await tapVisible(
      tester,
      find.bySemanticsLabel(RegExp(r'^Onglet Méditation,')),
    );
    expect(firstTaps, 1);
    expect(secondTaps, 0);
  });

  testWidgets('rebuilds an enabled control after text input before tapping', (
    tester,
  ) async {
    var hasText = false;
    var submitted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Column(
              children: [
                TextField(
                  onChanged: (value) =>
                      setState(() => hasText = value.isNotEmpty),
                ),
                FilledButton(
                  onPressed: hasText ? () => submitted = true : null,
                  child: const Text('Send'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Native message');
    await tapVisible(tester, find.text('Send'));
    expect(submitted, isTrue);
  });
}
