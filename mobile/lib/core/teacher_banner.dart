import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'portrait.dart';
import 'theme.dart';

/// Warm welcome banner with a fan of teacher portraits. Drops in above the search bar.
///
/// Pass real teachers' photos in [people]; if fewer than the banner needs, bundled illustrative portraits fill
/// the rest (and the banner says so). Mobile shows 3 portraits beside the text; wide screens show 5 and a CTA.
class TeacherBannerWidget extends StatefulWidget {
  const TeacherBannerWidget({
    super.key,
    this.people = const [],
    this.title = 'Trusted ustaads, right in your neighbourhood',
    this.subtitle = 'Verified teachers across Lahore',
    this.ctaLabel,
    this.onCta,
  });

  final List<PortraitSource> people;
  final String title;
  final String subtitle;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  State<TeacherBannerWidget> createState() => _TeacherBannerWidgetState();
}

class _TeacherBannerWidgetState extends State<TeacherBannerWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the system "reduce motion" setting.
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  List<PortraitSource> _fan(int n) {
    final real = widget.people.where((p) => (p.url ?? '').isNotEmpty || p.bytes != null).take(n).toList();
    return [...real, ...kBundledPortraits.take(math.max(0, n - real.length))];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 640;
      final n = wide ? 5 : 3;
      final d = wide ? 96.0 : 62.0;
      final step = d * .66;
      final fanW = step * (n - 1) + d;
      final fan = _fan(n);
      final illustrative = fan.any((p) => p.isBundled);

      final text = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(widget.title,
            maxLines: wide ? 3 : 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: wide ? 26 : 17, height: 1.15)),
        const SizedBox(height: 6),
        Text(widget.subtitle, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600, fontSize: 13)),
        if (wide && widget.ctaLabel != null) ...[
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.white, foregroundColor: AppColors.ink, side: const BorderSide(color: AppColors.ink, width: 2), minimumSize: const Size(0, 44)),
            onPressed: widget.onCta,
            child: Text(widget.ctaLabel!),
          ),
        ],
        if (illustrative)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Illustrative portraits', style: TextStyle(color: AppColors.ink, fontSize: 10.5)),
          ),
      ]);

      return Container(
        padding: EdgeInsets.symmetric(horizontal: wide ? 28 : 16, vertical: wide ? 24 : 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: AppColors.lime,
        ),
        child: Row(children: [
          Expanded(child: text),
          const SizedBox(width: 12),
          SizedBox(
            width: fanW,
            height: d + 14,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Stack(clipBehavior: Clip.none, children: [
                for (final (i, p) in fan.indexed)
                  Positioned(
                    left: i * step,
                    top: 7 + math.sin((_c.value * 2 * math.pi) + i * 1.1) * 5,
                    child: Container(
                      width: d,
                      height: d,
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                      child: ClipOval(child: TeacherPortrait(source: p, decodeWidth: (d * 3).round())),
                    ),
                  ),
              ]),
            ),
          ),
        ]),
      );
    });
  }
}
