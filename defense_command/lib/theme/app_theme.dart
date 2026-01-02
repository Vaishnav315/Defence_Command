import 'package:flutter/material.dart';

class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  // Dark Theme Colors (Original App Colors)
  static const Color _darkBackground = Color(0xFF0A0A0A);
  static const Color _darkSurface = Color(0xFF1A1A1A);
  static const Color _darkPrimary = Colors.white;
  static const Color _darkSecondary = Colors.grey;
  static const Color _darkAccent = Colors.white;

  // Light Theme Colors
  static const Color _lightBackground = Color(0xFFF2F2F7); // Apple system gray 6
  static const Color _lightSurface = Colors.white;
  static const Color _lightPrimaryText = Color(0xFF000000);
  static const Color _lightSecondaryText = Color(0xFF3C3C43); // Apple label secondary
  static const Color _lightAccent = Color(0xFF007AFF); // Professional Blue
  static const Color _lightDivider = Color(0xFFC6C6C8); // Apple separator
  
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: _darkPrimary,
    scaffoldBackgroundColor: _darkBackground,
    cardColor: _darkSurface,
    colorScheme: const ColorScheme.dark(
      surface: _darkSurface,
      primary: _darkPrimary,
      secondary: _darkSecondary,
      onSurface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.black,
      indicatorColor: _darkSurface,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, color: Colors.white),
      ),
      iconTheme: WidgetStateProperty.all(
        const IconThemeData(color: Colors.white),
      ),
    ),
    iconTheme: const IconThemeData(color: Colors.white),
    dividerColor: Colors.grey[800],
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.grey),
      titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.black.withOpacity(0.7),
      hintStyle: const TextStyle(color: Colors.grey),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[800]!.withOpacity(0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[800]!.withOpacity(0.5)),
      ),
    ),
  );

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: _lightBackground,
    primaryColor: _lightAccent,
    cardColor: _lightSurface,
    dividerColor: _lightDivider,
    colorScheme: const ColorScheme.light(
      surface: _lightSurface,
      primary: _lightAccent,
      onSurface: _lightPrimaryText,
    ),
    
    // AppBar Theme
    appBarTheme: const AppBarTheme(
      backgroundColor: _lightSurface,
      foregroundColor: _lightPrimaryText,
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: _lightPrimaryText),
      titleTextStyle: TextStyle(
        color: _lightPrimaryText,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      ),
    ),
    
    // Navigation Bar Theme
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _lightSurface,
      indicatorColor: _lightAccent.withOpacity(0.1),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: _lightAccent);
        }
        return const IconThemeData(color: _lightSecondaryText);
      }),
    ),
    
    // Icon Theme
    iconTheme: const IconThemeData(
      color: _lightPrimaryText,
    ),
    
    // Text Theme
    textTheme: const TextTheme(
      // Headlines
      displayLarge: TextStyle(color: _lightPrimaryText, fontSize: 32, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: _lightPrimaryText, fontSize: 24, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(color: _lightPrimaryText, fontSize: 20, fontWeight: FontWeight.bold),
      
      // Titles
      titleLarge: TextStyle(color: _lightPrimaryText, fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: _lightPrimaryText, fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(color: _lightPrimaryText, fontSize: 14, fontWeight: FontWeight.w600),
      
      // Body text
      bodyLarge: TextStyle(color: _lightPrimaryText, fontSize: 16),
      bodyMedium: TextStyle(color: _lightSecondaryText, fontSize: 14),
      bodySmall: TextStyle(color: _lightSecondaryText, fontSize: 12),
    ),
    
    // Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      fillColor: _lightSurface,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _lightDivider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _lightDivider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _lightAccent, width: 2),
      ),
      hintStyle: const TextStyle(color: _lightSecondaryText),
    ),

    // Card Theme
    cardTheme: CardThemeData(
      color: _lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _lightDivider.withOpacity(0.5)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    ),
  );
}
