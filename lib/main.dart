import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    return MaterialApp(
      title: 'Profilias',
      theme: ThemeData(
        fontFamily: 'Segoe UI',
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF1B3C59),
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color(0xFF00A6A6),
          onSecondary: Color(0xFFFFFFFF),
          error: Color(0xFFB42318),
          onError: Color(0xFFFFFFFF),
          surface: Color(0xFFF7F5F2),
          onSurface: Color(0xFF0F172A),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F5F2),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFFFFFFF),
          border: OutlineInputBorder(),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 8,
          shadowColor: const Color(0x1A0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}
