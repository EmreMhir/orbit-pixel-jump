import 'package:flutter/material.dart';

abstract final class OrbitTheme {
  static const background = Color(0xff070d20);
  static const panel = Color(0xff101a30);
  static const mint = Color(0xff70fff1);
  static const coral = Color(0xffff8578);
  static const text = Color(0xffeff5ff);
  static const muted = Color(0xffa5b6d1);
  static const border = Color(0xff354763);
  static TextStyle pixel(double size, {Color color = text}) => TextStyle(
    fontFamily: 'PressStart2P',
    fontSize: size,
    height: 1.6,
    color: color,
  );
  static ThemeData get data => ThemeData(
    fontFamily: 'SpaceGrotesk',
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: mint,
      onPrimary: background,
      surface: panel,
      onSurface: text,
      secondary: coral,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 15, height: 1.5, color: muted),
      bodyLarge: TextStyle(fontSize: 17, height: 1.5, color: text),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        side: const BorderSide(color: border),
        foregroundColor: text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: muted,
      ),
    ),
  );
}

class OrbitPanel extends StatelessWidget {
  const OrbitPanel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: OrbitTheme.panel,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: OrbitTheme.border),
    ),
    child: Material(color: Colors.transparent, child: child),
  );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = OrbitTheme.mint});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: TextStyle(
      color: color,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 3,
      height: 1.6,
    ),
  );
}
