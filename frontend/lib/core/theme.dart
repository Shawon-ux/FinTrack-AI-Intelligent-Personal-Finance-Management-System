import 'package:flutter/material.dart';

class C {
  static const bg = Color(0xFF0B0F1E), card = Color(0xFF151A31), card2 = Color(0xFF1C2242), line = Color(0xFF262D52);
  static const mut = Color(0xFF8F97C2), p = Color(0xFF7C5CFF), p2 = Color(0xFF4F8BFF);
  static const ok = Color(0xFF2DD4A0), bad = Color(0xFFFF5D7A), warn = Color(0xFFFFB84D);
  static const grad = LinearGradient(colors: [p, p2], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const palette = [p, p2, ok, warn, bad, Color(0xFFB86BFF), Color(0xFF38BDF8)];
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
    colorScheme: const ColorScheme.dark(primary: C.p, secondary: C.p2, surface: C.card, error: C.bad),
    cardTheme: CardThemeData(color: C.card, elevation: 0, margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: C.line))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: C.card2,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.p)),
    ),
    navigationBarTheme: const NavigationBarThemeData(backgroundColor: Color(0xFF0E1328), indicatorColor: Color(0x447C5CFF)),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: C.bg, showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26)))),
    dividerColor: C.line,
  );
}
