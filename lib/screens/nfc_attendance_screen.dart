import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

class NFCAttendanceScreen extends StatefulWidget {
  const NFCAttendanceScreen({super.key});

  @override
  State<NFCAttendanceScreen> createState() => _NFCAttendanceScreenState();
}

class _NFCAttendanceScreenState extends State<NFCAttendanceScreen> {
  String status = '📲 Tap an NFC card to mark attendance';
  bool scanning = false;

  Future<void> startNfcScan() async {
    setState(() {
      scanning = true;
      status = '🔍 Scanning for NFC...';
    });

    await NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        try {
          final tagData = tag.data;
          print('🔍 Tag data: ${jsonEncode(tagData)}');

          final identifier =
              tagData['ndef']?['identifier'] ??
              tagData['mifareclassic']?['identifier'] ??
              tagData['nfca']?['identifier'] ??
              tagData['iso7816']?['identifier'] ??
              tagData['felica']?['identifier'];

          if (identifier == null) {
            throw 'Unsupported NFC tag';
          }

          final nfcId =
              identifier is List
                  ? identifier
                      .map((e) => e.toRadixString(16).padLeft(2, '0'))
                      .join()
                      .toUpperCase()
                  : identifier.toString();

          setState(
            () =>
                status = '🆔 Detected NFC ID: $nfcId\n📡 Marking attendance...',
          );

          final token =
              await Provider.of<AuthService>(context, listen: false).getToken();
          final response = await http.post(
            Uri.parse('http://10.129.38.100:8000/api/attendance/mark'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'nfc_id': nfcId}),
          );

          final body = jsonDecode(response.body);

          if (response.statusCode == 200) {
            setState(() {
              status =
                  '✅ Attendance marked for ${body['student']} on ${body['date']}';
            });
          } else {
            setState(() {
              status = '❌ Failed: ${body['message'] ?? 'Unknown error'}';
            });
          }
        } catch (e) {
          setState(() => status = '❌ Scan error: $e');
        } finally {
          await NfcManager.instance.stopSession();
          setState(() => scanning = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: Text(
          'NFC Attendance',
          style: GoogleFonts.orbitron(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E1E2C),
        foregroundColor: const Color(0xFF00BFA6),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShaderMask(
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    colors: [Color(0xFF00BFA6), Color(0xFF00FFC6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds);
                },
                child: const Icon(Icons.nfc, size: 100, color: Colors.white),
              ),
              const SizedBox(height: 30),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: GoogleFonts.orbitron(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: scanning ? Colors.amberAccent : Colors.white70,
                ),
                child: Text(status, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 40),
              scanning
                  ? const CircularProgressIndicator(color: Color(0xFF00BFA6))
                  : ElevatedButton.icon(
                    icon: const Icon(Icons.play_circle_fill),
                    label: const Text('Start Scan'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      backgroundColor: const Color(0xFF00BFA6),
                      foregroundColor: Colors.black,
                      textStyle: GoogleFonts.orbitron(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {
                      try {
                        await startNfcScan();
                      } catch (e) {
                        setState(() => status = '❌ Error starting scan: $e');
                      }
                    },
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
