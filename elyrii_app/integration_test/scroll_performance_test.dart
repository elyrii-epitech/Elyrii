import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/native_app.dart';

/// Frame timings for startup, tab switches and flings on a real device.
/// Run with `flutter drive --profile --driver=test_driver/integration_test.dart
/// --target=integration_test/scroll_performance_test.dart -d DEVICE_ID`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('startup, tab switch and scroll frame timings', (tester) async {
    final startup = Stopwatch()..start();
    await startDemoApp(tester);
    final report = <String, Object>{'startup_ms': startup.elapsedMilliseconds};
    final center = tester.getCenter(find.byType(WidgetsApp).first);

    Future<void> idle(int ms) =>
        Future<void>.delayed(Duration(milliseconds: ms));

    Map<String, num> summarize(List<FrameTiming> frames) {
      List<double> sorted(Duration Function(FrameTiming) f) =>
          frames.map((t) => f(t).inMicroseconds / 1000).toList()..sort();
      double pct(List<double> v, double p) => v[((v.length - 1) * p).round()];
      final build = sorted((t) => t.buildDuration);
      final raster = sorted((t) => t.rasterDuration);
      final total = sorted((t) => t.totalSpan);
      return {
        'frames': frames.length,
        'build_p50': pct(build, .5),
        'build_p90': pct(build, .9),
        'build_max': build.last,
        'raster_p50': pct(raster, .5),
        'raster_p90': pct(raster, .9),
        'raster_max': raster.last,
        'over_8ms': total.where((v) => v > 8.4).length,
        'over_16ms': total.where((v) => v > 16.7).length,
      };
    }

    Future<List<FrameTiming>> record(Future<void> Function() action) async {
      final frames = <FrameTiming>[];
      void collect(List<FrameTiming> t) => frames.addAll(t);
      SchedulerBinding.instance.addTimingsCallback(collect);
      await action();
      // Timings are delivered in batches; wait for the last one.
      await idle(1200);
      SchedulerBinding.instance.removeTimingsCallback(collect);
      return frames;
    }

    Future<void> measureTab(String tab) async {
      if (tab != 'Accueil') {
        final switched = await record(() async {
          await tapVisible(
            tester,
            find.bySemanticsLabel(RegExp('^Onglet $tab,')),
          );
          await idle(1500);
        });
        report['$tab switch'] = summarize(switched);
      }
      await idle(500);
      final scrolled = await record(() async {
        for (var i = 0; i < 3; i++) {
          await tester.flingFrom(center, const Offset(0, -500), 2500);
          await idle(900);
          await tester.flingFrom(center, const Offset(0, 500), 2500);
          await idle(900);
        }
      });
      report['$tab scroll'] = summarize(scrolled);
    }

    for (final tab in [
      'Accueil',
      'Défis',
      'Journal',
      'Méditer',
      'Programmes',
    ]) {
      await measureTab(tab);
    }
    for (final tab in ['Accueil', 'Méditer', 'Programmes']) {
      final back = await record(() async {
        await tapVisible(
          tester,
          find.bySemanticsLabel(RegExp('^Onglet $tab,')),
        );
        await idle(1500);
      });
      report['$tab return'] = summarize(back);
      await idle(16000);
    }
    binding.reportData = report;
  });
}
