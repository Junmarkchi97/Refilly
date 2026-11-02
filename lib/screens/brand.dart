import 'package:flutter/material.dart';

/// Official four-color Google "G", drawn so it stays sharp at any size.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, this.size = 20});

  final double size;

  /// Yellow, red, green, blue pieces of the mark, in that order.
  static const parts = _GoogleLogoPainter._parts;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Google',
    image: true,
    child: CustomPaint(
      size: Size.square(size),
      painter: const _GoogleLogoPainter(),
    ),
  );
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static const _parts = <(Color, String)>[
    (
      Color(0xFFFBBC05),
      'M43.611,20.083H42V20H24v8h11.303c-1.649,4.657-6.08,8-11.303,8c-6.627,0-12-5.373-12-12'
      'c0-6.627,5.373-12,12-12c3.059,0,5.842,1.154,7.961,3.039l5.657-5.657'
      'C34.046,6.053,29.268,4,24,4C12.955,4,4,12.955,4,24c0,11.045,8.955,20,20,20'
      'c11.045,0,20-8.955,20-20C44,22.659,43.862,21.35,43.611,20.083z',
    ),
    (
      Color(0xFFEA4335),
      'M6.306,14.691l6.571,4.819C14.655,15.108,18.961,12,24,12c3.059,0,5.842,1.154,7.961,3.039'
      'l5.657-5.657C34.046,6.053,29.268,4,24,4C16.318,4,9.656,8.337,6.306,14.691z',
    ),
    (
      Color(0xFF34A853),
      'M24,44c5.166,0,9.86-1.977,13.409-5.192l-6.19-5.238C29.211,35.091,26.715,36,24,36'
      'c-5.202,0-9.619-3.317-11.283-7.946l-6.522,5.025C9.505,39.556,16.227,44,24,44z',
    ),
    (
      Color(0xFF4285F4),
      'M43.611,20.083H42V20H24v8h11.303c-0.792,2.237-2.231,4.166-4.087,5.571'
      'c0.001-0.001,0.002-0.001,0.003-0.002l6.19,5.238C36.971,39.205,44,34,44,24'
      'C44,22.659,43.862,21.35,43.611,20.083z',
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48, size.height / 48);
    for (final (color, data) in _parts) {
      canvas.drawPath(svgPath(data), Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _GoogleLogoPainter oldDelegate) => false;
}

/// The small subset of SVG path data the Google mark uses.
Path svgPath(String source) {
  final path = Path();
  final tokens = RegExp(r'[MmLlHhVvCcZz]|-?\d*\.?\d+(?:e[-+]?\d+)?')
      .allMatches(source)
      .map((match) => match.group(0)!)
      .toList();
  var index = 0;
  var command = '';
  var current = Offset.zero;
  Offset? start;

  double number() => double.parse(tokens[index++]);
  bool isCommand(String token) => token.length == 1 && RegExp(r'[A-Za-z]').hasMatch(token);

  while (index < tokens.length) {
    if (isCommand(tokens[index])) command = tokens[index++];
    if (command == 'Z' || command == 'z') {
      path.close();
      if (start != null) current = start;
      continue;
    }
    final relative = command == command.toLowerCase();
    switch (command.toUpperCase()) {
      case 'M':
        final point = _point(number(), number(), current, relative);
        path.moveTo(point.dx, point.dy);
        current = start = point;
        command = relative ? 'l' : 'L';
      case 'L':
        current = _point(number(), number(), current, relative);
        path.lineTo(current.dx, current.dy);
      case 'H':
        final x = number();
        current = Offset(relative ? current.dx + x : x, current.dy);
        path.lineTo(current.dx, current.dy);
      case 'V':
        final y = number();
        current = Offset(current.dx, relative ? current.dy + y : y);
        path.lineTo(current.dx, current.dy);
      case 'C':
        final control1 = _point(number(), number(), current, relative);
        final control2 = _point(number(), number(), current, relative);
        final end = _point(number(), number(), current, relative);
        path.cubicTo(control1.dx, control1.dy, control2.dx, control2.dy, end.dx, end.dy);
        current = end;
      default:
        throw FormatException('Unsupported SVG command $command');
    }
  }
  return path;
}

Offset _point(double x, double y, Offset current, bool relative) =>
    relative ? current + Offset(x, y) : Offset(x, y);

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
