import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Exact account keys avoid treating an owner's suffix as another identity.
abstract final class AccountPreferences {
  static Future<void> removeOwner(SharedPreferences prefs, String owner) async {
    final ownedKeys = {
      for (final base in const [
        'account_settings',
        'cache_user_settings',
        'cache_user_profile',
        'cache_journal_entries',
        'profile_setup_completed',
        'elyrii_mascot_customization',
        'elyrii_mascot_theme',
        'elyrii_mascot_appearance',
        'elyrii_mascot_pending_sync',
        'elyrii_mascot_schema_version',
        'elyrii_seen_cosmetic_unlocks',
      ])
        '${base}_$owner',
      // Previous dashboard caches did not include their owner in the envelope.
      for (final range in const ['7d', '30d', '90d'])
        'cache_dashboard_data_${owner}_$range',
      'profile_setup_completed',
    };
    for (final key in prefs.getKeys()) {
      var belongsToOwner = ownedKeys.contains(key);
      if (!belongsToOwner && key.startsWith('cache_dashboard_data_')) {
        try {
          final cache = jsonDecode(prefs.getString(key) ?? 'null');
          belongsToOwner = cache is Map && cache['owner'] == owner;
        } on FormatException {
          // Unknown malformed caches cannot be attributed to this account.
        }
      }
      if (belongsToOwner && !await prefs.remove(key)) {
        throw StateError('Account preference removal refused');
      }
    }
  }
}
