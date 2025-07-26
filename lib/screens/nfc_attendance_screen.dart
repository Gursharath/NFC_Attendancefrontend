import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _NFCAttendanceScreenState extends State<NFCAttendanceScreen>
    with TickerProviderStateMixin {
  String status = '📲 Ready to scan neural signatures...';
  bool scanning = false;
  String? lastScannedId;
  DateTime? lastScanTime;

  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late AnimationController _scanController;
  late AnimationController _statusController;

  // Animations
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _scanAnimation;
  late Animation<double> _statusAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Pulse animation for the main NFC icon
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Glow animation for borders and effects
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Scan animation (rotating effect)
    _scanController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _scanAnimation = Tween<double>(
      begin: 0,
      end: 2 * pi,
    ).animate(CurvedAnimation(parent: _scanController, curve: Curves.linear));

    // Status animation
    _statusController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _statusAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _statusController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    _scanController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  Future<void> startNfcScan() async {
    setState(() {
      scanning = true;
      status = '🔍 Scanning quantum signatures...';
    });

    // Start scan animation
    _scanController.repeat();
    _statusController.forward();

    // Haptic feedback
    HapticFeedback.mediumImpact();

    await NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        try {
          // Stop scan animation
          _scanController.stop();

          final tagData = tag.data;
          print('🔍 Neural data detected: ${jsonEncode(tagData)}');

          final identifier =
              tagData['ndef']?['identifier'] ??
              tagData['mifareclassic']?['identifier'] ??
              tagData['nfca']?['identifier'] ??
              tagData['iso7816']?['identifier'] ??
              tagData['felica']?['identifier'];

          if (identifier == null) {
            throw 'Incompatible neural signature detected';
          }

          final nfcId =
              identifier is List
                  ? identifier
                      .map((e) => e.toRadixString(16).padLeft(2, '0'))
                      .join()
                      .toUpperCase()
                  : identifier.toString();

          setState(() {
            status =
                '🆔 NEURAL_ID: $nfcId\n📡 Syncing with quantum database...';
            lastScannedId = nfcId;
          });

          // Success haptic
          HapticFeedback.lightImpact();

          final token =
              await Provider.of<AuthService>(context, listen: false).getToken();
          final response = await http.post(
            Uri.parse('http://10.148.36.100:8000/api/attendance/mark'),
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
                  '✅ QUANTUM_SYNC_SUCCESS\nENTITY: ${body['student']}\nTEMPORAL_STAMP: ${body['date']}';
              lastScanTime = DateTime.now();
            });
            HapticFeedback.lightImpact();
            _showSuccessNotification(body['student']);
          } else {
            setState(() {
              status =
                  '❌ SYNC_ERROR: ${body['message'] ?? 'Unknown neural disruption'}';
            });
            HapticFeedback.heavyImpact();
            _showErrorNotification(body['message'] ?? 'Unknown error');
          }
        } catch (e) {
          setState(() => status = '❌ NEURAL_ERROR: $e');
          HapticFeedback.heavyImpact();
          _showErrorNotification(e.toString());
        } finally {
          await NfcManager.instance.stopSession();
          setState(() => scanning = false);
          _scanController.stop();
          _statusController.reverse();
        }
      },
    );
  }

  void _showSuccessNotification(String student) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00BFA6), Color(0xFF00FFC6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00BFA6).withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.black),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Neural sync successful for $student',
                  style: GoogleFonts.orbitron(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorNotification(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.redAccent, Colors.red],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Neural error: $error',
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildGlowingContainer({
    required Widget child,
    Color glowColor = const Color(0xFF00BFA6),
    double glowIntensity = 0.3,
  }) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: glowColor.withOpacity(
                  glowIntensity * _glowAnimation.value,
                ),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2A2A3E).withOpacity(0.8),
                  const Color(0xFF1E1E2C).withOpacity(0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: glowColor.withOpacity(0.3 + 0.3 * _glowAnimation.value),
                width: 1,
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildScanButton() {
    return AnimatedBuilder(
      animation: Listenable.merge([_glowAnimation, _scanAnimation]),
      builder: (context, _) {
        return Container(
          width: 200,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF00BFA6,
                ).withOpacity(0.3 * _glowAnimation.value),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ElevatedButton.icon(
            icon:
                scanning
                    ? Transform.rotate(
                      angle: _scanAnimation.value,
                      child: const Icon(Icons.sync, size: 24),
                    )
                    : const Icon(Icons.nfc, size: 24),
            label: Text(
              scanning ? 'SCANNING...' : 'INITIATE_SCAN',
              style: GoogleFonts.orbitron(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              backgroundColor:
                  scanning
                      ? Colors.amberAccent.withOpacity(0.8)
                      : const Color(0xFF00BFA6),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
            ),
            onPressed:
                scanning
                    ? null
                    : () async {
                      try {
                        await startNfcScan();
                      } catch (e) {
                        setState(() => status = '❌ SYSTEM_ERROR: $e');
                        _showErrorNotification(e.toString());
                      }
                    },
          ),
        );
      },
    );
  }

  Widget _buildStatsCard() {
    return _buildGlowingContainer(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'NEURAL_DATABASE_STATUS',
              style: GoogleFonts.orbitron(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00BFA6),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'ACTIVE_SCANS',
                  scanning ? '1' : '0',
                  Icons.radar,
                  scanning ? Colors.amberAccent : const Color(0xFF00BFA6),
                ),
                _buildStatItem(
                  'LAST_SYNC',
                  lastScanTime != null
                      ? '${DateTime.now().difference(lastScanTime!).inMinutes}m ago'
                      : 'N/A',
                  Icons.access_time,
                  Colors.cyanAccent,
                ),
                _buildStatItem(
                  'STATUS',
                  'ONLINE',
                  Icons.cloud_done,
                  Colors.greenAccent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.sourceCodePro(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.sourceCodePro(fontSize: 10, color: Colors.white60),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0A0F), Color(0xFF1E1E2C), Color(0xFF2A2A3E)],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Custom App Bar
              SliverAppBar(
                expandedHeight: 120,
                floating: false,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    'NEURAL_SCANNER',
                    style: GoogleFonts.orbitron(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: const Color(0xFF00BFA6),
                    ),
                  ),
                  centerTitle: true,
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF2A2A3E), Colors.transparent],
                      ),
                    ),
                  ),
                ),
                actions: [
                  AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, _) {
                      return Container(
                        margin: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF00BFA6,
                              ).withOpacity(0.3 * _glowAnimation.value),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            // Add settings functionality
                          },
                          icon: const Icon(Icons.settings),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(
                              0xFF2A2A3E,
                            ).withOpacity(0.8),
                            foregroundColor: const Color(0xFF00BFA6),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),

              // Main Content
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Stats Card
                    _buildStatsCard(),
                    const SizedBox(height: 30),

                    // Main NFC Scanner
                    _buildGlowingContainer(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            // Animated NFC Icon
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, _) {
                                return Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors:
                                            scanning
                                                ? [
                                                  Colors.amberAccent
                                                      .withOpacity(0.3),
                                                  Colors.amberAccent
                                                      .withOpacity(0.1),
                                                  Colors.transparent,
                                                ]
                                                : [
                                                  const Color(
                                                    0xFF00BFA6,
                                                  ).withOpacity(0.3),
                                                  const Color(
                                                    0xFF00FFC6,
                                                  ).withOpacity(0.1),
                                                  Colors.transparent,
                                                ],
                                      ),
                                    ),
                                    child: Center(
                                      child: ShaderMask(
                                        shaderCallback: (bounds) {
                                          return LinearGradient(
                                            colors:
                                                scanning
                                                    ? [
                                                      Colors.amberAccent,
                                                      Colors.amber,
                                                    ]
                                                    : [
                                                      const Color(0xFF00BFA6),
                                                      const Color(0xFF00FFC6),
                                                    ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ).createShader(bounds);
                                        },
                                        child: Icon(
                                          scanning ? Icons.radar : Icons.nfc,
                                          size: 60,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 30),

                            // Status Display
                            AnimatedBuilder(
                              animation: _statusAnimation,
                              builder: (context, _) {
                                return Transform.scale(
                                  scale: _statusAnimation.value,
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors:
                                            scanning
                                                ? [
                                                  Colors.amberAccent
                                                      .withOpacity(0.1),
                                                  Colors.amber.withOpacity(
                                                    0.05,
                                                  ),
                                                ]
                                                : [
                                                  const Color(
                                                    0xFF00BFA6,
                                                  ).withOpacity(0.1),
                                                  const Color(
                                                    0xFF00FFC6,
                                                  ).withOpacity(0.05),
                                                ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color:
                                            scanning
                                                ? Colors.amberAccent
                                                    .withOpacity(0.3)
                                                : const Color(
                                                  0xFF00BFA6,
                                                ).withOpacity(0.3),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          'SYSTEM_STATUS',
                                          style: GoogleFonts.orbitron(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                scanning
                                                    ? Colors.amberAccent
                                                    : const Color(0xFF00BFA6),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          status,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.sourceCodePro(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color:
                                                scanning
                                                    ? Colors.amberAccent
                                                    : Colors.white70,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 40),

                            // Scan Button
                            _buildScanButton(),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Last Scan Info
                    if (lastScannedId != null) ...[
                      _buildGlowingContainer(
                        glowColor: Colors.cyanAccent,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF00BFA6),
                                          Color(0xFF00FFC6),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.history,
                                      color: Colors.black,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'LAST_NEURAL_SIGNATURE',
                                    style: GoogleFonts.orbitron(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.cyanAccent,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF1E1E2C,
                                  ).withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.cyanAccent.withOpacity(0.2),
                                  ),
                                ),
                                child: Text(
                                  lastScannedId!,
                                  style: GoogleFonts.sourceCodePro(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.cyanAccent,
                                    letterSpacing: 2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
