import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/stickers.dart';
import '../core/supabase.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// Shown after the person opens the reset link from their email. Supabase has already signed them in
/// with a short-lived recovery session, so all that is left is to set the new password.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.onDone});

  /// Called once the password was changed (the person stays signed in) or the reset was cancelled.
  final VoidCallback onDone;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await supabase.auth.updateUser(UserAttributes(password: _password.text));
      if (!mounted) return;
      showSnack(context, 'Password updated. You are logged in.');
      widget.onDone();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    await supabase.auth.signOut();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New password'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Sticker('pencil', size: 52, angle: -8),
            SizedBox(width: 14),
            LogoMark(size: 64),
            SizedBox(width: 14),
            Sticker('star', size: 44, angle: 8),
          ]),
          const SizedBox(height: 16),
          Text('Choose a new password', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text('Use at least 6 characters.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 22),
          Form(
            key: _form,
            child: Column(children: [
              TextFormField(
                controller: _password,
                obscureText: _hide,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'New password',
                  suffixIcon: IconButton(
                    icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
                validator: (v) => (v == null || v.length < 6) ? 'Use at least 6 characters' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirm,
                obscureText: _hide,
                decoration: const InputDecoration(labelText: 'Confirm new password'),
                validator: (v) => v != _password.text ? 'The passwords do not match' : null,
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.ink))
                    : const Text('Save new password'),
              ),
              TextButton(onPressed: _busy ? null : _cancel, child: const Text('Cancel')),
            ]),
          ),
        ]),
      ),
    );
  }
}
