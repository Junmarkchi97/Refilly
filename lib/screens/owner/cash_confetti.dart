import 'package:flutter/material.dart';
import 'package:flutter_confetti/flutter_confetti.dart';

const _partyColors = <Color>[
  Color(0xFFE23B3B),
  Color(0xFF3B82F6),
  Color(0xFF2EAD6F),
  Color(0xFFF59E0B),
  Color(0xFF7C5CBF),
  Color(0xFFF2B93B),
  Color(0xFF2563EB),
  Color(0xFFE8B931),
];

/// Colorful paper confetti when the owner marks an order delivered.
void celebrateOrderDelivered(BuildContext context) {
  Confetti.launch(
    context,
    particleBuilder: (_) => Square(),
    options: const ConfettiOptions(
      particleCount: 110,
      spread: 360,
      startVelocity: 34,
      gravity: 0.7,
      decay: 0.92,
      scalar: 1.1,
      particleDuration: Duration(milliseconds: 2100),
      x: 0.5,
      y: 0.38,
      colors: _partyColors,
    ),
  );
  Confetti.launch(
    context,
    particleBuilder: (index) => index.isEven ? Square() : Circle(),
    options: const ConfettiOptions(
      particleCount: 55,
      angle: 90,
      spread: 70,
      startVelocity: 48,
      gravity: 0.9,
      scalar: 0.95,
      particleDuration: Duration(milliseconds: 1800),
      x: 0.5,
      y: 0.7,
      colors: _partyColors,
    ),
  );
}
