import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_config.dart';
import 'core/app_logger.dart';
import 'core/supabase_config.dart';
import 'features/auth/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromDefines();
  AppLogger.info('Starting RDS Nearby in ${config.environment.name}');

  if (config.hasBackendConfig) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabasePublishableKey,
    );
  }

  runApp(RdsNearbyApp(config: config));
}

class RdsNearbyApp extends StatelessWidget {
  const RdsNearbyApp({super.key, required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    if (!config.hasBackendConfig) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _MissingConfigScreen(),
      );
    }

    return MaterialApp(
      title: 'RDS Nearby',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class _MissingConfigScreen extends StatelessWidget {
  const _MissingConfigScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Supabase configuration is missing.\n\n'
            'Run with SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}