import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  runApp(const RdsNearbyApp());
}

class RdsNearbyApp extends StatelessWidget {
  const RdsNearbyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RDS Nearby',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const FoundationScreen(),
    );
  }
}

class FoundationScreen extends StatelessWidget {
  const FoundationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final connected = supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('RDS Nearby')),
      body: Center(
        child: Text(
          connected
              ? 'Foundation ready\nSupabase configuration loaded'
              : 'Foundation ready\nRun with SUPABASE_URL and SUPABASE_ANON_KEY',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
