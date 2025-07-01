import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart'; // ✅ biometric import

import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final LocalAuthentication authBiometric =
      LocalAuthentication(); // ✅ biometric instance
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    return Scaffold(
      body: Stack(
        children: [
          // 🔵 Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0F2027),
                  Color(0xFF203A43),
                  Color(0xFF2C5364),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // 🌫️ Glass Container
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock, color: Colors.white, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'Admin Login',
                        style: GoogleFonts.orbitron(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 30),
                      TextField(
                        controller: emailController,
                        style: const TextStyle(color: Colors.white),
                        decoration: inputDeco("Email", Icons.email),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: inputDeco("Password", Icons.lock),
                      ),
                      const SizedBox(height: 30),

                      loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                setState(() => loading = true);
                                final success = await auth.login(
                                  emailController.text.trim(),
                                  passwordController.text.trim(),
                                );
                                setState(() => loading = false);
                                if (success) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const HomeScreen(),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Login failed'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                backgroundColor: const Color(0xFF00BFA6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                "Login",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),

                      const SizedBox(height: 20),

                      // 🔐 Biometric Login Button
                      ElevatedButton.icon(
                        onPressed: _authenticateWithBiometrics,
                        icon: const Icon(
                          Icons.fingerprint,
                          color: Colors.white,
                        ),
                        label: Text(
                          "Login with Fingerprint",
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white),
      ),
    );
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      bool canCheck = await authBiometric.canCheckBiometrics;
      bool isSupported = await authBiometric.isDeviceSupported();

      if (!canCheck || !isSupported) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication not supported'),
          ),
        );
        return;
      }

      bool authenticated = await authBiometric.authenticate(
        localizedReason: 'Scan your fingerprint to login',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Biometric Error: $e')));
    }
  }
}
