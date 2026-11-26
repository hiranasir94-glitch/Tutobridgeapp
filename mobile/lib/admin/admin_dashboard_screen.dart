import 'package:flutter/material.dart';

import '../core/supabase.dart';
import '../core/theme.dart';

/// Placeholder. Admins review teachers (verification_status, is_star_teacher) here in a later step.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [IconButton(tooltip: 'Sign out', onPressed: () => supabase.auth.signOut(), icon: const Icon(Icons.logout_rounded))],
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.admin_panel_settings_rounded, size: 64, color: AppColors.teal),
            SizedBox(height: 16),
            Text('Admin dashboard coming soon', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text('Teacher verification and Star Teacher review will live here.', textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}
