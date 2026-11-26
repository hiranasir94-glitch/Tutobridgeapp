import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/env.dart';
import '../core/stickers.dart';
import '../core/supabase.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// Asks for the account email and has Supabase send a one-time reset link to it.
/// The link opens the app (deep link), AuthGate then shows [ResetPasswordScreen].
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});
  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _busy = false;
  String? _sentTo;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    final email = _email.text.trim();
    setState(() => _busy = true);
    try {
      await supabase.auth.resetPasswordForEmail(email, redirectTo: kIsWeb ? null : Env.resetRedirect);
      if (mounted) setState(() => _sentTo = email);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const Center(child: Sticker('bulb', size: 64, angle: -6)),
          const SizedBox(height: 12),
          if (_sentTo == null) ..._formBody() else ..._sent(),
        ]),
      ),
    );
  }

  List<Widget> _formBody() => [
        Text('Forgot your password?', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text(
          'Enter the email address you signed up with. We will send you a link to choose a new password.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 22),
        Form(
          key: _form,
          child: Column(children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) => (v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) ? 'Enter a valid email address' : null,
              onFieldSubmitted: (_) => _send(),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _busy ? null : _send,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.ink))
                  : const Text('Send reset link'),
            ),
          ]),
        ),
      ];

  List<Widget> _sent() => [
        Text('Check your email', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 10),
        // The wording does not confirm whether the address has an account, so it cannot be used to probe for users.
        Text(
          'If there is an account for $_sentTo, a reset link is on its way. Open it on this phone to choose a new password. '
          'The link works once and expires after an hour.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, height: 1.4),
        ),
        const SizedBox(height: 22),
        OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back to log in')),
        TextButton(onPressed: () => setState(() => _sentTo = null), child: const Text('Use a different email')),
      ];
}
