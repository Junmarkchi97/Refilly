import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Refilly design system: clean marine tones, airy surfaces, and friendly curves.
/// A deep sea-green primary keeps buttons accessible while fresh aqua adds delight.
class RF {
  static const bg = Color(0xFFF7FBFA);
  static const fill = Color(0xFFEEF6F5);
  static const card = Colors.white;
  static const ink = Color(0xFF123B45);
  static const muted = Color(0xFF657D82);
  static const line = Color(0xFFDFEBE9);
  static const accent = Color(0xFF087F7C);
  static const accentSoft = Color(0xFFE1F7F2);
  static const aqua = Color(0xFF1BC8B5);
  static const radius = 20.0;
  static const sheetRadius = 30.0;
  static final shadow = [BoxShadow(color: const Color(0xFF13454A).withValues(alpha: .07), blurRadius: 24, offset: const Offset(0, 8))];
}

ThemeData refillyTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: RF.accent,
      primary: RF.ink,
      onPrimary: Colors.white,
      secondary: RF.accent,
      surface: RF.bg,
    ).copyWith(surfaceTint: Colors.transparent),
    scaffoldBackgroundColor: RF.bg,
  );
  final text = GoogleFonts.interTextTheme(base.textTheme)
      .apply(bodyColor: RF.ink, displayColor: RF.ink)
      .copyWith(
        headlineLarge: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1, color: RF.ink),
        headlineMedium: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -.8, color: RF.ink),
        headlineSmall: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -.5, color: RF.ink),
        titleLarge: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.3, color: RF.ink),
        titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: RF.ink),
      );
  final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  return base.copyWith(
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {for (final p in TargetPlatform.values) p: const CupertinoPageTransitionsBuilder()},
    ),
    splashFactory: InkSparkle.splashFactory,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: RF.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: RF.ink,
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    ),
    cardTheme: CardThemeData(
      color: RF.card,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RF.radius),
        side: const BorderSide(color: RF.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: RF.ink,
        foregroundColor: Colors.white,
        disabledBackgroundColor: RF.line,
        minimumSize: const Size(64, 56),
        shape: pill,
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: RF.ink,
        minimumSize: const Size(48, 46),
        side: const BorderSide(color: RF.line, width: 1.5),
        backgroundColor: Colors.white,
        shape: pill,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: RF.ink,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: RF.fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      labelStyle: const TextStyle(color: RF.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: RF.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: RF.accent, width: 1.6),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: RF.fill,
      selectedColor: RF.accent,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, color: RF.ink),
      secondaryLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
      checkmarkColor: Colors.white,
      showCheckmark: false,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(pill),
        side: const WidgetStatePropertyAll(BorderSide(color: RF.line)),
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? RF.accent : Colors.white),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : RF.ink),
        iconColor: const WidgetStatePropertyAll(Colors.white),
      ),
    ),
    listTileTheme: const ListTileThemeData(iconColor: RF.ink),
    dividerTheme: const DividerThemeData(color: RF.line, space: 24),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? RF.accent : RF.line),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: RF.accent, linearTrackColor: RF.line),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: RF.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(RF.sheetRadius))),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    expansionTileTheme: const ExpansionTileThemeData(shape: Border(), collapsedShape: Border()),
    radioTheme: const RadioThemeData(fillColor: WidgetStatePropertyAll(RF.ink)),
  );
}
