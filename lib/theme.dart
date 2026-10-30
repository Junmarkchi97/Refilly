import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Refilly identity: confident blue calls to action with charcoal typography and calm neutral surfaces.
class RF {
  static const bg = Colors.white;
  static const fill = Color(0xFFF5F7FB);
  static const card = Colors.white;
  static const ink = Color(0xFF171D2A);
  static const muted = Color(0xFF687387);
  static const line = Color(0xFFE5E9F2);
  static const accent = Color(0xFF0968EE);
  static const accentSoft = Color(0xFFEDF4FF);
  static const radius = 14.0;
  static const sheetRadius = 26.0;
  static final shadow = [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 18, offset: const Offset(0, 4))];
}

ThemeData refillyTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: RF.accent,
      primary: RF.accent,
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
  final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
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
        backgroundColor: RF.accent,
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
        foregroundColor: RF.accent,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: RF.fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      labelStyle: const TextStyle(color: RF.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: RF.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: RF.accent, width: 1.5),
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
