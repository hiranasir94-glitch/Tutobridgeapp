import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin/admin_dashboard_screen.dart';
import '../core/constants.dart';
import '../core/supabase.dart';
import '../core/theme.dart';
import '../models/app_profile.dart';
import '../models/teacher_profile.dart';
import '../parent/parent_home_screen.dart';
import '../tutor/tutor_dashboard_screen.dart';
import '../tutor/tutor_onboarding_screen.dart';
import 'reset_password_screen.dart';
import 'welcome_screen.dart';

/// Root of the app. Signed out: welcome screen. Signed in: [RoleRouter].
/// Because it listens to the auth stream, sign-in, sign-up, sign-out and a restored session all route here.
/// When the person opens a password-reset link, Supabase signs them in with a recovery session and emits
/// [AuthChangeEvent.passwordRecovery]; the gate then shows [ResetPasswordScreen] until the new password is saved.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _recovering = false;
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = supabase.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery && mounted) setState(() => _recovering = true);
      if (state.event == AuthChangeEvent.signedOut && _recovering && mounted) setState(() => _recovering = false);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, _) {
        final session = supabase.auth.currentSession;
        if (session == null) return const WelcomeScreen();
        if (_recovering) return ResetPasswordScreen(onDone: () => setState(() => _recovering = false));
        return RoleRouter(key: ValueKey(session.user.id));
      },
    );
  }
}

/// Reads the signed-in user's profiles.role and picks the screen.
class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  late Future<Widget> _screen = _resolve();

  void _reload() => setState(() => _screen = _resolve());

  Future<Widget> _resolve() async {
    // get_my_profile() is used because phone_number is not selectable straight from the table.
    final rows = await supabase.rpc('get_my_profile') as List;
    if (rows.isEmpty) throw StateError('Your profile was not found. Please sign out and sign up again.');
    final profile = AppProfile.fromMap(Map<String, dynamic>.from(rows.first as Map));

    switch (profile.role) {
      case UserRole.admin:
        return const AdminDashboardScreen();
      case UserRole.parent:
        return ParentHomeScreen(profile: profile);
      case UserRole.teacher:
        final row = await supabase.from('teacher_profiles').select().eq('id', profile.id).maybeSingle();
        final teacher = row == null ? null : TeacherProfile.fromMap(row);
        if (teacher == null || !teacher.isOnboardingComplete) {
          return TutorOnboardingScreen(profile: profile, existing: teacher, onCompleted: _reload);
        }
        return const TutorDashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _screen,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.ink)));
        }
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.ink),
                  const SizedBox(height: 12),
                  Text(errorText(snap.error!), textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: _reload, child: const Text('Try again')),
                  const SizedBox(height: 10),
                  OutlinedButton(onPressed: () => supabase.auth.signOut(), child: const Text('Sign out')),
                ]),
              ),
            ),
          );
        }
        return snap.data!;
      },
    );
  }
}
