import 'package:flutter/material.dart';

/// App colours. Brand colours are fixed; surfaces/text adapt to [C.dark].
/// [C.dark] is set at the app root before each build (see main.dart), so any widget built after
/// a theme change picks up the new palette.
class C {
  static bool dark = true;

  static Color get bg => dark ? const Color(0xFF0B0F1E) : const Color(0xFFF4F5FB);
  static Color get card => dark ? const Color(0xFF151A31) : const Color(0xFFFFFFFF);
  static Color get card2 => dark ? const Color(0xFF1C2242) : const Color(0xFFECEFF9);
  static Color get line => dark ? const Color(0xFF262D52) : const Color(0xFFDDE1F0);
  static Color get mut => dark ? const Color(0xFF8F97C2) : const Color(0xFF626B94);
  static Color get text => dark ? const Color(0xFFEEF0FF) : const Color(0xFF151A31);
  static Color get nav => dark ? const Color(0xFF0E1328) : const Color(0xFFFFFFFF);
  // translucent "glass" surfaces used on the auth screens
  static Color get glass => dark ? Colors.white.withValues(alpha: .06) : Colors.white.withValues(alpha: .75);
  static Color get glassLine => dark ? Colors.white.withValues(alpha: .12) : const Color(0xFFDDE1F0);

  static const p = Color(0xFF7C5CFF), p2 = Color(0xFF4F8BFF);
  static const ok = Color(0xFF2DD4A0), bad = Color(0xFFFF5D7A), warn = Color(0xFFFFB84D);
  static const grad = LinearGradient(colors: [p, p2], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const palette = [p, p2, ok, warn, bad, Color(0xFFB86BFF), Color(0xFF38BDF8)];
}

ThemeData buildTheme(bool dark) {
  C.dark = dark;
  final base = dark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
  final border = OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: C.line));
  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
    colorScheme: (dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(primary: C.p, secondary: C.p2, surface: C.card, error: C.bad),
    textTheme: base.textTheme.apply(bodyColor: C.text, displayColor: C.text),
    cardTheme: CardThemeData(color: C.card, elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: C.line))),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: C.card2, border: border, enabledBorder: border, focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.p))),
    navigationBarTheme: NavigationBarThemeData(backgroundColor: C.nav, indicatorColor: C.p.withValues(alpha: .25)),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: C.bg, showDragHandle: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26)))),
    appBarTheme: AppBarTheme(backgroundColor: C.bg, foregroundColor: C.text, elevation: 0),
    dialogTheme: DialogThemeData(backgroundColor: C.card),
    chipTheme: ChipThemeData(
      backgroundColor: C.card2,
      selectedColor: C.p.withValues(alpha: .28),
      side: BorderSide(color: C.line),
      showCheckmark: false,
      labelStyle: TextStyle(color: C.text, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? C.p.withValues(alpha: .22) : Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? C.p : C.mut),
        side: WidgetStatePropertyAll(BorderSide(color: C.line)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? C.p : C.card2),
      trackOutlineColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? Colors.transparent : C.line),
    ),
    dividerColor: C.line,
  );
}
