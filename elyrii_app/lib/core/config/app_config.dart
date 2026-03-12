import 'api_config.dart';

/// App-wide configuration
/// Use [ApiConfig] for endpoint URLs
class AppConfig {
  AppConfig._();

  /// Whether the app is running in debug mode
  static const bool isDebug = true;

  /// Configure the gateway URL based on environment
  static void initialize({String? gatewayUrl}) {
    if (gatewayUrl != null) {
      ApiConfig.setBaseUrl(gatewayUrl);
    }
  }
}
