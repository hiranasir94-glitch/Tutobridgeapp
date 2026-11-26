import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Someone to show in a portrait slot. Give any of [bytes], [url] (Supabase Storage or any https image) or
/// [asset] (a bundled file). Priority is bytes, then url, then asset; initials show when none loads.
class PortraitSource {
  const PortraitSource({required this.name, this.url, this.asset, this.bytes});
  final String name;
  final String? url;
  final String? asset;
  final Uint8List? bytes;

  bool get isBundled => bytes == null && (url == null || url!.isEmpty) && asset != null;
}

/// Illustrative portraits bundled with the app (drop your files into assets/teachers/, see SETUP.md).
/// They are generic and are NOT any specific teacher, so the banner labels them as illustrative.
const kBundledPortraits = <PortraitSource>[
  PortraitSource(name: 'Ayesha K', asset: 'assets/teachers/teacher_1.jpg'),
  PortraitSource(name: 'Bilal R', asset: 'assets/teachers/teacher_2.jpg'),
  PortraitSource(name: 'Sana M', asset: 'assets/teachers/teacher_3.jpg'),
  PortraitSource(name: 'Hamza T', asset: 'assets/teachers/teacher_4.jpg'),
  PortraitSource(name: 'Noor F', asset: 'assets/teachers/teacher_5.jpg'),
];

String initialsOf(String name) =>
    name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();

/// The one image widget everything else builds on. It always paints the initials placeholder first and fades
/// the picture in over it once decoded, so a slow or broken image never leaves a hole and never pops in.
/// Fills its parent; wrap it in [AspectRatio] (or use [aspectRatio]) to control the shape.
class TeacherPortrait extends StatelessWidget {
  const TeacherPortrait({
    super.key,
    required this.source,
    this.aspectRatio,
    this.fit = BoxFit.cover,
    this.focus = const Alignment(0, -0.35), // keeps faces in frame when a tall photo is cropped
    this.decodeWidth = 600,
  });

  final PortraitSource source;
  final double? aspectRatio;
  final BoxFit fit;
  final Alignment focus;
  final int decodeWidth; // decode at roughly display size to save memory

  @override
  Widget build(BuildContext context) {
    final img = _image();
    final body = Stack(fit: StackFit.expand, children: [
      _Placeholder(name: source.name),
      if (img != null) img,
    ]);
    return aspectRatio == null ? body : AspectRatio(aspectRatio: aspectRatio!, child: body);
  }

  Widget? _image() {
    Widget fade(BuildContext c, Widget child, int? frame, bool sync) =>
        sync ? child : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 450), curve: Curves.easeOut, child: child);
    Widget gone(BuildContext c, Object e, StackTrace? s) => const SizedBox.shrink();

    if (source.bytes != null) {
      return Image.memory(source.bytes!, fit: fit, alignment: focus, frameBuilder: fade, errorBuilder: gone);
    }
    if (source.url != null && source.url!.isNotEmpty) {
      return Image.network(source.url!, fit: fit, alignment: focus, cacheWidth: decodeWidth, frameBuilder: fade, errorBuilder: gone);
    }
    if (source.asset != null) {
      return Image.asset(source.asset!, fit: fit, alignment: focus, cacheWidth: decodeWidth, frameBuilder: fade, errorBuilder: gone);
    }
    return null;
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.lime,
      ),
      child: LayoutBuilder(builder: (context, c) {
        final side = math.min(c.maxWidth, c.maxHeight);
        final text = initialsOf(name);
        return Center(
          child: text.isEmpty
              ? Icon(Icons.person_rounded, color: AppColors.ink, size: side * .5)
              : Text(text, style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: side * .36)),
        );
      }),
    );
  }
}

/// Round portrait for cards, lists and headers. A golden ring marks Star Teachers.
class TeacherAvatar extends StatelessWidget {
  const TeacherAvatar({super.key, required this.source, this.radius = 28, this.star = false});
  final PortraitSource source;
  final double radius;
  final bool star;

  @override
  Widget build(BuildContext context) {
    final d = radius * 2;
    return Container(
      width: d,
      height: d,
      padding: star ? const EdgeInsets.all(2.5) : EdgeInsets.zero,
      decoration: star ? const BoxDecoration(shape: BoxShape.circle, color: AppColors.ink) : null,
      child: ClipOval(child: TeacherPortrait(source: source, decodeWidth: (d * 3).round())),
    );
  }
}

/// Tall portrait card for grids, "nearby" carousels and tuition-centre listings.
class PortraitCard extends StatelessWidget {
  const PortraitCard({super.key, required this.source, required this.title, this.subtitle, this.badge, this.onTap, this.aspectRatio = .8});
  final PortraitSource source;
  final String title;
  final String? subtitle;
  final Widget? badge; // e.g. StarBadge()
  final VoidCallback? onTap;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(fit: StackFit.expand, children: [
            TeacherPortrait(source: source),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.center, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xCC111111)]),
              ),
            ),
            if (badge != null) Positioned(top: 10, left: 10, child: badge!),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                if (subtitle != null)
                  Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Small avatar with a pointer, for map overlays and "nearby" previews.
class PortraitPin extends StatelessWidget {
  const PortraitPin({super.key, required this.source, this.size = 48, this.onTap});
  final PortraitSource source;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3))],
          ),
          child: ClipOval(child: TeacherPortrait(source: source, decodeWidth: (size * 3).round())),
        ),
        CustomPaint(size: const Size(14, 8), painter: _Tail()),
      ]),
    );
  }
}

class _Tail extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()..moveTo(0, 0)..lineTo(s.width, 0)..lineTo(s.width / 2, s.height)..close();
    canvas.drawPath(p, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Cover-style header for a teacher's profile page. Wide screens get a flatter crop so it never fills the fold.
class TeacherProfileHeader extends StatelessWidget {
  const TeacherProfileHeader({super.key, required this.source, required this.name, this.line, this.badges = const []});
  final PortraitSource source;
  final String name;
  final String? line;
  final List<Widget> badges;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final ratio = c.maxWidth >= 720 ? 21 / 8 : 4 / 3;
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: ratio,
          child: Stack(fit: StackFit.expand, children: [
            TeacherPortrait(source: source, decodeWidth: 1200),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.center, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xDD111111)]),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                if (badges.isNotEmpty) Wrap(spacing: 6, runSpacing: 6, children: badges),
                const SizedBox(height: 6),
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)),
                if (line != null) Text(line!, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
      );
    });
  }
}
