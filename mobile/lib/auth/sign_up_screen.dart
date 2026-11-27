import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/location_field.dart';
import '../core/supabase.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// One screen for both sign-ups. The role travels in the sign-up metadata, and the database trigger
/// handle_new_user copies it (plus name and phone) into public.profiles.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, required this.role});
  final UserRole role;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _loc = LocationInput();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;

  bool get _isTeacher => widget.role == UserRole.teacher;

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _email, _password]) {
      c.dispose();
    }
    _loc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final res = await supabase.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
        data: {
          'role': widget.role.db,
          'full_name': _name.text.trim(),
          'phone_number': _phone.text.trim(),
          // Copied into public.profiles by the handle_new_user trigger. A teacher's "current address" uses the same column.
          'address': _address.text.trim(),
          'current_location_label': _loc.text,
          if (_loc.hasCoords) 'current_lat': _loc.lat,
          if (_loc.hasCoords) 'current_lng': _loc.lng,
        },
      );
      if (!mounted) return;
      if (res.session == null) {
        // The project requires email confirmation before a session exists.
        showSnack(context, 'Check your email to confirm your account, then sign in.');
        Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isTeacher ? 'Register as a Teacher' : 'Parent / Student Sign Up')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text(
            _isTeacher ? 'Create your teacher account. You will add your subjects and rates next.' : 'Create an account to find teachers near you.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Form(
            key: _form,
            child: Column(children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your name' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: InputDecoration(labelText: _isTeacher ? 'Phone / WhatsApp number' : 'Phone number', hintText: '03XX XXXXXXX'),
                validator: (v) => (v == null || !isValidPkMobile(v)) ? 'Enter a Pakistani mobile number like 0300 1234567' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _address,
                textCapitalization: TextCapitalization.words,
                keyboardType: TextInputType.streetAddress,
                autofillHints: const [AutofillHints.fullStreetAddress],
                minLines: 2,
                maxLines: 3,
                maxLength: 300,
                decoration: InputDecoration(
                  labelText: _isTeacher ? 'Current Address' : 'Residential / Street Address',
                  hintText: 'House, street, area, city',
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().length < 8) ? 'Enter your full address' : null,
              ),
              const SizedBox(height: 14),
              LocationField(input: _loc, label: 'Current location'),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => (v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) ? 'Enter a valid email address' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _hide,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: 'At least 6 characters',
                  suffixIcon: IconButton(
                    icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
                validator: (v) => (v == null || v.length < 6) ? 'Use at least 6 characters' : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.ink))
                    : Text(_isTeacher ? 'Create Teacher Account' : 'Create Account'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
