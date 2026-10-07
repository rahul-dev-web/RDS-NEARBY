import 'supabase_config.dart';

enum AppEnvironment { development, staging, production }

class AppConfig {
  const AppConfig({required this.environment});

  final AppEnvironment environment;

  bool get isProduction => environment == AppEnvironment.production;
  bool get isDevelopment => environment == AppEnvironment.development;

  static AppEnvironment _parseEnvironment(String value) {
    switch (value.toLowerCase()) {
      case 'staging':
        return AppEnvironment.staging;
      case 'production':
        return AppEnvironment.production;
      default:
        return AppEnvironment.development;
    }
  }

  static const current = AppConfig(
    environment: AppEnvironment.development,
  );

  static AppConfig fromDefines() {
    const raw = String.fromEnvironment(
      'APP_ENVIRONMENT',
      defaultValue: 'development',
    );
    return AppConfig(environment: _parseEnvironment(raw));
  }

  static const publicWebUrl = String.fromEnvironment('PUBLIC_WEB_URL');

  bool get hasBackendConfig => hasSupabaseConfig;
  bool get hasPublicWebUrl => publicWebUrl.trim().isNotEmpty;
}