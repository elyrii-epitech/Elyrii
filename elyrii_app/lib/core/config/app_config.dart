import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'api_config.dart';

/// App-wide configuration
/// Use [ApiConfig] for endpoint URLs
class AppConfig {
  AppConfig._();

  /// Whether the app is running in debug mode
  static const bool isDebug = true;

  static const int _gatewayPort = 3000;

  /// Resolve the correct gateway host for the current platform
  static String get _defaultGatewayUrl {
    if (kIsWeb) return 'http://localhost:$_gatewayPort';
    if (Platform.isAndroid) return 'http://10.0.2.2:$_gatewayPort';
    return 'http://localhost:$_gatewayPort';
  }

  /// Configure the gateway URL based on environment or auto-detect platform
  static void initialize({String? gatewayUrl}) {
    ApiConfig.setBaseUrl(gatewayUrl ?? _defaultGatewayUrl);
  }
}
