import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';

/// The filters on the Search screen. [modes] and [cats] use "overlaps" semantics on the database arrays:
/// a teacher matches when they have ANY of the chosen modes (or categories).
class SearchFilters {
  final Set<TeachMode> modes = {};
  final Set<String> cats = {}; // expertise slugs
  bool school = false; // legacy "At School" posts
  bool nowOnly = false; // is_immediately_available = true

  bool get any => modes.isNotEmpty || cats.isNotEmpty || school || nowOnly;

  void clear() {
    modes.clear();
    cats.clear();
    school = false;
    nowOnly = false;
  }

  /// True when [cats] is exactly the slugs of [q] (used to highlight a quick category chip).
  bool isQuick(QuickCategory q) => cats.length == q.slugs.length && cats.containsAll(q.slugs);
}

/// Quick-tap category pills shown on the home page. Tapping one filters the results straight away.
class QuickCategoryRow extends StatelessWidget {
  const QuickCategoryRow({super.key, required this.filters, required this.onPick});
  final SearchFilters filters;
  final ValueChanged<QuickCategory> onPick;

  static const _icons = <String, IconData>{
    'Early Years': Icons.child_care_rounded,
    'Primary': Icons.backpack_rounded,
    'Middle School': Icons.menu_book_rounded,
    'O / A Levels': Icons.school_rounded,
    'Aitchison Prep': Icons.account_balance_rounded,
    'Quran / Nazra': Icons.auto_stories_rounded,
    'Test Prep': Icons.edit_note_rounded,
    'Sports': Icons.sports_soccer_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kQuickCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final q = kQuickCategories[i];
          final on = filters.isQuick(q);
          return ActionChip(
            avatar: Icon(_icons[q.label] ?? Icons.category_rounded, size: 18, color: AppColors.ink),
            label: Text(q.label),
            backgroundColor: on ? AppColors.lime : AppColors.white,
            side: BorderSide(color: on ? AppColors.ink : AppColors.line, width: on ? 2 : 1.5),
            labelStyle: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
            onPressed: () => onPick(q),
          );
        },
      ),
    );
  }
}

/// Teaching mode, "Available Now" and grade level / specialty filters.
class SearchFilterBar extends StatelessWidget {
  const SearchFilterBar({super.key, required this.filters, required this.onChanged});
  final SearchFilters filters;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    void change(VoidCallback f) {
      f();
      onChanged();
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: const Icon(Icons.circle, size: 11, color: AppColors.ink),
              label: const Text('Available Now'),
              selected: filters.nowOnly,
              selectedColor: AppColors.lime,
              checkmarkColor: AppColors.ink,
              labelStyle: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
              onSelected: (v) => change(() => filters.nowOnly = v),
            ),
          ),
          for (final m in TeachMode.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(m.label),
                selected: filters.modes.contains(m),
                selectedColor: AppColors.lime,
                checkmarkColor: AppColors.ink,
                labelStyle: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                onSelected: (v) => change(() => v ? filters.modes.add(m) : filters.modes.remove(m)),
              ),
            ),
          FilterChip(
            label: const Text('At School'),
            selected: filters.school,
            selectedColor: AppColors.lime,
            checkmarkColor: AppColors.ink,
            labelStyle: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
            onSelected: (v) => change(() => filters.school = v),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      const Text('Grade level / specialty', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.muted)),
      const SizedBox(height: 6),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final c in kExpertise)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(c.short),
                selected: filters.cats.contains(c.slug),
                selectedColor: AppColors.lime,
                checkmarkColor: AppColors.ink,
                labelStyle: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                onSelected: (v) => change(() => v ? filters.cats.add(c.slug) : filters.cats.remove(c.slug)),
              ),
            ),
        ]),
      ),
      if (filters.any)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => change(filters.clear),
            icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
            label: const Text('Clear filters'),
          ),
        ),
    ]);
  }
}
