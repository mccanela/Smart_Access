import 'package:flutter/material.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('404', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Oops! Page not found', style: TextStyle(fontSize: 20, color: Colors.grey)),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
              child: const Text('Return to Home'),
            ),
          ],
        ),
      ),
    );
  }
} 