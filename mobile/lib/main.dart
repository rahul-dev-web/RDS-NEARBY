import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase_config.dart';
import 'features/auth/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (hasSupabaseConfig) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabasePublishableKey,
    );
  }

  runApp(const RdsNearbyApp());
}

class RdsNearbyApp extends StatelessWidget {
  const RdsNearbyApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (!hasSupabaseConfig) {
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
