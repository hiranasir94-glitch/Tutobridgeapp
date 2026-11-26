import 'package:flutter/material.dart';

import '../core/location_field.dart';
import '../core/supabase.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../models/app_profile.dart';
import 'account_widgets.dart';

class _Saved {
  _Saved(Map<String, dynamic> m)
      : id = m['id'] as String,
        label = (m['label'] as String?) ?? 'Address',
        address = (m['address'] as String?) ?? '',
        locationLabel = m['location_label'] as String?,
        lat = (m['lat'] as num?)?.toDouble(),
        lng = (m['lng'] as num?)?.toDouble();
  final String id;
  final String label;
  final String address;
  final String? locationLabel;
  final double? lat;
  final double? lng;
}

/// View and change the current address, keep a list of saved ones, and switch between them.
/// The current address is the one on the user's profile (what teachers see after accepting a request).
class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  static const _labels = ['Home', 'Work', 'Other'];

  final _form = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _loc = LocationInput();
  String _label = 'Home';
  bool _makeCurrent = true;
  bool _saving = false;

  AppProfile? _me;
  List<_Saved> _saved = const [];
  bool _loading = true;
  String? _error;
  String? _switchingId;

  String get _uid => supabase.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _address.dispose();
    _loc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final me = AppProfile.fromMap(Map<String, dynamic>.from(((await supabase.rpc('get_my_profile')) as List).first as Map));
      var rows = (await supabase.from('saved_addresses').select().order('created_at', ascending: false) as List)
          .map((r) => _Saved(Map<String, dynamic>.from(r as Map)))
          .toList();

      // The address given at sign-up lives only on the profile; add it to the saved list once.
      final current = (me.address ?? '').trim();
      if (current.length >= 8 && !rows.any((s) => s.address.trim() == current)) {
        await supabase.from('saved_addresses').insert({
          'user_id': _uid,
          'label': 'Registered address',
          'address': current,
          'location_label': me.locationLabel,
          'lat': me.lat,
          'lng': me.lng,
        });
        rows = (await supabase.from('saved_addresses').select().order('created_at', ascending: false) as List)
            .map((r) => _Saved(Map<String, dynamic>.from(r as Map)))
            .toList();
      }
      if (mounted) setState(() { _me = me; _saved = rows; _loading = false; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _error = errorText(e); _loading = false; });
    }
  }

  bool _isCurrent(_Saved s) => s.address.trim() == (_me?.address ?? '').trim();

  Future<void> _useSaved(_Saved s) async {
    setState(() => _switchingId = s.id);
    try {
      await supabase.rpc('use_saved_address', params: {'p_id': s.id});
      await _load();
      if (mounted) showSnack(context, '${s.label} is now your current address.');
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _switchingId = null);
    }
  }

  Future<void> _delete(_Saved s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this address?'),
        content: Text(s.address),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44), backgroundColor: AppColors.white, foregroundColor: AppColors.ink, side: const BorderSide(color: AppColors.ink, width: 2)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await supabase.from('saved_addresses').delete().eq('id', s.id);
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final row = await supabase
          .from('saved_addresses')
          .insert({
            'user_id': _uid,
            'label': _label,
            'address': _address.text.trim(),
            'location_label': _loc.text,
            'lat': _loc.lat,
            'lng': _loc.lng,
          })
          .select('id')
          .single();
      if (_makeCurrent) await supabase.rpc('use_saved_address', params: {'p_id': row['id']});
      _address.clear();
      _loc.label.clear(); // reuse the same controller; replacing it while the field is on screen is unsafe
      _loc.lat = null;
      _loc.lng = null;
      await _load();
      if (mounted) showSnack(context, _makeCurrent ? 'Saved and set as your current address.' : 'Address saved.');
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    return Scaffold(
      appBar: AppBar(title: const Text('Address')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.ink))
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  const SectionTitle('Current address'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.limeLight, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.ink, width: 2)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.home_rounded, color: AppColors.ink),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text((me?.address ?? '').isEmpty ? 'No address saved yet' : me!.address!, style: const TextStyle(fontWeight: FontWeight.w800)),
                          if ((me?.locationLabel ?? '').isNotEmpty)
                            Text('Near ${me!.locationLabel!}', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  const SectionTitle('Saved addresses'),
                  if (_saved.isEmpty)
                    const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Nothing saved yet. Add one below.', style: TextStyle(color: AppColors.muted)))
                  else
                    for (final s in _saved)
                      Card(
                        color: Colors.white,
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: _isCurrent(s) ? AppColors.ink : AppColors.line, width: 1.5)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Pill(s.label),
                              const SizedBox(width: 8),
                              if (_isCurrent(s)) const Pill('Current', color: AppColors.ink, background: AppColors.lime, icon: Icons.check_rounded),
                              const Spacer(),
                              IconButton(tooltip: 'Remove', onPressed: () => _delete(s), icon: const Icon(Icons.delete_outline_rounded, color: AppColors.ink)),
                            ]),
                            Text(s.address, style: const TextStyle(fontWeight: FontWeight.w700)),
                            if ((s.locationLabel ?? '').isNotEmpty) Text('Near ${s.locationLabel!}', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                            if (!_isCurrent(s)) ...[
                              const SizedBox(height: 10),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                                onPressed: _switchingId == null ? () => _useSaved(s) : null,
                                child: _switchingId == s.id
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                                    : const Text('Use this address'),
                              ),
                            ],
                          ]),
                        ),
                      ),
                  const SizedBox(height: 14),
                  const SectionTitle('Add a new address'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.line, width: 1.5)),
                    child: Form(
                      key: _form,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Wrap(spacing: 8, children: [
                          for (final l in _labels)
                            ChoiceChip(
                              label: Text(l),
                              selected: _label == l,
                              labelStyle: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                              onSelected: (_) => setState(() => _label = l),
                            ),
                        ]),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _address,
                          textCapitalization: TextCapitalization.words,
                          keyboardType: TextInputType.streetAddress,
                          minLines: 2,
                          maxLines: 3,
                          maxLength: 300,
                          decoration: const InputDecoration(labelText: 'Address', hintText: 'House, street, area, city', alignLabelWithHint: true),
                          validator: (v) => (v == null || v.trim().length < 8) ? 'Enter the full address' : null,
                        ),
                        const SizedBox(height: 8),
                        LocationField(input: _loc, label: 'Location for this address'),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Make this my current address', style: TextStyle(fontWeight: FontWeight.w700)),
                          value: _makeCurrent,
                          onChanged: (v) => setState(() => _makeCurrent = v),
                        ),
                        const SizedBox(height: 6),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.ink))
                              : const Text('Save address'),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),
                ]),
    );
  }
}
