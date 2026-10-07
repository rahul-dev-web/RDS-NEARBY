import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'phone_auth_screen.dart';
import 'profile_setup_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (client.auth.currentSession == null) return const PhoneAuthScreen();
        return FutureBuilder<Map<String, dynamic>?>(
          future: AuthService(client).getProfile(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (profileSnapshot.hasError) {
              return Scaffold(body: Center(child: Text(profileSnapshot.error.toString())));
            }
            final profile = profileSnapshot.data;
            final name = profile?['name']?.toString().trim() ?? '';
            final role = profile?['role']?.toString() ?? 'customer';
            if (name.isEmpty) return const ProfileSetupScreen();
            if (role == 'merchant') return const MerchantHomeScreen();
            return const CustomerHomeScreen();
          },
        );
      },
    );
  }
}

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});
  @override
  Widget build(BuildContext context) => const ModeHomeScreen(
    title: 'Nearby', subtitle: 'Search for what you need around you.', mode: 'Customer',
  );
}

class MerchantHomeScreen extends StatelessWidget {
  const MerchantHomeScreen({super.key});
  @override
  Widget build(BuildContext context) => const ModeHomeScreen(
    title: 'Merchant', subtitle: 'Your business workspace starts here.', mode: 'Merchant',
  );
}

class ModeHomeScreen extends StatelessWidget {
  const ModeHomeScreen({required this.title, required this.subtitle, required this.mode, super.key});
  final String title, subtitle, mode;
  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: [
        IconButton(onPressed: () => client.auth.signOut(), icon: const Icon(Icons.logout)),
      ]),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(mode, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(subtitle),
          const SizedBox(height: 24),
          const Card(child: ListTile(
            leading: Icon(Icons.location_on_outlined),
            title: Text('Local discovery'),
            subtitle: Text('Discovery and business onboarding are next.'),
          )),
        ]),
      ),
    );
  }
}
