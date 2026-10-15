import 'dart:async';

import '../test/flutter_test_config.dart' as support;

Future<void> testExecutable(FutureOr<void> Function() main) =>
    support.testExecutable(main);
