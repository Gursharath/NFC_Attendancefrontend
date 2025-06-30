import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

void main() {
  // Set transparent status bar and nav bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Color(0xFF1E1E2C),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const NFCApp());
}

class NFCApp extends StatelessWidget {
  const NFCApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthService())],
      child: MaterialApp(
        title: 'NFC Attendance',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF1E1E2C),
          primaryColor: const Color(0xFF00BFA6),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00BFA6),
            background: Color(0xFF1E1E2C),
            surface: Color(0xFF2C2C3E),
            onPrimary: Colors.black,
            onBackground: Colors.white,
            onSurface: Colors.white70,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF2C2C3E),
            labelStyle: const TextStyle(color: Color(0xFFA0A0A0)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BFA6),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.orbitron(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          textTheme: GoogleFonts.orbitronTextTheme(ThemeData.dark().textTheme),
        ),
        home: const LoginScreen(),
      ),
    );
  }
}
