import 'package:elyrii_app/app/launch/elyrii_launch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> decodeMark(WidgetTester tester) async {
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage(ElyriiLaunchScene.markAsset),
        tester.element(find.byType(ElyriiLaunch)),
      );
    });
    await tester.pump();
  }

  testWidgets('reveals the already mounted page and preserves its state', (
    tester,
  ) async {
    var mounts = 0;
    var taps = 0;
    final page = _PageProbe(onMount: () => mounts++, onTap: () => taps++);

    Widget app(Brightness brightness) => MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: ElyriiLaunch(child: page),
    );

    await tester.pumpWidget(app(Brightness.dark));
    expect(mounts, 1);
    expect(find.byType(ElyriiLaunchScene), findsOneWidget);
    // Hit the covered button by coordinate: the reveal blocks its interaction.
    await tester.tapAt(tester.getCenter(find.byType(TextButton)));
    expect(taps, 0);

    await decodeMark(tester);
    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.byType(ElyriiLaunchScene), findsNothing);
    expect(mounts, 1);
    await tester.tap(find.byType(TextButton));
    expect(taps, 1);

    // A theme update must not replay the launch or remount the router's page.
    await tester.pumpWidget(app(Brightness.light));
    await tester.pumpAndSettle();
    expect(mounts, 1);
    expect(find.byType(ElyriiLaunchScene), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion enters the page without waiting for the reveal', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: ElyriiLaunch(child: Scaffold(body: Text('Ready'))),
        ),
      ),
    );
    await decodeMark(tester);
    expect(find.byType(ElyriiLaunchScene), findsNothing);
    expect(find.text('Ready'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('compact launch supports enlarged text without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: ElyriiLaunchScene(),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('elyrii'), findsOneWidget);
    expect(find.text('Un instant pour toi.'), findsNothing);
    final wordmark = tester.getRect(find.text('elyrii'));
    expect(wordmark.bottom, lessThan(568));
  });
}

class _PageProbe extends StatefulWidget {
  const _PageProbe({required this.onMount, required this.onTap});

  final VoidCallback onMount;
  final VoidCallback onTap;

  @override
  State<_PageProbe> createState() => _PageProbeState();
}

class _PageProbeState extends State<_PageProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(onPressed: widget.onTap, child: const Text('Ready')),
    ),
  );
}
