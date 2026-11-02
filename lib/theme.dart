import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Refilly identity: warm off-white surfaces, near-black type, black pill actions,
/// and brand blue reserved for highlights and selected states.
class RF {
  static const bg = Color(0xFFF6F3EE);
  static const fill = Color(0xFFF1EDE7);
  static const card = Colors.white;
  static const ink = Color(0xFF171717);
  static const button = Color(0xFF141414);
  static const muted = Color(0xFF5E5953);
  static const line = Color(0xFFE7E1D9);
  static const accent = Color(0xFF0968EE);
  static const accentInk = Color(0xFF0754C2);
  static const accentSoft = Color(0xFFE7F0FE);
  static const selectedFill = Color(0xFFF7FAFF);
  static const good = Color(0xFF0D6A3E);
  static const goodSoft = Color(0xFFE7F6EE);
  static const usual = Color(0xFFF8E6DA);
  static const usualInk = Color(0xFF8C4518);
  static const radius = 18.0;
  static const cardRadius = 24.0;
  static const sheetRadius = 32.0;
  static final shadow = [
    BoxShadow(color: const Color(0xFF30220F).withValues(alpha: .06), blurRadius: 24, offset: const Offset(0, 8)),
    BoxShadow(color: const Color(0xFF30220F).withValues(alpha: .04), blurRadius: 2, offset: const Offset(0, 1)),
  ];
  static final selectedShadow = [
    BoxShadow(color: accent.withValues(alpha: .08), blurRadius: 24, offset: const Offset(0, 10)),
  ];
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
        headlineLarge: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -1.4, height: 1.05, color: RF.ink),
        headlineMedium: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -1.1, color: RF.ink),
        headlineSmall: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -.8, color: RF.ink),
        titleLarge: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.5, color: RF.ink),
        titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -.3, color: RF.ink),
      );
  const pill = StadiumBorder();
  final field = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  return base.copyWith(
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {for (final p in TargetPlatform.values) p: const CupertinoPageTransitionsBuilder()},
    ),
    splashFactory: InkSparkle.splashFactory,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: RF.ink,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: RF.card,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RF.cardRadius)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: RF.button,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFD9D3CB),
        disabledForegroundColor: const Color(0xFF6E6862),
        minimumSize: const Size(64, 54),
        shape: pill,
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: RF.ink,
        minimumSize: const Size(48, 46),
        side: const BorderSide(color: RF.line, width: 1.2),
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
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      labelStyle: const TextStyle(color: RF.muted),
      hintStyle: const TextStyle(color: RF.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: RF.line)),
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
      backgroundColor: Colors.white,
      selectedColor: RF.button,
      side: const BorderSide(color: RF.line),
      shape: const StadiumBorder(),
      labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, color: RF.ink),
      secondaryLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
      checkmarkColor: Colors.white,
      showCheckmark: false,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(field),
        side: const WidgetStatePropertyAll(BorderSide(color: RF.line)),
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? RF.button : Colors.white),
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
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: RF.ink, linearTrackColor: RF.line),
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
