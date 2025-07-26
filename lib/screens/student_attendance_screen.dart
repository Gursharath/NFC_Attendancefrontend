import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/auth_service.dart';

class StudentAttendanceScreen extends StatefulWidget {
  final int studentId;
  final String studentName;

  const StudentAttendanceScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen>
    with TickerProviderStateMixin {
  List<dynamic> history = [];
  List<dynamic> filteredHistory = [];
  bool loading = true;
  String? searchDate;

  late AnimationController _mainController;
  late AnimationController _cardController;
  late AnimationController _glowController;
  late AnimationController _searchController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _searchAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    fetchAttendanceHistory();
  }

  void _initializeAnimations() {
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _cardController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _searchController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _mainController, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _mainController, curve: Curves.easeOut));

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _searchAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _searchController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _cardController.dispose();
    _glowController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchAttendanceHistory() async {
    final token =
        await Provider.of<AuthService>(context, listen: false).getToken();
    final response = await http.get(
      Uri.parse(
        'http://10.148.36.100:8000/api/attendance/${widget.studentId}/history',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        history = jsonDecode(response.body);
        filteredHistory = history;
        loading = false;
      });
      _mainController.forward();
      _cardController.forward();
      _searchController.forward();
    } else {
      setState(() => loading = false);
      _showTechNotification(
        '❌ Neural link failed to retrieve attendance data',
        isError: true,
      );
    }
  }

  void _showTechNotification(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      isError
                          ? const Color(0xFFFF6B6B)
                          : const Color(0xFF00FF88),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color:
                          isError
                              ? const Color(0xFFFF6B6B)
                              : const Color(0xFF00FF88),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Source Code Pro',
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF1E1E2C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isError ? const Color(0xFFFF6B6B) : const Color(0xFF00FF88),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void filterByDate(String query) {
    setState(() {
      searchDate = query;
      filteredHistory =
          history
              .where(
                (record) =>
                    record['date'].toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
    });

    // Restart card animations for filtered results
    _cardController.reset();
    _cardController.forward();
  }

  Future<void> _downloadCSV() async {
    HapticFeedback.mediumImpact();

    final csvData = [
      ['TEMPORAL_INDEX', 'QUANTUM_TIMESTAMP'],
      ...filteredHistory.map((row) => [row['date'], row['time_marked']]),
    ];

    String csv = const ListToCsvConverter().convert(csvData);

    final directory = await getApplicationDocumentsDirectory();
    final path =
        '${directory.path}/neural_attendance_${widget.studentName}.csv';
    final file = File(path);
    await file.writeAsString(csv);

    Share.shareXFiles([
      XFile(path),
    ], text: '🚀 Quantum attendance data for ${widget.studentName}');

    _showTechNotification('📊 Neural data exported to quantum storage');
  }

  Future<void> _printData() async {
    HapticFeedback.mediumImpact();

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.black,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '🚀 NEURAL ATTENDANCE MATRIX',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.cyan,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'QUANTUM ENTITY: ${widget.studentName}',
                      style: pw.TextStyle(fontSize: 16, color: PdfColors.white),
                    ),
                    pw.Text(
                      'TEMPORAL_ENTRIES: ${filteredHistory.length}',
                      style: pw.TextStyle(fontSize: 16, color: PdfColors.green),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: ['TEMPORAL_INDEX', 'QUANTUM_TIMESTAMP'],
                data:
                    filteredHistory.map((e) {
                      return [e['date'] ?? 'NULL', e['time_marked'] ?? 'NULL'];
                    }).toList(),
                border: pw.TableBorder.all(color: PdfColors.cyan, width: 1),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.cyan),
                cellAlignment: pw.Alignment.centerLeft,
                cellStyle: const pw.TextStyle(fontSize: 12),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(2),
                },
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    _showTechNotification('🖨️ Quantum data transmitted to print matrix');
  }

  Widget _buildAnimatedCard(dynamic record, int index) {
    return AnimatedBuilder(
      animation: _cardController,
      builder: (context, child) {
        final cardAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _cardController,
            curve: Interval(
              (index * 0.1).clamp(0.0, 1.0),
              ((index * 0.1) + 0.3).clamp(0.0, 1.0),
              curve: Curves.easeOut,
            ),
          ),
        );

        final slideAnimation = Tween<Offset>(
          begin: const Offset(0.3, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: _cardController, curve: Curves.easeOut),
        );

        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: cardAnimation,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E1E2C), Color(0xFF2C2C3E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: const Color(0xFF00D4FF).withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D4FF).withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => HapticFeedback.lightImpact(),
                    borderRadius: BorderRadius.circular(16),
                    splashColor: const Color(0xFF00D4FF).withOpacity(0.1),
                    highlightColor: const Color(0xFF00D4FF).withOpacity(0.05),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00D4FF), Color(0xFF00FF88)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF00D4FF,
                                  ).withOpacity(0.3),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.access_time_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'TEMPORAL_INDEX',
                                      style: TextStyle(
                                        color: const Color(0xFF00D4FF),
                                        fontSize: 12,
                                        fontFamily: 'Source Code Pro',
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (index <
                                        3) // Show "NEW" badge for recent entries
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00FF88),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF00FF88,
                                              ).withOpacity(0.5),
                                              blurRadius: 8,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                        child: const Text(
                                          'NEW',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Source Code Pro',
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  record['date'] ?? 'NULL',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Orbitron',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'QUANTUM_TIMESTAMP',
                                  style: TextStyle(
                                    color: const Color(0xFF00FF88),
                                    fontSize: 12,
                                    fontFamily: 'Source Code Pro',
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  record['time_marked'] ?? 'NULL',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 16,
                                    fontFamily: 'Source Code Pro',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _glowAnimation,
                            builder: (context, child) {
                              return Container(
                                width: 4,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00D4FF),
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF00D4FF,
                                      ).withOpacity(_glowAnimation.value * 0.8),
                                      blurRadius: 12 * _glowAnimation.value,
                                      spreadRadius: 2 * _glowAnimation.value,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalDays = filteredHistory.length;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0F23), Color(0xFF1E1E2C), Color(0xFF16213E)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E2C),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF00D4FF).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_rounded,
                          color: Color(0xFF00D4FF),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'NEURAL ATTENDANCE',
                            style: TextStyle(
                              color: Color(0xFF00D4FF),
                              fontSize: 14,
                              fontFamily: 'Source Code Pro',
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'MATRIX',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontFamily: 'Orbitron',
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: const Color(
                                    0xFF00D4FF,
                                  ).withOpacity(0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _glowAnimation,
                      builder: (context, child) {
                        return Row(
                          children: [
                            GestureDetector(
                              onTap: _printData,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E2C),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Color(0xFF00FF88).withOpacity(
                                      0.3 + (0.7 * _glowAnimation.value),
                                    ),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF00FF88,
                                      ).withOpacity(_glowAnimation.value * 0.3),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.print_rounded,
                                  color: Color(0xFF00FF88).withOpacity(
                                    0.7 + (0.3 * _glowAnimation.value),
                                  ),
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: _downloadCSV,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E2C),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Color(0xFF00D4FF).withOpacity(
                                      0.3 + (0.7 * _glowAnimation.value),
                                    ),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF00D4FF,
                                      ).withOpacity(_glowAnimation.value * 0.3),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.download_rounded,
                                  color: Color(0xFF00D4FF).withOpacity(
                                    0.7 + (0.3 * _glowAnimation.value),
                                  ),
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              if (loading)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            const Color(0xFF00D4FF),
                          ),
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'ACCESSING NEURAL DATABASE...',
                        style: TextStyle(
                          color: const Color(0xFF00D4FF),
                          fontSize: 16,
                          fontFamily: 'Source Code Pro',
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Quantum signature verification in progress',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                          fontFamily: 'Source Code Pro',
                        ),
                      ),
                    ],
                  ),
                )
              else
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          // Student Info Header
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1E1E2C), Color(0xFF2C2C3E)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: const Color(0xFF00FF88).withOpacity(0.3),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF00FF88,
                                  ).withOpacity(0.1),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF00FF88),
                                            Color(0xFF00D4FF),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF00FF88,
                                            ).withOpacity(0.3),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.person_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'QUANTUM_ENTITY',
                                            style: TextStyle(
                                              color: const Color(0xFF00FF88),
                                              fontSize: 12,
                                              fontFamily: 'Source Code Pro',
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            widget.studentName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontFamily: 'Orbitron',
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F0F23),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF00D4FF,
                                      ).withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'TEMPORAL_ENTRIES',
                                            style: TextStyle(
                                              color: const Color(0xFF00D4FF),
                                              fontSize: 12,
                                              fontFamily: 'Source Code Pro',
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$totalDays',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 28,
                                              fontFamily: 'Orbitron',
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      Container(
                                        width: 4,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00D4FF),
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF00D4FF,
                                              ).withOpacity(0.5),
                                              blurRadius: 8,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Search Bar
                          AnimatedBuilder(
                            animation: _searchAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _searchAnimation.value,
                                child: Container(
                                  margin: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF1E1E2C),
                                        Color(0xFF2C2C3E),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF00D4FF,
                                      ).withOpacity(0.3),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF00D4FF,
                                        ).withOpacity(0.1),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: TextField(
                                    onChanged: filterByDate,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Source Code Pro',
                                      fontSize: 16,
                                    ),
                                    decoration: InputDecoration(
                                      hintText:
                                          'SEARCH TEMPORAL_INDEX (e.g. 2025-07-25)',
                                      hintStyle: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontFamily: 'Source Code Pro',
                                        fontSize: 14,
                                      ),
                                      prefixIcon: Container(
                                        padding: const EdgeInsets.all(12),
                                        child: Icon(
                                          Icons.search_rounded,
                                          color: const Color(0xFF00D4FF),
                                          size: 24,
                                        ),
                                      ),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 20,
                                            horizontal: 20,
                                          ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          // Content Area
                          Expanded(
                            child:
                                filteredHistory.isEmpty
                                    ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 120,
                                            height: 120,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: LinearGradient(
                                                colors: [
                                                  const Color(
                                                    0xFFFF6B6B,
                                                  ).withOpacity(0.3),
                                                  const Color(
                                                    0xFFFF6B6B,
                                                  ).withOpacity(0.1),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              border: Border.all(
                                                color: const Color(
                                                  0xFFFF6B6B,
                                                ).withOpacity(0.3),
                                                width: 2,
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.search_off_rounded,
                                              size: 50,
                                              color: const Color(
                                                0xFFFF6B6B,
                                              ).withOpacity(0.7),
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                          Text(
                                            'NO NEURAL SIGNATURES FOUND',
                                            style: TextStyle(
                                              color: const Color(0xFFFF6B6B),
                                              fontSize: 18,
                                              fontFamily: 'Orbitron',
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Quantum database query returned empty matrix',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(
                                                0.6,
                                              ),
                                              fontSize: 14,
                                              fontFamily: 'Source Code Pro',
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    : ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        0,
                                        20,
                                        100,
                                      ),
                                      itemCount: filteredHistory.length,
                                      itemBuilder: (context, index) {
                                        final record = filteredHistory[index];
                                        return _buildAnimatedCard(
                                          record,
                                          index,
                                        );
                                      },
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      // Floating Action Button for quick actions
      floatingActionButton: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFF00FF88,
                  ).withOpacity(_glowAnimation.value * 0.5),
                  blurRadius: 20 * _glowAnimation.value,
                  spreadRadius: 5 * _glowAnimation.value,
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                fetchAttendanceHistory();
              },
              backgroundColor: const Color(0xFF00FF88),
              child: const Icon(
                Icons.refresh_rounded,
                color: Colors.black,
                size: 28,
              ),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
