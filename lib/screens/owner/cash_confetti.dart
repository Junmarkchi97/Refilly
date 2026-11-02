import 'package:flutter/material.dart';
import 'package:flutter_confetti/flutter_confetti.dart';

/// Gold sits on every third color so the round pieces read as coins.
const _cashColors = <Color>[
  Color(0xFFE8B931),
  Color(0xFFE23B3B),
  Color(0xFF3B82F6),
  Color(0xFFF6C445),
  Color(0xFF2EAD6F),
  Color(0xFFF2B93B),
  Color(0xFF7C5CBF),
  Color(0xFFF59E0B),
  Color(0xFF2563EB),
];

/// Paper squares and gold coins burst after cash is collected.
void celebrateCashCollected(BuildContext context) {
  ConfettiParticle piece(int index) => index % 3 == 0 ? Circle() : Square();

  Confetti.launch(
    context,
    particleBuilder: piece,
    options: const ConfettiOptions(
      particleCount: 120,
      spread: 360,
      startVelocity: 36,
      gravity: 0.65,
      decay: 0.92,
      scalar: 1.15,
      particleDuration: Duration(milliseconds: 2200),
      x: 0.5,
      y: 0.4,
      colors: _cashColors,
    ),
  );
  Confetti.launch(
    context,
    particleBuilder: piece,
    options: const ConfettiOptions(
      particleCount: 70,
      angle: 90,
      spread: 75,
      startVelocity: 52,
      gravity: 0.85,
      scalar: 1.05,
      particleDuration: Duration(milliseconds: 2000),
      x: 0.5,
      y: 0.72,
      colors: _cashColors,
    ),
  );
}
