import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/native_app.dart';

/// Use --profile on physical Android/iOS hardware; raster metrics in headless
/// browsers or widget tests do not substitute for native GPU measurements.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('cold start and 3D dashboard frame timings', (tester) async {
    final startup = Stopwatch()..start();
    await startDemoApp(tester);
    startup.stop();
    final timings = <FrameTiming>[];
    SchedulerBinding.instance.addTimingsCallback(timings.addAll);
    try {
      await binding.traceAction(() async {
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
      }, reportKey: 'dashboard_3d');
    } finally {
      SchedulerBinding.instance.removeTimingsCallback(timings.addAll);
    }
    double percentile(List<int> samples) {
      if (samples.isEmpty) return 0;
      samples.sort();
      return samples[((samples.length - 1) * .95).round()] / 1000;
    }

    expect(
      timings,
      isNotEmpty,
      reason: 'Run this profile on a physical device.',
    );
    binding.reportData ??= {};
    binding.reportData!['dashboard_ready_ms'] = startup.elapsedMilliseconds;
    binding.reportData!['frames'] = {
      'count': timings.length,
      'build_p95_ms': percentile(
        timings.map((f) => f.buildDuration.inMicroseconds).toList(),
      ),
      'raster_p95_ms': percentile(
        timings.map((f) => f.rasterDuration.inMicroseconds).toList(),
      ),
    };
  });
}
