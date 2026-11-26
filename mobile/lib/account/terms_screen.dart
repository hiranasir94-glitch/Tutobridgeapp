import 'package:flutter/material.dart';

import '../core/theme.dart';

// TODO before launch: have a lawyer review this text and replace the contact address with a real, monitored one.
const kSupportEmail = 'support@tutobridge.com';
const _updated = 'Last updated: 26 November 2026';

class _Section {
  const _Section(this.title, this.body);
  final String title;
  final String body;
}

const _terms = [
  _Section('1. About Tutobridge', 'Tutobridge helps parents and students in Lahore find and contact tutors and teachers. We provide the platform; the lessons themselves are agreed between you and the teacher.'),
  _Section('2. Accounts', 'You must give accurate information and keep your password private. Parents and guardians create accounts for children. You are responsible for activity under your account.'),
  _Section('3. Teachers', 'Teachers must provide truthful qualifications and documents. A Verified badge means we reviewed the documents supplied, not that we guarantee any teacher\'s performance or conduct. We may refuse or remove a teacher at any time.'),
  _Section('4. Lessons and payments', 'Parents and teachers agree the schedule, place and fee between themselves. Tutobridge does not collect payment for lessons and is not a party to that agreement. Subscription plans, where offered, are described on the Subscription screen.'),
  _Section('5. Safety', 'Meet in a safe place, keep a responsible adult nearby for children\'s lessons, and report anything concerning to us straight away. Do not share passwords or financial details in chat.'),
  _Section('6. Messages and conduct', 'Be respectful. Do not harass, threaten, spam or mislead anyone, and do not use the app for anything unlawful. We may limit or close accounts that break these rules.'),
  _Section('7. Our responsibility', 'We work to keep the service available and accurate but provide it as is. To the extent the law allows, we are not liable for lessons, advice, or losses arising between users.'),
  _Section('8. Changes', 'We may update these terms. If a change is significant we will tell you in the app. Continuing to use Tutobridge means you accept the updated terms.'),
];

const _privacy = [
  _Section('What we collect', 'Your name, phone number, email and password; addresses and location you enter or capture; for teachers, qualifications, experience, fees, a profile photo and verification documents (CNIC and degree); messages you send; booking requests; and your chosen subscription plan.'),
  _Section('How we use it', 'To create your account, show teachers near you, let you chat and book, verify teachers, provide support, keep the service safe, and improve the app.'),
  _Section('Location', 'We use your location only when you tap Use Current Location or save an address. It is used to sort teachers by approximate distance. Other users never see your exact coordinates.'),
  _Section('Who can see what', 'Teachers see a parent\'s phone number, address and location only after accepting that parent\'s request. Parents never see a teacher\'s address or exact location, only the neighbourhoods they cover and an approximate distance. Messages are visible only to the two people in the conversation. Verification documents are private to the teacher and our review team.'),
  _Section('Sharing', 'We do not sell your personal data. We use trusted service providers, such as our hosting and database provider, to run the app. We may disclose information if the law requires it or to protect someone\'s safety.'),
  _Section('Keeping and deleting data', 'We keep your data while your account is active. You can ask us to delete your account and data at any time using the contact below, and you can remove saved addresses yourself in the app.'),
  _Section('Children', 'Accounts for children are created and managed by a parent or guardian.'),
  _Section('Contact', 'Questions or requests about your data: $kSupportEmail'),
];

/// Terms of Service and Privacy Policy in two tabs.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Terms and Policies'),
          bottom: const TabBar(
            labelColor: AppColors.teal,
            indicatorColor: AppColors.teal,
            labelStyle: TextStyle(fontWeight: FontWeight.w800),
            tabs: [Tab(text: 'Terms of Service'), Tab(text: 'Privacy Policy')],
          ),
        ),
        body: const TabBarView(children: [
          _Document(title: 'Terms of Service', sections: _terms),
          _Document(title: 'Privacy Policy', sections: _privacy),
        ]),
      ),
    );
  }
}

class _Document extends StatelessWidget {
  const _Document({required this.title, required this.sections});
  final String title;
  final List<_Section> sections;

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 4),
      const Text(_updated, style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
      const SizedBox(height: 16),
      for (final s in sections) ...[
        Text(s.title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(s.body, style: const TextStyle(height: 1.45)),
        const SizedBox(height: 18),
      ],
    ]);
  }
}
