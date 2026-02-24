import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'pages/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const supabaseUrl = 'https://dhwpwfzktedljsrrczbe.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRod3B3ZnprdGVkbGpzcnJjemJlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA0MTIzNTAsImV4cCI6MjA4NTk4ODM1MH0.aK3XlJIXDGRhBTLfAj66HsTn3E14pdRRa6wUz5SbYn0';

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
    );
    const primary = Color(0xFF0F766E);
    const secondary = Color(0xFF1F3A5F);
    const surface = Color(0xFFF9F5F0);
    const onSurface = Color(0xFF0B1220);
    const glass = Color(0xE6FFFFFF);
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Color(0xFFFFFFFF),
      secondary: secondary,
      onSecondary: Color(0xFFFFFFFF),
      error: Color(0xFFB42318),
      onError: Color(0xFFFFFFFF),
      surface: surface,
      onSurface: onSurface,
    );
    final textTheme = GoogleFonts.oswaldTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.oswald(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        height: 1.1,
      ),
      displayMedium: GoogleFonts.oswald(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        height: 1.12,
      ),
      displaySmall: GoogleFonts.oswald(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        height: 1.15,
      ),
      headlineMedium: GoogleFonts.oswald(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      headlineSmall: GoogleFonts.oswald(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      titleLarge: GoogleFonts.oswald(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      titleMedium: GoogleFonts.oswald(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
      ),
      bodyLarge: GoogleFonts.oswald(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      bodyMedium: GoogleFonts.oswald(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      bodySmall: GoogleFonts.oswald(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.35,
      ),
      labelLarge: GoogleFonts.oswald(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return MaterialApp(
      title: 'Profilias',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: surface,
        textTheme: textTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: surface,
          elevation: 0,
          centerTitle: false,
          iconTheme: const IconThemeData(color: onSurface),
          titleTextStyle: textTheme.titleLarge?.copyWith(
            color: onSurface,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFDFBF9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primary, width: 1.4),
          ),
          labelStyle: textTheme.bodyMedium?.copyWith(
            color: onSurface.withValues(alpha: 0.7),
            letterSpacing: 0.4,
          ),
          floatingLabelStyle: textTheme.bodyMedium?.copyWith(
            color: primary,
            letterSpacing: 0.6,
          ),
          hintStyle: textTheme.bodySmall?.copyWith(
            color: onSurface.withValues(alpha: 0.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            ),
            shape: WidgetStateProperty.all(buttonShape),
            backgroundColor: WidgetStateProperty.all(primary),
            foregroundColor: WidgetStateProperty.all(Colors.white),
            elevation: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.pressed) ? 2 : 6,
            ),
            shadowColor: WidgetStateProperty.all(
              const Color(0x33000000),
            ),
            overlayColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.pressed)
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.06),
            ),
            textStyle: WidgetStateProperty.all(textTheme.labelLarge),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            ),
            shape: WidgetStateProperty.all(buttonShape),
            side: WidgetStateProperty.all(const BorderSide(color: primary)),
            foregroundColor: WidgetStateProperty.all(primary),
            overlayColor: WidgetStateProperty.resolveWith(
              (states) => primary.withValues(alpha: 0.08),
            ),
            textStyle: WidgetStateProperty.all(textTheme.labelLarge),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            foregroundColor: secondary,
            textStyle: textTheme.labelLarge,
          ),
        ),
        cardTheme: CardThemeData(
          color: glass,
          elevation: 14,
          shadowColor: const Color(0x260B1220),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          surfaceTintColor: Colors.white,
          clipBehavior: Clip.antiAlias,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.white,
          selectedColor: primary.withValues(alpha: 0.15),
          labelStyle: textTheme.labelLarge?.copyWith(
            color: onSurface,
          ),
          secondaryLabelStyle: textTheme.labelLarge?.copyWith(
            color: primary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
          ),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            textStyle: WidgetStateProperty.all(textTheme.labelLarge),
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? primary.withValues(alpha: 0.12)
                  : Colors.white,
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) =>
                  states.contains(WidgetState.selected) ? primary : onSurface,
            ),
            side: WidgetStateProperty.all(
              BorderSide(color: Colors.black.withValues(alpha: 0.08)),
            ),
          ),
        ),
        dividerTheme: DividerThemeData(
          color: Colors.black.withValues(alpha: 0.08),
          thickness: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF0B1220),
          contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}
