// Many Hands colors, light and dark. Values come from the web app's src/theme.css.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bgAlt,
    required this.surface,
    required this.ink2,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.bgDark,
    required this.inkInv,
    required this.inkInv2,
    required this.accentOnDark,
    required this.ringTrack,
    required this.coveredFg,
    required this.coveredBg,
    required this.thinFg,
    required this.thinBg,
    required this.riskFg,
    required this.riskBg,
    required this.orphanFg,
    required this.orphanBg,
    required this.openFg,
    required this.openBg,
    required this.todoBg,
    required this.barThin,
    required this.danger,
    required this.dangerBg,
    required this.logoBg,
    required this.logoMark,
    required this.avatars,
  });

  final Color bgAlt, surface, ink2, accent, onAccent, accentSoft;
  final Color bgDark, inkInv, inkInv2, accentOnDark, ringTrack;
  final Color coveredFg, coveredBg, thinFg, thinBg, riskFg, riskBg, orphanFg, orphanBg, openFg, openBg, todoBg, barThin;
  final Color danger, dangerBg, logoBg, logoMark;
  final List<(Color bg, Color fg)> avatars;

  static const light = AppColors(
    bgAlt: Color(0xFFF5F5F7),
    surface: Color(0xFFFFFFFF),
    ink2: Color(0xFF6E6E73),
    accent: Color(0xFF1F5E4E),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0x1A1F5E4E),
    bgDark: Color(0xFF1D1D1F),
    inkInv: Color(0xFFF5F5F7),
    inkInv2: Color(0xFFA1A1A6),
    accentOnDark: Color(0xFF7FD8B8),
    ringTrack: Color(0xFF3A3A3C),
    coveredFg: Color(0xFF1B6B43),
    coveredBg: Color(0xFFE3F3E8),
    thinFg: Color(0xFF8A5300),
    thinBg: Color(0xFFFDF0D5),
    riskFg: Color(0xFFA6370B),
    riskBg: Color(0xFFFCE5DA),
    orphanFg: Color(0xFF5E2F80),
    orphanBg: Color(0xFFF0E7F7),
    openFg: Color(0xFF284D8C),
    openBg: Color(0xFFE6EEFA),
    todoBg: Color(0xFFECECF0),
    barThin: Color(0xFFC98A1B),
    danger: Color(0xFFB42318),
    dangerBg: Color(0xFFFDECEA),
    logoBg: Color(0xFF1F5E4E),
    logoMark: Color(0xFFF2C46B),
    avatars: [
      (Color(0xFFF9E1D0), Color(0xFF7A3410)),
      (Color(0xFFDCEBF7), Color(0xFF1E4A73)),
      (Color(0xFFE5F1DD), Color(0xFF2F5A1E)),
      (Color(0xFFEDE3F6), Color(0xFF4F2C73)),
      (Color(0xFFFCEFC9), Color(0xFF6B4A00)),
    ],
  );

  static const dark = AppColors(
    bgAlt: Color(0xFF1C1C1E),
    surface: Color(0xFF2A2A2E),
    ink2: Color(0xFFA1A1A6),
    accent: Color(0xFF7FD8B8),
    onAccent: Color(0xFF0D2B23),
    accentSoft: Color(0x297FD8B8),
    bgDark: Color(0xFF242428),
    inkInv: Color(0xFFF5F5F7),
    inkInv2: Color(0xFFA1A1A6),
    accentOnDark: Color(0xFF7FD8B8),
    ringTrack: Color(0xFF404045),
    coveredFg: Color(0xFF8BE0B0),
    coveredBg: Color(0xFF17392A),
    thinFg: Color(0xFFF2C46B),
    thinBg: Color(0xFF3B2D10),
    riskFg: Color(0xFFFFA07C),
    riskBg: Color(0xFF46200F),
    orphanFg: Color(0xFFD6B0F2),
    orphanBg: Color(0xFF33213F),
    openFg: Color(0xFFA5C4F7),
    openBg: Color(0xFF1B2B46),
    todoBg: Color(0xFF38383C),
    barThin: Color(0xFFE0A63A),
    danger: Color(0xFFFF8A80),
    dangerBg: Color(0xFF45191A),
    logoBg: Color(0xFF1F5E4E),
    logoMark: Color(0xFFF2C46B),
    avatars: [
      (Color(0xFF4A2A17), Color(0xFFF9D2B6)),
      (Color(0xFF17324D), Color(0xFFC4DDF5)),
      (Color(0xFF1F3A17), Color(0xFFCDE8BE)),
      (Color(0xFF33213F), Color(0xFFE2CCF5)),
      (Color(0xFF3B2D10), Color(0xFFF7DE9E)),
    ],
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) => t < 0.5 ? this : (other as AppColors? ?? this);
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final ink = brightness == Brightness.dark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);
  final bg = brightness == Brightness.dark ? const Color(0xFF121214) : Colors.white;
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1F5E4E), brightness: brightness).copyWith(
    primary: c.accent,
    onPrimary: c.onAccent,
    surface: bg,
    onSurface: ink,
    error: c.danger,
  );
  final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(980));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: ink),
    ),
    textTheme: Typography.material2021().black.apply(bodyColor: ink, displayColor: ink).copyWith(
          displaySmall: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: -1.2, height: 1.05, color: ink),
          headlineSmall: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.6, color: ink),
          titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: ink),
          bodyLarge: TextStyle(fontSize: 17, height: 1.45, color: ink),
          bodyMedium: TextStyle(fontSize: 15, height: 1.4, color: ink),
        ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: pill,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(shape: pill, minimumSize: const Size(44, 44))),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: c.accent, minimumSize: const Size(44, 44))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.bgAlt,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.accent, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: bg,
      indicatorColor: c.accentSoft,
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: DividerThemeData(color: ink.withValues(alpha: 0.08), space: 1),
  );
}

/// The light/dark choice is per device. With no choice saved, the app follows the system setting.
class ThemeController extends ChangeNotifier {
  static const _key = 'many-hands-theme';
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_key);
      _mode = v == 'dark' ? ThemeMode.dark : v == 'light' ? ThemeMode.light : ThemeMode.system;
      notifyListeners();
    } catch (_) {}
  }

  bool isDark(BuildContext context) =>
      _mode == ThemeMode.dark || (_mode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);

  Future<void> setDark(bool dark) async {
    _mode = dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, dark ? 'dark' : 'light');
    } catch (_) {}
  }
}
