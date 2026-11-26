import 'package:flutter/material.dart';

import '../core/plans.dart';
import '../core/supabase.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../models/app_profile.dart';

/// Membership plans with a feature list for each. There is no payment provider yet: choosing the free plan
/// switches immediately; choosing a paid plan records a request and shows it as "Requested".
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String? _planId;
  String _status = 'active';
  bool _loading = true;
  String? _busyId;
  String? _error;

  List<Plan> get _plans => plansFor(widget.profile.role);
  String get _freeId => _plans.firstWhere((p) => p.isFree).id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final row = await supabase.from('subscriptions').select('plan_id, status').maybeSingle();
      if (mounted) {
        setState(() {
          _planId = (row?['plan_id'] as String?) ?? _freeId;
          _status = (row?['status'] as String?) ?? 'active';
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = errorText(e); _loading = false; });
    }
  }

  Future<void> _select(Plan p) async {
    if (!p.isFree) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Request the ${p.name} plan?'),
          content: Text('${p.priceLabel}\n\nOnline payment is not available yet. We will record your request and contact you to activate it. You will not be charged now.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
            FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(120, 44)), onPressed: () => Navigator.pop(ctx, true), child: const Text('Request plan')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _busyId = p.id);
    try {
      await supabase.from('subscriptions').upsert({'user_id': supabase.auth.currentUser!.id, 'plan_id': p.id}, onConflict: 'user_id');
      await _load();
      if (mounted) showSnack(context, p.isFree ? 'You are on the Free plan.' : '${p.name} plan requested. We will be in touch.');
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.ink))
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  Text('Choose a plan', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  const Text('Upgrade or switch any time.', style: TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 16),
                  for (final p in _plans)
                    PlanCard(
                      plan: p,
                      isCurrent: p.id == _planId && _status == 'active',
                      isRequested: p.id == _planId && _status == 'pending_payment',
                      busy: _busyId == p.id,
                      onSelect: () => _select(p),
                    ),
                ]),
    );
  }
}

/// One pricing tier with its feature breakdown and a selection button.
class PlanCard extends StatelessWidget {
  const PlanCard({super.key, required this.plan, required this.isCurrent, required this.isRequested, required this.busy, required this.onSelect});
  final Plan plan;
  final bool isCurrent;
  final bool isRequested;
  final bool busy;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final highlight = plan.popular || isCurrent;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isCurrent ? AppColors.ink : (plan.popular ? AppColors.ink : AppColors.line), width: highlight ? 2.5 : 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(plan.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(width: 10),
          if (isCurrent) const Pill('Your plan', color: AppColors.ink, background: AppColors.lime, icon: Icons.check_rounded),
          if (isRequested) const Pill('Requested', color: AppColors.ink, background: AppColors.lime, icon: Icons.hourglass_top_rounded),
          if (plan.popular && !isCurrent && !isRequested) const Pill('Most popular', color: AppColors.ink, background: AppColors.lime, icon: Icons.star_rounded),
        ]),
        const SizedBox(height: 4),
        Text(plan.priceLabel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.ink)),
        const SizedBox(height: 4),
        Text(plan.tagline, style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 12),
        for (final f in plan.features)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.check_circle_rounded, size: 20, color: AppColors.ink),
              const SizedBox(width: 8),
              Expanded(child: Text(f)),
            ]),
          ),
        const SizedBox(height: 10),
        if (isCurrent)
          const OutlinedButton(onPressed: null, child: Text('Current plan'))
        else
          FilledButton(
            onPressed: (busy || isRequested) ? null : onSelect,
            child: busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.ink))
                : Text(isRequested ? 'Request received' : (plan.isFree ? 'Switch to Free' : 'Select ${plan.name}')),
          ),
      ]),
    );
  }
}
