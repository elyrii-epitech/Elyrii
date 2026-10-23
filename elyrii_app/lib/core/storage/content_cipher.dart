import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../services/secure_storage_service.dart';

/// Authenticated encryption for private local content. Keys live in platform
/// secure storage, separately from the database and its backups.
class ContentCipher {
  final SecureStorageService storage;
  final AesGcm _algorithm = AesGcm.with256bits();
  final Map<String, Future<SecretKey>> _keys = {};
  final Set<String> _revoked = {};
  static final _instances = Expando<ContentCipher>();
  factory ContentCipher(SecureStorageService storage) =>
      _instances[storage] ??= ContentCipher._(storage);
  ContentCipher._(this.storage);

  Future<SecretKey> _key(String owner) async {
    final existing = _keys[owner];
    if (existing != null) return existing;
    final request = _readOrCreateKey(owner);
    _keys[owner] = request;
    try {
      return await request;
    } catch (_) {
      if (identical(_keys[owner], request)) _keys.remove(owner);
      rethrow;
    }
  }

  Future<SecretKey> _readOrCreateKey(String owner) async {
    if (_revoked.contains(owner)) {
      throw StateError('Account content was removed');
    }
    final name = 'content_key_${Uri.encodeComponent(owner)}';
    final saved = await storage.read(key: name);
    if (saved != null) return SecretKey(base64Decode(saved));
    final key = await _algorithm.newSecretKey();
    if (_revoked.contains(owner)) {
      throw StateError('Account content was removed');
    }
    await storage.write(
      key: name,
      value: base64Encode(await key.extractBytes()),
    );
    return key;
  }

  Future<String> seal(
    String owner,
    String value, {
    required String purpose,
  }) async {
    if (_revoked.contains(owner)) {
      throw StateError('Account content was removed');
    }
    final box = await _algorithm.encrypt(
      utf8.encode(value),
      secretKey: await _key(owner),
      aad: utf8.encode('$owner:$purpose'),
    );
    return 'aesgcm1:${base64Encode(box.concatenation())}';
  }

  Future<String> open(
    String owner,
    String value, {
    required String purpose,
  }) async {
    if (!value.startsWith('aesgcm1:')) {
      throw const FormatException('Unencrypted content requires migration');
    }
    final box = SecretBox.fromConcatenation(
      base64Decode(value.substring(8)),
      nonceLength: 12,
      macLength: 16,
    );
    return utf8.decode(
      await _algorithm.decrypt(
        box,
        secretKey: await _key(owner),
        aad: utf8.encode('$owner:$purpose'),
      ),
    );
  }

  Future<void> deleteOwner(String owner) async {
    _revoked.add(owner);
    // Finish a key creation that may already have entered platform storage.
    try {
      await _keys[owner];
    } catch (_) {}
    _keys.remove(owner);
    await storage.delete(key: 'content_key_${Uri.encodeComponent(owner)}');
  }
}
