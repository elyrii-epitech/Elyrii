import 'package:elyrii_app/core/diagnostics/app_diagnostics.dart';
import 'package:elyrii_app/core/widgets/mascot_model_surface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a closing native WebView cannot produce an unhandled command failure',
    () async {
      var calls = 0;
      final records = <(String, String)>[];
      final previousSink = AppDiagnostics.sink;
      AppDiagnostics.sink = (event, category) => records.add((event, category));
      addTearDown(() => AppDiagnostics.sink = previousSink);
      final controller = MascotModelController(
        sendCommand: (_) async {
          calls++;
          if (calls == 1) {
            throw MissingPluginException('Fixture: closed renderer');
          }
          return null;
        },
      );
      controller.onModelLoaded.value = true;
      controller.pauseAnimation();
      await Future<void>.delayed(Duration.zero);
      expect(records, [('mascot_command_failed', 'MissingPluginException')]);
      controller.pauseAnimation();
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);
      controller.onModelLoaded.value = false;
      controller.pauseAnimation();
      expect(calls, 2);
    },
  );
}
