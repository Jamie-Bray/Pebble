import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Day Mode Colors
  static const Color dayBackground = Color(0xFFF2F4F8);
  static const Color dayPrimaryText = Color(0xFF1A1A1A);
  static const Color dayCardBackground = Color(0xFFFFFFFF);
  static const Color dayAccent = Color(0xFF3F77BE);
  static const Color dayActiveIcon = Color(0xFF6B7C93);

  // Night Mode Colors
  static const Color nightBackground = Color(0xFF101214);
  static const Color nightPrimaryText = Color(0xFFF2F4F8);
  static const Color nightCardBackground = Color(0xFF1A1C1E);
  static const Color nightAccent = Color(0xFF8C9EFF);

  // Blush Mode Colors
  static const Color blushBackground = Color(0xFFFFF9F7);
  static const Color blushCardBackground = Color(0xFFF8D9E1);
  static const Color blushPrimaryText = Color(0xFF3C3C3C);
  static const Color blushAccent = Color(0xFFDFA6B0);

  // Blush Night Mode Colors
  static const Color blushNightBackground = Color(0xFF1C1B1E);
  static const Color blushNightCardBackground = Color(0xFF2A272B);
  static const Color blushNightPrimaryText = Color(0xFFF8D9E1);
  static const Color blushNightAccent = Color(0xFFB497A2);

  // Jungle Mode Colors (Soft Green, Natural)
  static const Color jungleBackground = Color(0xFFF0F7F0);
  static const Color jungleCardBackground = Color(0xFFE8F5E8);
  static const Color junglePrimaryText = Color(0xFF2D4A2D);
  static const Color jungleAccent = Color(0xFF7FB069);

  // Sky Mode Colors (Gentle Blue, Peaceful)
  static const Color skyBackground = Color(0xFFF0F8FF);
  static const Color skyCardBackground = Color(0xFFE6F3FF);
  static const Color skyPrimaryText = Color(0xFF2D4A6B);
  static const Color skyAccent = Color(0xFF6BA5D1);
  
  // Shared properties
  static final _cardTheme = CardTheme(
    elevation: 1,
    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16.0),
    ),
  );

  static final _elevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    ),
  );

  static final _fabTheme = FloatingActionButtonThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16.0),
    ),
  );

  static final TextTheme _textTheme = GoogleFonts.interTextTheme();

  // Day Theme
  static ThemeData get dayTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: dayBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: dayAccent,
        background: dayBackground,
        primary: dayAccent,
        onPrimary: Colors.white,
        surface: dayCardBackground,
        onSurface: dayPrimaryText,
        brightness: Brightness.light,
      ),
      textTheme: _textTheme.apply(
        bodyColor: dayPrimaryText,
        displayColor: dayPrimaryText,
      ),
      cardTheme: _cardTheme.copyWith(
        color: dayCardBackground,
        shadowColor: dayActiveIcon.withOpacity(0.1),
      ),
      elevatedButtonTheme: _elevatedButtonTheme,
      floatingActionButtonTheme: _fabTheme.copyWith(
        backgroundColor: dayAccent,
        foregroundColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }

  // Night Theme
  static ThemeData get nightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: nightBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: nightAccent,
        background: nightBackground,
        primary: nightAccent,
        onPrimary: Colors.black,
        surface: nightCardBackground,
        onSurface: nightPrimaryText,
        brightness: Brightness.dark,
      ),
      textTheme: _textTheme.apply(
        bodyColor: nightPrimaryText,
        displayColor: nightPrimaryText,
      ),
      cardTheme: _cardTheme.copyWith(
        color: nightCardBackground,
      ),
      elevatedButtonTheme: _elevatedButtonTheme,
      floatingActionButtonTheme: _fabTheme.copyWith(
        backgroundColor: nightAccent,
        foregroundColor: Colors.black,
      ),
       appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }

  // NOTE: Blush themes can be added here later following the same pattern.
  static ThemeData get blushTheme {
    return dayTheme.copyWith(
      scaffoldBackgroundColor: blushBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: blushAccent,
        background: blushBackground,
        primary: blushAccent,
        surface: blushCardBackground,
        onSurface: blushPrimaryText,
        brightness: Brightness.light,
      ),
      textTheme: _textTheme.apply(
        bodyColor: blushPrimaryText,
        displayColor: blushPrimaryText,
      ),
      cardTheme: _cardTheme.copyWith(
        color: blushCardBackground,
        shadowColor: blushAccent.withOpacity(0.1),
      ),
    );
  }

  static ThemeData get blushNightTheme {
    return nightTheme.copyWith(
      scaffoldBackgroundColor: blushNightBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: blushNightAccent,
        background: blushNightBackground,
        primary: blushNightAccent,
        surface: blushNightCardBackground,
        onSurface: blushNightPrimaryText,
        brightness: Brightness.dark,
      ),
       textTheme: _textTheme.apply(
        bodyColor: blushNightPrimaryText,
        displayColor: blushNightPrimaryText,
      ),
      cardTheme: _cardTheme.copyWith(
        color: blushNightCardBackground,
      ),
    );
  }

  // Jungle Theme (Soft Green, Natural)
  static ThemeData get jungleTheme {
    return dayTheme.copyWith(
      scaffoldBackgroundColor: jungleBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: jungleAccent,
        background: jungleBackground,
        primary: jungleAccent,
        surface: jungleCardBackground,
        onSurface: junglePrimaryText,
        brightness: Brightness.light,
      ),
      textTheme: _textTheme.apply(
        bodyColor: junglePrimaryText,
        displayColor: junglePrimaryText,
      ),
      cardTheme: _cardTheme.copyWith(
        color: jungleCardBackground,
        shadowColor: jungleAccent.withOpacity(0.1),
      ),
      floatingActionButtonTheme: _fabTheme.copyWith(
        backgroundColor: jungleAccent,
        foregroundColor: Colors.white,
      ),
    );
  }

  // Sky Theme (Gentle Blue, Peaceful)
  static ThemeData get skyTheme {
    return dayTheme.copyWith(
      scaffoldBackgroundColor: skyBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: skyAccent,
        background: skyBackground,
        primary: skyAccent,
        surface: skyCardBackground,
        onSurface: skyPrimaryText,
        brightness: Brightness.light,
      ),
      textTheme: _textTheme.apply(
        bodyColor: skyPrimaryText,
        displayColor: skyPrimaryText,
      ),
      cardTheme: _cardTheme.copyWith(
        color: skyCardBackground,
        shadowColor: skyAccent.withOpacity(0.1),
      ),
      floatingActionButtonTheme: _fabTheme.copyWith(
        backgroundColor: skyAccent,
        foregroundColor: Colors.white,
      ),
    );
  }
} 