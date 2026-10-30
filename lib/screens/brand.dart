import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

/// Refilly's original water drop + refill wave brand mark.
class RefillyMark extends StatelessWidget {
  const RefillyMark({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Refilly',
    image: true,
    child: SvgPicture.asset(
      'assets/brand/refilly_mark.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    ),
  );
}

class RefillyBrand extends StatelessWidget {
  const RefillyBrand({super.key, this.markSize = 44, this.showTagline = true});
  final double markSize;
  final bool showTagline;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      RefillyMark(size: markSize),
      const SizedBox(width: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Refilly',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: RF.ink,
              letterSpacing: -.9,
            ),
          ),
          if (showTagline)
            const Text(
              'FRESH WATER · LOCALLY DELIVERED',
              style: TextStyle(
                color: RF.accent,
                fontSize: 9,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    ],
  );
}
