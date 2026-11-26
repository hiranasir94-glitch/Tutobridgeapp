import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'portrait.dart';
import 'supabase.dart';
import 'theme.dart';

/// Slides and fades a child in. Gives screens the lively, young feel.
class Rise extends StatelessWidget {
  const Rise({super.key, required this.child, this.delayMs = 0});
  final Widget child;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + delayMs),
      curve: Curves.easeOutBack,
      builder: (context, v, c) => Transform.translate(
        offset: Offset(0, (1 - v) * 28),
        child: Opacity(opacity: v.clamp(0.0, 1.0), child: c),
      ),
      child: child,
    );
  }
}

/// Gently floats a child up and down.
class Floaty extends StatefulWidget {
  const Floaty({super.key, required this.child, this.seconds = 3});
  final Widget child;
  final int seconds;

  @override
  State<Floaty> createState() => _FloatyState();
}

class _FloatyState extends State<Floaty> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Duration(seconds: widget.seconds))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      builder: (context, child) => Transform.translate(offset: Offset(0, -12 * _c.value), child: child),
      child: widget.child,
    );
  }
}

class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(size * .28)),
      child: Icon(Icons.school_rounded, color: AppColors.teal, size: size * .6),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = AppColors.teal, this.background = AppColors.tealLight, this.icon});
  final String text;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
        Flexible(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12))),
      ]),
    );
  }
}

class StarBadge extends StatelessWidget {
  const StarBadge({super.key});
  @override
  Widget build(BuildContext context) =>
      const Pill('Star Teacher', color: Color(0xFF422006), background: AppColors.sun, icon: Icons.star_rounded);
}

/// Kept for existing call sites; now backed by [TeacherAvatar] so every avatar gets the fade-in and fallback.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.url, this.bytes, this.radius = 30, this.star = false});
  final String name;
  final String? url;
  final dynamic bytes; // Uint8List?
  final double radius;
  final bool star;

  @override
  Widget build(BuildContext context) => TeacherAvatar(
        source: PortraitSource(name: name, url: url, bytes: bytes as Uint8List?),
        radius: radius,
        star: star,
      );
}

/// Asks "Log out?" and signs out on yes. AuthGate then returns to the welcome screen.
Future<void> confirmSignOut(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text('You will need to sign in again to use Tutobridge.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(110, 44), backgroundColor: AppColors.coral),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Log out'),
        ),
      ],
    ),
  );
  if (ok == true) await supabase.auth.signOut();
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.coral : AppColors.tealDark,
      behavior: SnackBarBehavior.floating,
    ));
}
