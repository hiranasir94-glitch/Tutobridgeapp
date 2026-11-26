import 'package:flutter/material.dart';

import 'constants.dart';
import 'theme.dart';

/// Grouped multi-select for "Area of expertise". Shows the chosen categories as chips; tapping opens a sheet that lists
/// every category with the subjects it covers. Selection is a set of category slugs (see [kExpertise]).
class ExpertisePicker extends StatelessWidget {
  const ExpertisePicker({super.key, required this.selected, required this.onChanged});
  final Set<String> selected;
  final VoidCallback onChanged;

  Future<void> _open(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ExpertiseSheet(selected: selected),
    );
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _open(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Area of expertise',
          helperText: 'Choose every level or category you teach.',
          suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: selected.isEmpty
            ? const Text('Tap to choose', style: TextStyle(color: AppColors.muted))
            : Wrap(spacing: 6, runSpacing: 6, children: [
                for (final c in kExpertise)
                  if (selected.contains(c.slug)) Chip(label: Text(c.short, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)), visualDensity: VisualDensity.compact),
              ]),
      ),
    );
  }
}

class _ExpertiseSheet extends StatefulWidget {
  const _ExpertiseSheet({required this.selected});
  final Set<String> selected;

  @override
  State<_ExpertiseSheet> createState() => _ExpertiseSheetState();
}

class _ExpertiseSheetState extends State<_ExpertiseSheet> {
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .85,
      maxChildSize: .95,
      builder: (context, scroll) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Row(children: [
            Expanded(child: Text('Area of expertise', style: Theme.of(context).textTheme.titleLarge)),
            Text('${widget.selected.length} selected', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
          ]),
        ),
        Expanded(
          child: ListView(controller: scroll, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
            for (final c in kExpertise)
              CheckboxListTile(
                value: widget.selected.contains(c.slug),
                activeColor: AppColors.teal,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(c.label, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: c.hint == null ? null : Text(c.hint!),
                onChanged: (v) => setState(() => v == true ? widget.selected.add(c.slug) : widget.selected.remove(c.slug)),
              ),
          ]),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done'))),
          ),
        ),
      ]),
    );
  }
}
