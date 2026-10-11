import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as paths;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

/// Explicit readable exports. Only app-owned temporary files are touched.
abstract final class PrivateExport {
  @visibleForTesting
  static Future<Directory> Function() temporaryDirectory =
      getTemporaryDirectory;
  static Future<Directory> _directory() async =>
      Directory(paths.join((await temporaryDirectory()).path, 'elyrii-exports'))
          .create(recursive: true);
  static Future<void> cleanup({bool all = false}) async {
    final root = await _directory();
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    for (final dir in [
      root,
      Directory(paths.join(root.parent.path, 'share_plus')),
    ]) {
      if (!await dir.exists()) continue;
      await for (final entry in dir.list(followLinks: false)) {
        if (entry is! File ||
            !paths.basename(entry.path).startsWith('elyrii-export-')) {
          continue;
        }
        if (all || (await entry.lastModified()).isBefore(cutoff)) {
          await entry.delete();
        }
      }
    }
  }

  static Future<ShareResult> share(
    BuildContext context,
    Map<String, dynamic> data, {
    required String title,
    bool Function()? isCurrentOwner,
  }) async {
    await cleanup();
    final file = File(
      paths.join(
        (await _directory()).path,
        'elyrii-export-${const Uuid().v4()}.json',
      ),
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
    if (!context.mounted || isCurrentOwner?.call() == false) {
      await file.delete();
      return const ShareResult('', ShareResultStatus.dismissed);
    }
    final box = context.findRenderObject();
    final origin = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 1, 1);
    try {
      return await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          title: title,
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      await file.delete();
      rethrow;
    }
  }
}
