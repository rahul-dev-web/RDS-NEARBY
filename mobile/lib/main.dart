import 'package:flutter/material.dart';

void main() {
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
    return Scaffold(
      appBar: AppBar(title: const Text('RDS Nearby')),
      body: const Center(
        child: Text(
          'Foundation ready\nCustomer + Merchant app shell',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
