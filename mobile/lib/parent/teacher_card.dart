import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/portrait.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../models/teacher_listing.dart';

/// Teacher card for the discovery board: picture, qualifications, modes, fee and a prominent Connect button.
IconData _modeIcon(TeachMode m) => switch (m) {
      TeachMode.online => Icons.videocam_rounded,
      TeachMode.homeAcademy => Icons.meeting_room_rounded,
      TeachMode.privateHome => Icons.home_rounded,
    };

class TeacherCard extends StatelessWidget {
  const TeacherCard({super.key, required this.listing, required this.onConnect, required this.onBook, this.connecting = false});
  final TeacherListing listing;
  final VoidCallback onConnect;
  final VoidCallback onBook;
  final bool connecting;

  @override
  Widget build(BuildContext context) {
    final t = listing.teacher;
    String pkr(double v) => 'PKR ${v.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: t.isStar ? AppColors.ink : AppColors.line, width: t.isStar ? 2 : 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TeacherAvatar(source: PortraitSource(name: listing.name, url: listing.avatarUrl), radius: 28, star: t.isStar),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(listing.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  if (t.isStar) const StarBadge(),
                  if (listing.isSample) const Pill('Sample', color: AppColors.muted, background: AppColors.line),
                ]),
                if (t.qualifications.isNotEmpty)
                  Text(t.qualifications.first, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 13)),
                Text('${t.subjects.take(3).join(', ')} · ${t.curricula.take(3).join(', ')}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                if (listing.distanceKm != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.near_me_rounded, size: 14, color: AppColors.ink),
                      const SizedBox(width: 4),
                      Text(listing.distanceKm! < 1 ? 'Under 1 km away' : 'About ${listing.distanceKm!.toStringAsFixed(listing.distanceKm! % 1 == 0 ? 0 : 1)} km away',
                          style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 12.5)),
                    ]),
                  ),
              ]),
            ),
            if (t.reviewsCount > 0)
              Pill('${t.ratingAvg.toStringAsFixed(1)} (${t.reviewsCount})',
                  color: AppColors.ink, background: AppColors.lime, icon: Icons.star_rounded),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (t.atSchool) Pill('At School · ~${pkr(t.monthlySalary ?? 0)}/mo'),
            for (final m in TeachMode.values)
              if (t.offers(m)) Pill(m.badge, icon: _modeIcon(m)),
            if (t.isImmediatelyAvailable)
              const Pill('Available Now', color: AppColors.ink, background: AppColors.lime, icon: Icons.circle),
            if (t.rateAmount != null && t.rateType != null)
              Pill('${pkr(t.rateAmount!)} per ${t.rateType!.unit}', color: AppColors.ink, background: AppColors.lime),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: onBook,
                child: const Text('Book a Trial'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: AppColors.lime, foregroundColor: AppColors.ink),
                onPressed: connecting ? null : onConnect,
                icon: connecting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.ink))
                    : const Icon(Icons.chat_rounded),
                label: const Text('Connect'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

