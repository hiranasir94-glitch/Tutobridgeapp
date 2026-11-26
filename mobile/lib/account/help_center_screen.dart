import 'package:flutter/material.dart';

import '../core/theme.dart';

class _Faq {
  const _Faq(this.audience, this.q, this.a);
  final String audience; // Parents, Students or Teachers
  final String q;
  final String a;
}

const _faqs = [
  _Faq('Parents', 'How do I find a teacher near me?', 'Open Search. Teachers close to your saved location appear first, with an approximate distance. Use the search bar or the filters to narrow by subject, grade, curriculum or where the teaching happens.'),
  _Faq('Parents', 'What does Connect do?', 'Connect opens a private chat with that teacher so you can ask questions, share the grade and subject you need, and agree on a time before booking.'),
  _Faq('Parents', 'What is the difference between Connect and Book a Trial?', 'Connect is a conversation. Book a Trial sends the teacher a formal request with grade, subject, place and schedule. They can accept or decline it, and their contact details are shared only after they accept.'),
  _Faq('Parents', 'Where can the lessons happen?', 'At school, at your home, or at the teacher\'s home. Each teacher lists the places they offer.'),
  _Faq('Parents', 'Who can see my address and phone number?', 'Only a teacher who has accepted your request. Teachers you merely chat with cannot see them.'),
  _Faq('Students', 'Can a student use Tutobridge?', 'Students should use the app together with a parent or guardian, who creates the account, chats with teachers and books lessons.'),
  _Faq('Students', 'How do I know a teacher is safe?', 'Teachers show a Verified badge only after our team has reviewed their documents. We still recommend that a parent is at home for the first lesson.'),
  _Faq('Students', 'What is a Star Teacher?', 'A Star Teacher has a 4.8+ rating, many parent reviews and verified student results.'),
  _Faq('Teachers', 'How do I get verified?', 'Complete your profile and upload your CNIC and highest degree certificate. Your status shows as Pending until our team reviews them. Parents can find you once you are verified.'),
  _Faq('Teachers', 'How do I set my fees?', 'In your profile choose whether you charge per day or per month and enter the amount for home tuition. School positions use an expected monthly salary. You can change these any time from the dashboard.'),
  _Faq('Teachers', 'When do parents see my contact details?', 'Never before you accept a request. Your address is never shown to parents, only the neighbourhoods you cover.'),
  _Faq('Teachers', 'How do I pause new requests?', 'Switch off Accepting New Students on your dashboard. You will be hidden from search until you switch it back on.'),
  _Faq('Everyone', 'How do I change my address?', 'Open Account, then Address. Add a new address or pick a saved one and tap Use this address.'),
  _Faq('Everyone', 'How do I use my current location?', 'When entering an address, tap Use Current Location and allow location access. You can edit the label afterwards, or type it instead.'),
  _Faq('Everyone', 'How do subscriptions work?', 'Open Account, then Subscription to compare plans. The Free plan is always available. Paid plans are requested for now and activated by our team.'),
  _Faq('Everyone', 'How is payment handled?', 'Lesson fees are agreed and paid directly between parent and teacher. Tutobridge does not take payment for lessons.'),
];

/// Searchable, expandable FAQ grouped by who is asking.
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  static const _filters = ['All', 'Parents', 'Students', 'Teachers'];
  String _filter = 'All';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final shown = _faqs.where((f) {
      final audienceOk = _filter == 'All' || f.audience == _filter || f.audience == 'Everyone';
      final textOk = q.isEmpty || '${f.q} ${f.a}'.toLowerCase().contains(q);
      return audienceOk && textOk;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Help Center')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('How can we help?', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: const InputDecoration(hintText: 'Search questions...', prefixIcon: Icon(Icons.search_rounded)),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final f in _filters)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f == 'All' ? 'All' : 'For $f'),
                  selected: _filter == f,
                  labelStyle: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                  onSelected: (_) => setState(() => _filter = f),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 14),
        if (shown.isEmpty)
          const Padding(padding: EdgeInsets.all(32), child: Text('No answers match. Try different words.', textAlign: TextAlign.center))
        else
          for (final f in shown)
            Card(
              color: Colors.white,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.line, width: 1.5)),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  iconColor: AppColors.ink,
                  title: Text(f.q, style: const TextStyle(fontWeight: FontWeight.w800)),
                  children: [Text(f.a, style: const TextStyle(height: 1.4))],
                ),
              ),
            ),
      ]),
    );
  }
}
