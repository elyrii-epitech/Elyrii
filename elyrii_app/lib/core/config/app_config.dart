import 'package:flutter/foundation.dart';

import 'api_config.dart';

enum AppEnvironment { development, staging, production }

/// Release builds default to production and require an explicit HTTPS gateway.
class AppConfig {
  AppConfig._();
  static const isDebug = kDebugMode;
  static const _environment = String.fromEnvironment(
    'ELYRII_ENV',
    defaultValue: kReleaseMode ? 'production' : 'development',
  );
  static const _gatewayPort = int.fromEnvironment(
    'ELYRII_API_PORT',
    defaultValue: 3001,
  );
  static const _gatewayUrl = String.fromEnvironment('ELYRII_API_URL');
  static AppEnvironment get environment => AppEnvironment.values.firstWhere(
    (value) => value.name == _environment,
    orElse: () => throw const FormatException(
      'ELYRII_ENV doit être development, staging ou production.',
    ),
  );

  static String resolveGateway({
    required AppEnvironment environment,
    String? gatewayUrl,
    TargetPlatform? platform,
  }) {
    var url = gatewayUrl?.trim() ?? '';
    if (url.isEmpty && environment == AppEnvironment.development) {
      final host = (platform ?? defaultTargetPlatform) == TargetPlatform.android
          ? '10.0.2.2'
          : 'localhost';
      url = 'http://$host:$_gatewayPort';
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException(
        'Configure une adresse API valide avec ELYRII_API_URL.',
      );
    }
    if (environment != AppEnvironment.development &&
        (uri.scheme != 'https' ||
            {'localhost', '127.0.0.1', '::1', '10.0.2.2'}.contains(uri.host))) {
      throw const FormatException(
        'La configuration staging/production exige une API HTTPS explicite.',
      );
    }
    return url.replaceAll(RegExp(r'/+$'), '');
  }

  static void initialize({String? gatewayUrl}) {
    const legacy = String.fromEnvironment('BASE_URL');
    ApiConfig.setBaseUrl(
      resolveGateway(
        environment: environment,
        gatewayUrl:
            gatewayUrl ?? (_gatewayUrl.isNotEmpty ? _gatewayUrl : legacy),
      ),
    );
  }
}
