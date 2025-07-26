import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:nfc_manager/nfc_manager.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final nfcIdController = TextEditingController();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final courseController = TextEditingController();
  bool loading = false;
  bool isScanning = false;
  Map<String, dynamic>? scannedStudent;

  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _nfcController;
  late AnimationController _scanningController;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _nfcPulseAnimation;
  late Animation<double> _scanningAnimation;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _nfcController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scanningController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _nfcPulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _nfcController, curve: Curves.elasticOut),
    );

    _scanningAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanningController, curve: Curves.easeInOut),
    );

    _slideController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    _nfcController.dispose();
    _scanningController.dispose();
    nfcIdController.dispose();
    nameController.dispose();
    emailController.dispose();
    courseController.dispose();
    super.dispose();
  }

  Future<void> registerStudent() async {
    if (nfcIdController.text.isEmpty ||
        nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        courseController.text.isEmpty) {
      _showTechSnackBar(
        '⚠️ Neural interface incomplete - fill all data nodes',
        Colors.orange,
      );
      return;
    }

    setState(() => loading = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    final token = await auth.getToken();

    final response = await http.post(
      Uri.parse('http://10.148.36.100:8000/api/students'),
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
      _showTechSnackBar(
        '✅ Student matrix synchronized successfully',
        const Color(0xFF00FF88),
      );
      nfcIdController.clear();
      nameController.clear();
      emailController.clear();
      courseController.clear();
      setState(() => scannedStudent = null);
    } else {
      final msg = jsonDecode(response.body);
      _showTechSnackBar(
        '❌ System error: ${msg['message'] ?? 'Data corruption detected'}',
        Colors.red,
      );
    }
  }

  void _showTechSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.sourceCodePro(
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> scanNfcId() async {
    setState(() => isScanning = true);
    _scanningController.repeat();
    _nfcController.forward();

    _showTechSnackBar(
      '📡 Initiating quantum NFC scan...',
      const Color(0xFF00D4FF),
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

          if (identifier == null) throw 'Unsupported quantum signature';

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

          final auth = Provider.of<AuthService>(context, listen: false);
          final token = await auth.getToken();
          final res = await http.get(
            Uri.parse('http://10.148.36.100:8000/api/students/nfc/$nfcId'),
            headers: {'Authorization': 'Bearer $token'},
          );

          if (res.statusCode == 200) {
            setState(() {
              scannedStudent = jsonDecode(res.body);
            });
          } else {
            setState(() => scannedStudent = null);
            _showTechSnackBar(
              '⚠️ Entity not found in neural database',
              Colors.orange,
            );
          }

          _showTechSnackBar(
            '✅ Quantum signature decoded: $nfcId',
            const Color(0xFF00FF88),
          );
        } catch (e) {
          _showTechSnackBar('❌ Quantum interference detected: $e', Colors.red);
        } finally {
          await NfcManager.instance.stopSession();
          setState(() => isScanning = false);
          _scanningController.stop();
          _nfcController.reverse();
        }
      },
    );
  }

  Widget _buildGlowingButton({
    required String text,
    required VoidCallback onPressed,
    required Color color,
    IconData? icon,
    bool isLoading = false,
  }) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 24,
                ),
                backgroundColor: color,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child:
                  isLoading
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.black,
                          ),
                        ),
                      )
                      : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, size: 20),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            text,
                            style: GoogleFonts.orbitron(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTechField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int index = 0,
  }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(0, 0.5 + (index * 0.1)),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _slideController,
          curve: Interval(0.2 + (index * 0.1), 1.0, curve: Curves.easeOutCubic),
        ),
      ),
      child: FadeTransition(
        opacity: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: GoogleFonts.sourceCodePro(
              color: const Color(0xFFE0E0E0),
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: GoogleFonts.orbitron(
                color: const Color(0xFF00D4FF),
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF00D4FF), size: 20),
              ),
              filled: true,
              fillColor: const Color(0xFF1A1A2E).withOpacity(0.8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF16213E),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF00D4FF),
                  width: 2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNfcScanner() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(_slideAnimation),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: nfcIdController,
                style: GoogleFonts.sourceCodePro(
                  color: const Color(0xFFE0E0E0),
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  labelText: "NFC QUANTUM ID",
                  labelStyle: GoogleFonts.orbitron(
                    color: const Color(0xFF00FF88),
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF88).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.nfc,
                      color: Color(0xFF00FF88),
                      size: 20,
                    ),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1A1A2E).withOpacity(0.8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF16213E),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF00FF88),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            AnimatedBuilder(
              animation: _nfcPulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _nfcPulseAnimation.value,
                  child: AnimatedBuilder(
                    animation: _scanningAnimation,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00FF88).withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: isScanning ? 4 : 0,
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: isScanning ? null : scanNfcId,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            backgroundColor: const Color(0xFF00FF88),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child:
                              isScanning
                                  ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.black,
                                      ),
                                    ),
                                  )
                                  : const Icon(
                                    Icons.wifi_tethering,
                                    color: Colors.black,
                                    size: 24,
                                  ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentDataPanel() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _slideController,
          curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic),
        ),
      ),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF00FF88).withOpacity(0.1),
              const Color(0xFF00D4FF).withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF00FF88).withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00FF88).withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person_pin,
                    color: Color(0xFF00FF88),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "NEURAL PROFILE DETECTED",
                  style: GoogleFonts.orbitron(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00FF88),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDataRow(
              "IDENTITY",
              scannedStudent!['name'],
              Icons.account_circle,
            ),
            _buildDataRow(
              "COMM_LINK",
              scannedStudent!['email'],
              Icons.alternate_email,
            ),
            _buildDataRow("PROGRAM", scannedStudent!['course'], Icons.school),
            _buildDataRow(
              "QUANTUM_ID",
              scannedStudent!['nfc_id'],
              Icons.fingerprint,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00D4FF), size: 16),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: GoogleFonts.sourceCodePro(
              color: const Color(0xFF00D4FF),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.sourceCodePro(
                color: Colors.white,
                fontWeight: FontWeight.w400,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'NEURAL REGISTRATION',
          style: GoogleFonts.orbitron(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF00D4FF),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0F0F23).withOpacity(0.9),
                const Color(0xFF1E1E2C).withOpacity(0.7),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.power_settings_new, color: Colors.red),
              ),
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
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0F23), Color(0xFF1E1E2C), Color(0xFF16213E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Header with animated text
                FadeTransition(
                  opacity: _slideAnimation,
                  child: Text(
                    "QUANTUM STUDENT MATRIX",
                    style: GoogleFonts.orbitron(
                      fontSize: 18,
                      fontWeight: FontWeight.w300,
                      color: const Color(0xFF00D4FF).withOpacity(0.8),
                      letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 40),

                // NFC Scanner
                _buildNfcScanner(),

                // Form fields
                _buildTechField(
                  controller: nameController,
                  label: "FULL IDENTITY",
                  icon: Icons.person,
                  index: 1,
                ),
                _buildTechField(
                  controller: emailController,
                  label: "COMM PROTOCOL",
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  index: 2,
                ),
                _buildTechField(
                  controller: courseController,
                  label: "LEARNING PROGRAM",
                  icon: Icons.school,
                  index: 3,
                ),

                const SizedBox(height: 30),

                // Register button
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: _slideController,
                      curve: const Interval(
                        0.8,
                        1.0,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: _buildGlowingButton(
                      text: "INITIALIZE MATRIX",
                      onPressed: registerStudent,
                      color: const Color(0xFF00FF88),
                      icon: Icons.add_circle_outline,
                      isLoading: loading,
                    ),
                  ),
                ),

                // Student data panel
                if (scannedStudent != null) _buildStudentDataPanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
