import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:nfc_manager/nfc_manager.dart';
import '../services/auth_service.dart';
import 'login_screen.dart'; // ✅ import the login screen

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nfcIdController = TextEditingController();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final courseController = TextEditingController();
  bool loading = false;

  Future<void> registerStudent() async {
    if (nfcIdController.text.isEmpty ||
        nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        courseController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please fill all fields')),
      );
      return;
    }

    setState(() => loading = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    final token = await auth.getToken();

    final response = await http.post(
      Uri.parse('http://192.168.1.31:8000/api/students'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'nfc_id': nfcIdController.text.trim(),
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'course': courseController.text.trim(),
      }),
    );

    setState(() => loading = false);

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Student registered successfully')),
      );
      nfcIdController.clear();
      nameController.clear();
      emailController.clear();
      courseController.clear();
    } else {
      final msg = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed: ${msg['message'] ?? 'Invalid data'}'),
        ),
      );
    }
  }

  Future<void> scanNfcId() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📡 Hold the NFC card near your phone...')),
    );

    await NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        try {
          final tagData = tag.data;

          final identifier =
              tagData['ndef']?['identifier'] ??
              tagData['mifareclassic']?['identifier'] ??
              tagData['nfca']?['identifier'] ??
              tagData['iso7816']?['identifier'] ??
              tagData['felica']?['identifier'];

          if (identifier == null) throw 'Unsupported NFC tag';

          final nfcId =
              identifier is List
                  ? identifier
                      .map((e) => e.toRadixString(16).padLeft(2, '0'))
                      .join()
                      .toUpperCase()
                  : identifier.toString();

          setState(() {
            nfcIdController.text = nfcId;
          });

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('✅ Scanned NFC ID: $nfcId')));
        } catch (e) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('❌ NFC scan error: $e')));
        } finally {
          await NfcManager.instance.stopSession();
        }
      },
    );
  }

  InputDecoration buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFFA0A0A0)),
      prefixIcon: Icon(icon, color: const Color(0xFF00BFA6)),
      filled: true,
      fillColor: const Color(0xFF2C2C3E),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF40404F)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF00BFA6), width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: Text(
          'Register Student',
          style: GoogleFonts.orbitron(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E1E2C),
        foregroundColor: const Color(0xFF00BFA6),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final auth = Provider.of<AuthService>(context, listen: false);
              await auth.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: nfcIdController,
                    style: const TextStyle(color: Color(0xFFE0E0E0)),
                    decoration: buildInputDecoration("NFC ID", Icons.nfc),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: scanNfcId,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BFA6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Icon(Icons.wifi_tethering, color: Colors.black),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Color(0xFFE0E0E0)),
              decoration: buildInputDecoration("Name", Icons.person),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              style: const TextStyle(color: Color(0xFFE0E0E0)),
              keyboardType: TextInputType.emailAddress,
              decoration: buildInputDecoration("Email", Icons.email),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: courseController,
              style: const TextStyle(color: Color(0xFFE0E0E0)),
              decoration: buildInputDecoration("Course", Icons.school),
            ),
            const SizedBox(height: 30),
            loading
                ? const CircularProgressIndicator(color: Color(0xFF00BFA6))
                : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: registerStudent,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF00BFA6),
                      foregroundColor: Colors.black,
                      textStyle: GoogleFonts.orbitron(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Register Student"),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
