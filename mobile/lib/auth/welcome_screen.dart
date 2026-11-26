import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/stickers.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'sign_in_screen.dart';
import 'sign_up_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.lime,
      body: Stack(children: [
        const Positioned(right: 24, top: 60, child: Floaty(seconds: 4, child: _Blob(120, AppColors.limeDark))),
        const Positioned(left: -20, top: 300, child: Floaty(seconds: 3, child: _Blob(70, AppColors.white))),
        const Positioned(right: 70, bottom: 250, child: Floaty(seconds: 5, child: _Blob(46, AppColors.limeDark))),
        const Positioned(right: 18, top: 70, child: Floaty(seconds: 5, child: Sticker('books', size: 84, angle: 8))),
        const Positioned(right: 110, top: 130, child: Floaty(seconds: 4, child: Sticker('bulb', size: 58, angle: -8))),
        const Positioned(right: 12, top: 250, child: Floaty(seconds: 6, child: Sticker('globe', size: 72, angle: -6))),
        const Positioned(right: 40, top: 390, child: Floaty(seconds: 5, child: Sticker('pencilcup', size: 64, angle: 6))),
        const Positioned(left: 14, top: 400, child: Floaty(seconds: 4, child: Sticker('apple', size: 58, angle: -10))),
        const Positioned(right: 130, bottom: 230, child: Floaty(seconds: 6, child: Sticker('backpack', size: 62, angle: 8))),
        const Positioned(left: 70, bottom: 250, child: Floaty(seconds: 5, child: Sticker('palette', size: 54, angle: -6))),
        const Positioned(left: 160, top: 74, child: Floaty(seconds: 3, child: Sticker('star', size: 30, angle: 10))),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Spacer(),
              const Floaty(child: LogoMark(size: 72)),
              const SizedBox(height: 20),
              Rise(child: Text('Tutobridge', style: text.headlineMedium!.copyWith(color: AppColors.ink, fontSize: 44))),
              const SizedBox(height: 8),
              Rise(
                delayMs: 100,
                child: Text('Find Trusted Tutors Near You in Lahore',
                    style: text.titleMedium!.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              Rise(
                delayMs: 200,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.white, foregroundColor: AppColors.ink, side: const BorderSide(color: AppColors.ink, width: 2)),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignInScreen())),
                  child: const Text('Log In'),
                ),
              ),
              const SizedBox(height: 12),
              Rise(
                delayMs: 300,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.white, foregroundColor: AppColors.ink, side: const BorderSide(color: AppColors.ink, width: 2)),
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const SignUpScreen(role: UserRole.parent))),
                  child: const Text('Sign Up as a Parent / Student'),
                ),
              ),
              const SizedBox(height: 12),
              Rise(
                delayMs: 400,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.ink, backgroundColor: Colors.transparent, side: const BorderSide(color: AppColors.ink, width: 2)),
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const SignUpScreen(role: UserRole.teacher))),
                  child: const Text('Register as a Teacher'),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob(this.size, this.color);
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
