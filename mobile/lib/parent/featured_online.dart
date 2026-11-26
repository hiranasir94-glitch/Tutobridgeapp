import 'package:flutter/material.dart';

import '../core/portrait.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../models/teacher_listing.dart';

/// "Featured Online Teachers": a horizontal carousel of verified teachers who teach online,
/// with teachers who are available right now shown first.
class FeaturedOnlineSection extends StatelessWidget {
  const FeaturedOnlineSection({super.key, required this.listings, required this.onConnect, required this.onSeeAll, this.connectingId});
  final List<TeacherListing> listings;
  final ValueChanged<TeacherListing> onConnect;
  final VoidCallback onSeeAll;
  final String? connectingId;

  @override
  Widget build(BuildContext context) {
    if (listings.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.videocam_rounded, color: AppColors.ink),
        const SizedBox(width: 6),
        const Expanded(child: Text('Featured Online Teachers', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
        TextButton(onPressed: onSeeAll, child: const Text('See all')),
      ]),
      SizedBox(
        height: 196,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: listings.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => _FeaturedCard(listing: listings[i], connecting: connectingId == listings[i].teacher.id, onConnect: () => onConnect(listings[i])),
        ),
      ),
    ]);
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.listing, required this.onConnect, required this.connecting});
  final TeacherListing listing;
  final VoidCallback onConnect;
  final bool connecting;

  @override
  Widget build(BuildContext context) {
    final t = listing.teacher;
    return Container(
      width: 190,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.isStar ? AppColors.ink : AppColors.line, width: t.isStar ? 2 : 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          TeacherAvatar(source: PortraitSource(name: listing.name, url: listing.avatarUrl), radius: 24, star: t.isStar),
          const Spacer(),
          if (t.reviewsCount > 0) Pill(t.ratingAvg.toStringAsFixed(1), color: AppColors.ink, background: AppColors.lime, icon: Icons.star_rounded),
        ]),
        const SizedBox(height: 8),
        Text(listing.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        Text(t.subjects.take(2).join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
        const SizedBox(height: 6),
        if (t.isImmediatelyAvailable)
          const Pill('Available Now', color: AppColors.ink, background: AppColors.lime, icon: Icons.circle)
        else
          const Pill('Online', icon: Icons.videocam_rounded),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(40), backgroundColor: AppColors.lime, foregroundColor: AppColors.ink),
            onPressed: connecting ? null : onConnect,
            child: connecting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink)) : const Text('Connect'),
          ),
        ),
      ]),
    );
  }
}
