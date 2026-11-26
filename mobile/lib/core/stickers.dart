import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'theme.dart';

/// Cute school-supply illustrations (assets/stickers/<name>.svg) in the Tutobridge orange palette.
/// Names: books, globe, bulb, pencilcup, notebook, laptop, scissors, glue, palette, pencil, eraser, ruler, apple,
/// backpack, calculator, pencilcase, crayons, clips, star, heart, spark.
class Sticker extends StatelessWidget {
  const Sticker(this.name, {super.key, this.size = 56, this.angle = 0});
  final String name;
  final double size;

  /// Tilt in degrees.
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle * 3.14159265 / 180,
      child: SvgPicture.asset('assets/stickers/$name.svg', width: size, height: size, semanticsLabel: ''),
    );
  }
}

/// A friendly empty state: a sticker, a title and an optional hint.
class StickerEmpty extends StatelessWidget {
  const StickerEmpty({super.key, required this.sticker, required this.title, this.hint});
  final String sticker;
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Sticker(sticker, size: 84, angle: -6),
        const SizedBox(height: 10),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink)),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(hint!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
        ],
      ]),
    );
  }
}
