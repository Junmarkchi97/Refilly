import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Refilly's geometric R + delivery wheels logo.
class RefillyMark extends StatelessWidget {
  const RefillyMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Refilly logo',
    image: true,
    child: SvgPicture.asset(
      'assets/brand/refilly_icon.svg',
      width: size,
      height: size,
      excludeFromSemantics: true,
    ),
  );
}
