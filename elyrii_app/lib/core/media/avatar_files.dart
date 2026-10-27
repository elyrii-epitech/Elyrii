import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as paths;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../diagnostics/app_diagnostics.dart';

abstract final class AvatarFiles {
  static String _scope(String owner) =>
      base64Url.encode(utf8.encode(owner)).replaceAll('=', '');
  static String _key(String owner) => 'pending_avatar_v1_${_scope(owner)}';
  static Future<Directory> _root() async => Directory(
    paths.join((await getTemporaryDirectory()).path, 'elyrii-avatars'),
  ).create(recursive: true);
  static Future<void> begin(String owner) async =>
      (await SharedPreferences.getInstance()).setString(
        'avatar_picker_pending_owner',
        owner,
      );
  static Future<String> adopt(String source, String owner) async {
    final sourceFile = File(source);
    if (await sourceFile.length() > 4 * 1024 * 1024) {
      throw const FormatException('Avatar exceeds the local file budget');
    }
    final data = await sourceFile.readAsBytes();
    if (data.length > 4 * 1024 * 1024) {
      throw const FormatException('Avatar exceeds the local file budget');
    }
    final directory = await Directory(
      paths.join((await _root()).path, _scope(owner)),
    ).create(recursive: true);
    final target = File(paths.join(directory.path, '${const Uuid().v4()}.jpg'));
    await target.writeAsBytes(data, flush: true);
    final prefs = await SharedPreferences.getInstance();
    final old = prefs.getString(_key(owner));
    if (!await prefs.setString(_key(owner), target.path)) {
      await target.delete();
      throw StateError('Pending avatar could not be persisted');
    }
    await prefs.remove('avatar_picker_pending_owner');
    if (old != null && old != target.path) await release(old);
    return target.path;
  }

  static Future<void> recover(String owner) async {
    final prefs = await SharedPreferences.getInstance();
    if (!Platform.isAndroid ||
        prefs.getString('avatar_picker_pending_owner') != owner) {
      return;
    }
    try {
      final response = await ImagePicker().retrieveLostData();
      final files = response.files;
      if (files != null && files.isNotEmpty) {
        await adopt(files.first.path, owner);
      }
      if (response.exception != null) {
        AppDiagnostics.record('avatar_recovery_failed', response.exception!);
      }
      await prefs.remove('avatar_picker_pending_owner');
    } catch (error) {
      AppDiagnostics.record('avatar_recovery_failed', error);
    }
  }

  static Future<String?> pending(String owner) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_key(owner));
    if (path == null || !await File(path).exists()) return null;
    final root = await _root();
    if (!paths.isWithin(paths.join(root.path, _scope(owner)), path)) {
      return null;
    }
    return path;
  }

  static Future<void> release(String path) async {
    final file = File(path);
    if (!await file.exists()) return;
    final root = await _root();
    final actual = await file.resolveSymbolicLinks();
    if (paths.isWithin(await root.resolveSymbolicLinks(), actual)) {
      await file.delete();
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().where(
        (key) => key.startsWith('pending_avatar_v1_'),
      )) {
        if (prefs.getString(key) == path) await prefs.remove(key);
      }
    }
  }

  static Future<void> cleanupAbandoned() async {
    final root = await _root();
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    await for (final entry in root.list(recursive: true, followLinks: false)) {
      if (entry is File && (await entry.lastModified()).isBefore(cutoff)) {
        await release(entry.path);
      }
    }
  }

  static Future<void> deleteOwner(String owner) async {
    final dir = Directory(paths.join((await _root()).path, _scope(owner)));
    if (await dir.exists()) await dir.delete(recursive: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(owner));
    if (prefs.getString('avatar_picker_pending_owner') == owner) {
      await prefs.remove('avatar_picker_pending_owner');
    }
  }
}
