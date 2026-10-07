import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'phone_auth_screen.dart';
import 'profile_setup_screen.dart';
import '../merchant/merchant_onboarding_screen.dart';
import '../merchant/merchant_catalog_screen.dart';

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
            if (profileSnapshot.hasError) return Scaffold(body: Center(child: Text(profileSnapshot.error.toString())));
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
    title: 'Nearby',
    subtitle: 'Search for what you need around you.',
    mode: 'Customer',
  );
}

class MerchantHomeScreen extends StatelessWidget {
  const MerchantHomeScreen({super.key});

  Future<List<Map<String, dynamic>>> _businesses() =>
      AuthService(Supabase.instance.client).getMyBusinesses();

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Merchant'),
        actions: [
          IconButton(onPressed: () => client.auth.signOut(), icon: const Icon(Icons.logout)),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _businesses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));

          final businesses = snapshot.data ?? [];
          if (businesses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storefront_outlined, size: 56),
                    const SizedBox(height: 16),
                    const Text('Create your first business', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Add your shop details, category and location to start building your public profile.', textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MerchantOnboardingScreen()),
                      ),
                      icon: const Icon(Icons.add_business),
                      label: const Text('Create business'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Your businesses', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...businesses.map((business) => Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.store)),
                  title: Text(business['name']?.toString() ?? 'Business'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) { if (value == 'catalog') Navigator.of(context).push(MaterialPageRoute(builder: (_) => MerchantCatalogScreen(businessId: business['id'].toString(), businessName: business['name']?.toString() ?? 'Business'))); },
                    itemBuilder: (_) => const [PopupMenuItem(value: 'catalog', child: Text('Products & Services'))],
                  ),
                  subtitle: Text(
                    (business['status']?.toString() ?? 'pending') +
                    ' · ' +
                    (business['verification_status']?.toString() ?? 'pending'),
                  ),
                ),
              )),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MerchantOnboardingScreen()),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add another business'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ModeHomeScreen extends StatelessWidget {
  const ModeHomeScreen({required this.title, required this.subtitle, required this.mode, super.key});
  final String title;
  final String subtitle;
  final String mode;

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [IconButton(onPressed: () => client.auth.signOut(), icon: const Icon(Icons.logout))],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mode, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(subtitle),
            const SizedBox(height: 24),
            const Card(
              child: ListTile(
                leading: Icon(Icons.location_on_outlined),
                title: Text('Local discovery'),
                subtitle: Text('Customer discovery is the next layer after merchant onboarding.'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
