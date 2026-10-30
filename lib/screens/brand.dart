import 'package:flutter/material.dart';

/// Approved Refilly delivery-R icon, reused across web and mobile.
class RefillyMark extends StatelessWidget {
  const RefillyMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Refilly logo',
    image: true,
    child: Image.asset(
      'assets/brand/refilly_app_icon.png',
      width: size,
      height: size,
      excludeFromSemantics: true,
      fit: BoxFit.contain,
    ),
  );
}
