import 'package:flutter/material.dart';

abstract final class PosterTheme {
  static const ink = Color(0xff202219);
  static const lime = Color(0xffa8cc43);
  static const yellow = Color(0xffffdf38);
  static const cream = Color(0xfffff9df);
  static const red = Color(0xffb82d22);
  static const pink = Color(0xff922254);

  static ThemeData get data => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: red,
      primary: red,
      onPrimary: Colors.white,
      secondary: pink,
      surface: cream,
      onSurface: ink,
      primaryContainer: yellow,
      onPrimaryContainer: ink,
      outline: ink,
    ),
    scaffoldBackgroundColor: lime,
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.7,
      ),
      titleMedium: TextStyle(fontWeight: FontWeight.w800),
      bodyMedium: TextStyle(height: 1.45),
      labelLarge: TextStyle(fontWeight: FontWeight.w800),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
        side: BorderSide(color: ink, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        side: const BorderSide(color: ink, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: const BorderSide(color: ink, width: 2),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: ink),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: ink),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: cream,
      selectedColor: yellow,
      side: BorderSide(color: ink, width: 1.5),
      labelStyle: TextStyle(color: ink, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(5)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: cream,
      labelStyle: TextStyle(color: ink),
      floatingLabelStyle: TextStyle(color: ink, fontWeight: FontWeight.bold),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(5)),
        borderSide: BorderSide(color: ink, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(5)),
        borderSide: BorderSide(color: ink, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(5)),
        borderSide: BorderSide(color: pink, width: 3),
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: red,
      thumbColor: red,
      inactiveTrackColor: Color(0xffdad3b7),
      trackHeight: 6,
    ),
  );
}

class PosterHeader extends StatelessWidget {
  const PosterHeader({super.key, required this.onAbout});
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Icon(Icons.radio_rounded, size: 22, color: PosterTheme.ink),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'THE RADIO ARCHIVE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
          IconButton(
            tooltip: 'About this player',
            onPressed: onAbout,
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Semantics(
        header: true,
        label: 'Ronflonflon',
        excludeSemantics: true,
        child: SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            child: Stack(
              children: [
                Text(
                  'RONFLONFLON',
                  style: TextStyle(
                    fontSize: 106,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -5,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeJoin = StrokeJoin.round
                      ..strokeWidth = 5
                      ..color = PosterTheme.ink,
                    shadows: const [
                      Shadow(color: PosterTheme.ink, offset: Offset(3, 5)),
                    ],
                  ),
                ),
                const Text(
                  'RONFLONFLON',
                  style: TextStyle(
                    fontSize: 106,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -5,
                    color: PosterTheme.yellow,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        'avec Jacques Plafond',
        style: TextStyle(
          fontFamily: 'Georgia',
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w700,
          fontSize: 28,
          height: 1.2,
          color: PosterTheme.pink,
        ),
      ),
      const SizedBox(height: 14),
      const Text('One episode at a time. A little radio time machine.'),
      const SizedBox(height: 22),
      const ExcludeSemantics(
        child: SizedBox(
          height: 12,
          width: double.infinity,
          child: CustomPaint(painter: _RibbonPainter()),
        ),
      ),
    ],
  );
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = PosterTheme.cream);
    final paint = Paint()
      ..color = PosterTheme.ink
      ..strokeWidth = 5;
    for (double x = -size.height; x < size.width; x += 13) {
      canvas.drawLine(Offset(x, size.height), Offset(x + 10, 0), paint);
    }
    canvas.restore();
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = PosterTheme.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _RibbonPainter oldDelegate) => false;
}
