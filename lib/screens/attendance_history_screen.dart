import 'dart:convert';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../services/auth_service.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen>
    with TickerProviderStateMixin {
  List<dynamic> history = [];
  List<dynamic> filtered = [];
  bool loading = true;
  String searchQuery = '';
  DateTimeRange? dateRange;

  late AnimationController _mainController;
  late AnimationController _cardController;
  late AnimationController _glowController;
  late AnimationController _searchController;
  late AnimationController _statsController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _searchAnimation;
  late Animation<double> _statsAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    fetchAllHistory();
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

    _statsController = AnimationController(
      duration: const Duration(milliseconds: 1000),
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

    _statsAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _statsController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _mainController.dispose();
    _cardController.dispose();
    _glowController.dispose();
    _searchController.dispose();
    _statsController.dispose();
    super.dispose();
  }

  void _showTechNotification(String message, {bool isError = false}) {
    HapticFeedback.lightImpact();
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

  Future<void> fetchAllHistory() async {
    setState(() => loading = true);
    final token =
        await Provider.of<AuthService>(context, listen: false).getToken();
    final response = await http.get(
      Uri.parse('http://10.148.36.100:8000/api/attendance/today'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      setState(() {
        history = data;
        filtered = data;
        loading = false;
      });
      _mainController.forward();
      _cardController.forward();
      _searchController.forward();
      _statsController.forward();
    } else {
      setState(() => loading = false);
      _showTechNotification(
        '❌ Neural link failed to access quantum database',
        isError: true,
      );
    }
  }

  void applySearch(String query) {
    setState(() {
      searchQuery = query;
      filtered =
          history.where((record) {
            final student = record['student'];
            final name = student?['name']?.toLowerCase() ?? '';
            return name.contains(query.toLowerCase());
          }).toList();
    });

    // Restart card animations for filtered results
    _cardController.reset();
    _cardController.forward();
  }

  void filterByDate(DateTimeRange range) {
    setState(() {
      dateRange = range;
      filtered =
          history.where((record) {
            final dateStr = record['date'];
            final date = DateTime.tryParse(dateStr);
            if (date == null) return false;
            return date.isAfter(
                  range.start.subtract(const Duration(days: 1)),
                ) &&
                date.isBefore(range.end.add(const Duration(days: 1)));
          }).toList();
    });

    _cardController.reset();
    _cardController.forward();
  }

  Future<void> exportAsPDF() async {
    HapticFeedback.mediumImpact();

    final PdfDocument doc = PdfDocument();
    final page = doc.pages.add();

    // Add header
    final PdfFont headerFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      18,
      style: PdfFontStyle.bold,
    );
    final PdfFont subHeaderFont = PdfStandardFont(PdfFontFamily.helvetica, 12);

    page.graphics.drawString(
      '🚀 NEURAL ATTENDANCE MATRIX',
      headerFont,
      bounds: const Rect.fromLTWH(0, 0, 500, 30),
      brush: PdfSolidBrush(PdfColor(0, 212, 255)),
    );

    page.graphics.drawString(
      'Quantum Database Export • Total Entities: ${filtered.length}',
      subHeaderFont,
      bounds: const Rect.fromLTWH(0, 35, 500, 20),
      brush: PdfSolidBrush(PdfColor(128, 128, 128)),
    );

    final PdfGrid grid = PdfGrid();
    grid.columns.add(count: 4);
    grid.headers.add(1);
    grid.headers[0].cells[0].value = 'QUANTUM_ENTITY';
    grid.headers[0].cells[1].value = 'PROGRAM_CODE';
    grid.headers[0].cells[2].value = 'TEMPORAL_INDEX';
    grid.headers[0].cells[3].value = 'QUANTUM_TIMESTAMP';

    // Style headers
    for (int i = 0; i < 4; i++) {
      grid.headers[0].cells[i].style.backgroundBrush = PdfSolidBrush(
        PdfColor(0, 212, 255),
      );
      grid.headers[0].cells[i].style.textBrush = PdfSolidBrush(
        PdfColor(0, 0, 0),
      );
      grid.headers[0].cells[i].style.font = PdfStandardFont(
        PdfFontFamily.helvetica,
        10,
        style: PdfFontStyle.bold,
      );
    }

    for (var record in filtered) {
      final student = record['student'];
      final row = grid.rows.add();
      row.cells[0].value = student?['name'] ?? 'UNKNOWN_ENTITY';
      row.cells[1].value = student?['course'] ?? 'NULL_PROGRAM';
      row.cells[2].value = record['date'] ?? 'NULL_DATE';
      row.cells[3].value = record['time_marked'] ?? 'NULL_TIME';

      // Style data cells
      for (int i = 0; i < 4; i++) {
        row.cells[i].style.font = PdfStandardFont(PdfFontFamily.helvetica, 9);
        row.cells[i].style.textBrush = PdfSolidBrush(PdfColor(64, 64, 64));
      }
    }

    grid.draw(page: page, bounds: const Rect.fromLTWH(0, 70, 500, 700));
    final bytes = await doc.save();
    doc.dispose();

    await FileSaver.instance.saveFile(
      name: 'Neural_Attendance_Matrix',
      bytes: Uint8List.fromList(bytes),
      mimeType: MimeType.pdf,
    );

    _showTechNotification('📊 Quantum data exported to storage matrix');
  }

  Future<void> showDateFilter() async {
    HapticFeedback.lightImpact();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00D4FF),
              surface: Color(0xFF1E1E2C),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      filterByDate(picked);
      _showTechNotification('🕒 Temporal filter applied to neural matrix');
    }
  }

  void sortByName() {
    HapticFeedback.selectionClick();
    setState(() {
      filtered.sort((a, b) {
        final nameA = a['student']?['name'] ?? '';
        final nameB = b['student']?['name'] ?? '';
        return nameA.compareTo(nameB);
      });
    });
    _cardController.reset();
    _cardController.forward();
    _showTechNotification('📝 Entities sorted by quantum signature');
  }

  void sortByDate() {
    HapticFeedback.selectionClick();
    setState(() {
      filtered.sort((a, b) {
        final dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(2000);
        final dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(2000);
        return dateB.compareTo(dateA); // Descending
      });
    });
    _cardController.reset();
    _cardController.forward();
    _showTechNotification('📅 Matrix sorted by temporal sequence');
  }

  Widget _buildAnimatedCard(dynamic record, int index) {
    final student = record['student'];

    return AnimatedBuilder(
      animation: _cardController,
      builder: (context, child) {
        final cardAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _cardController,
            curve: Interval(
              (index * 0.05).clamp(0.0, 1.0),
              ((index * 0.05) + 0.3).clamp(0.0, 1.0),
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
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                                colors: [Color(0xFF00FF88), Color(0xFF00D4FF)],
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
                                      'QUANTUM_ENTITY',
                                      style: TextStyle(
                                        color: const Color(0xFF00FF88),
                                        fontSize: 11,
                                        fontFamily: 'Source Code Pro',
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (index <
                                        5) // Show "NEW" badge for recent entries
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
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Source Code Pro',
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  student?['name'] ?? 'UNKNOWN_ENTITY',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Orbitron',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'PROGRAM_CODE',
                                            style: TextStyle(
                                              color: const Color(0xFF00D4FF),
                                              fontSize: 11,
                                              fontFamily: 'Source Code Pro',
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            student?['course'] ??
                                                'NULL_PROGRAM',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(
                                                0.9,
                                              ),
                                              fontSize: 14,
                                              fontFamily: 'Source Code Pro',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'TEMPORAL_DATA',
                                          style: TextStyle(
                                            color: const Color(0xFFFF6B6B),
                                            fontSize: 11,
                                            fontFamily: 'Source Code Pro',
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${record['date']} • ${record['time_marked']}',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.9,
                                            ),
                                            fontSize: 14,
                                            fontFamily: 'Source Code Pro',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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

  Widget _buildStatsCard() {
    return AnimatedBuilder(
      animation: _statsAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _statsAnimation.value,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  color: const Color(0xFF00FF88).withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NEURAL_DATABASE',
                          style: TextStyle(
                            color: const Color(0xFF00FF88),
                            fontSize: 12,
                            fontFamily: 'Source Code Pro',
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'STATUS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontFamily: 'Orbitron',
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: const Color(0xFF00FF88).withOpacity(0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00FF88), Color(0xFF00D4FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00FF88).withOpacity(0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.analytics_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F0F23),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF00D4FF).withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL_ENTITIES',
                              style: TextStyle(
                                color: const Color(0xFF00D4FF),
                                fontSize: 11,
                                fontFamily: 'Source Code Pro',
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${filtered.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F0F23),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF00FF88).withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ACTIVE_STATUS',
                              style: TextStyle(
                                color: const Color(0xFF00FF88),
                                fontSize: 11,
                                fontFamily: 'Source Code Pro',
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ONLINE',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                            'NEURAL DATABASE',
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
                            'RECORDS',
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
                              onTap: showDateFilter,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E2C),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Color(0xFFFF6B6B).withOpacity(
                                      0.3 + (0.7 * _glowAnimation.value),
                                    ),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFFF6B6B,
                                      ).withOpacity(_glowAnimation.value * 0.3),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.date_range_rounded,
                                  color: Color(0xFFFF6B6B).withOpacity(
                                    0.7 + (0.3 * _glowAnimation.value),
                                  ),
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: exportAsPDF,
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
                                  Icons.picture_as_pdf_rounded,
                                  color: Color(0xFF00FF88).withOpacity(
                                    0.7 + (0.3 * _glowAnimation.value),
                                  ),
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () async {
                                HapticFeedback.mediumImpact();

                                final PdfDocument doc = PdfDocument();
                                final page = doc.pages.add();

                                // Add header
                                final PdfFont headerFont = PdfStandardFont(
                                  PdfFontFamily.helvetica,
                                  18,
                                  style: PdfFontStyle.bold,
                                );
                                final PdfFont subHeaderFont = PdfStandardFont(
                                  PdfFontFamily.helvetica,
                                  12,
                                );

                                page.graphics.drawString(
                                  '🚀 NEURAL ATTENDANCE MATRIX',
                                  headerFont,
                                  bounds: const Rect.fromLTWH(0, 0, 500, 30),
                                  brush: PdfSolidBrush(PdfColor(0, 212, 255)),
                                );

                                page.graphics.drawString(
                                  'Quantum Database Print • Total Entities: ${filtered.length}',
                                  subHeaderFont,
                                  bounds: const Rect.fromLTWH(0, 35, 500, 20),
                                  brush: PdfSolidBrush(PdfColor(128, 128, 128)),
                                );

                                final PdfGrid grid = PdfGrid();
                                grid.columns.add(count: 4);
                                grid.headers.add(1);
                                grid.headers[0].cells[0].value =
                                    'QUANTUM_ENTITY';
                                grid.headers[0].cells[1].value = 'PROGRAM_CODE';
                                grid.headers[0].cells[2].value =
                                    'TEMPORAL_INDEX';
                                grid.headers[0].cells[3].value =
                                    'QUANTUM_TIMESTAMP';

                                // Style headers
                                for (int i = 0; i < 4; i++) {
                                  grid
                                      .headers[0]
                                      .cells[i]
                                      .style
                                      .backgroundBrush = PdfSolidBrush(
                                    PdfColor(0, 212, 255),
                                  );
                                  grid.headers[0].cells[i].style.textBrush =
                                      PdfSolidBrush(PdfColor(0, 0, 0));
                                  grid
                                      .headers[0]
                                      .cells[i]
                                      .style
                                      .font = PdfStandardFont(
                                    PdfFontFamily.helvetica,
                                    10,
                                    style: PdfFontStyle.bold,
                                  );
                                }

                                for (var record in filtered) {
                                  final student = record['student'];
                                  final row = grid.rows.add();
                                  row.cells[0].value =
                                      student?['name'] ?? 'UNKNOWN_ENTITY';
                                  row.cells[1].value =
                                      student?['course'] ?? 'NULL_PROGRAM';
                                  row.cells[2].value =
                                      record['date'] ?? 'NULL_DATE';
                                  row.cells[3].value =
                                      record['time_marked'] ?? 'NULL_TIME';

                                  // Style data cells
                                  for (int i = 0; i < 4; i++) {
                                    row.cells[i].style.font = PdfStandardFont(
                                      PdfFontFamily.helvetica,
                                      9,
                                    );
                                    row.cells[i].style.textBrush =
                                        PdfSolidBrush(PdfColor(64, 64, 64));
                                  }
                                }

                                grid.draw(
                                  page: page,
                                  bounds: const Rect.fromLTWH(0, 70, 500, 700),
                                );
                                final bytes = await doc.save();
                                doc.dispose();

                                await Printing.layoutPdf(
                                  onLayout:
                                      (PdfPageFormat format) async =>
                                          Uint8List.fromList(bytes),
                                );

                                _showTechNotification(
                                  '🖨️ Quantum data transmitted to print matrix',
                                );
                              },
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
                                  Icons.print_rounded,
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
                        'Quantum signature synchronization in progress',
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
                  child: RefreshIndicator(
                    onRefresh: fetchAllHistory,
                    backgroundColor: const Color(0xFF1E1E2C),
                    color: const Color(0xFF00D4FF),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          children: [
                            // Stats Card
                            _buildStatsCard(),

                            // Search Bar
                            AnimatedBuilder(
                              animation: _searchAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _searchAnimation.value,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 8,
                                    ),
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
                                      onChanged: applySearch,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Source Code Pro',
                                        fontSize: 16,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'SEARCH QUANTUM_ENTITY...',
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

                            // Sort Buttons
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: sortByName,
                                      child: AnimatedBuilder(
                                        animation: _glowAnimation,
                                        builder: (context, child) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                              horizontal: 20,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF1E1E2C),
                                                  Color(0xFF2C2C3E),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              border: Border.all(
                                                color: Color(
                                                  0xFF00FF88,
                                                ).withOpacity(
                                                  0.3 +
                                                      (0.4 *
                                                          _glowAnimation.value),
                                                ),
                                                width: 1,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFF00FF88,
                                                  ).withOpacity(
                                                    _glowAnimation.value * 0.2,
                                                  ),
                                                  blurRadius: 12,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.sort_by_alpha_rounded,
                                                  color: const Color(
                                                    0xFF00FF88,
                                                  ),
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'SORT_NAME',
                                                  style: TextStyle(
                                                    color: const Color(
                                                      0xFF00FF88,
                                                    ),
                                                    fontSize: 12,
                                                    fontFamily:
                                                        'Source Code Pro',
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: 1.2,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: sortByDate,
                                      child: AnimatedBuilder(
                                        animation: _glowAnimation,
                                        builder: (context, child) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                              horizontal: 20,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF1E1E2C),
                                                  Color(0xFF2C2C3E),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              border: Border.all(
                                                color: Color(
                                                  0xFF00D4FF,
                                                ).withOpacity(
                                                  0.3 +
                                                      (0.4 *
                                                          _glowAnimation.value),
                                                ),
                                                width: 1,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFF00D4FF,
                                                  ).withOpacity(
                                                    _glowAnimation.value * 0.2,
                                                  ),
                                                  blurRadius: 12,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.schedule_rounded,
                                                  color: const Color(
                                                    0xFF00D4FF,
                                                  ),
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'SORT_TIME',
                                                  style: TextStyle(
                                                    color: const Color(
                                                      0xFF00D4FF,
                                                    ),
                                                    fontSize: 12,
                                                    fontFamily:
                                                        'Source Code Pro',
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: 1.2,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Content Area
                            Expanded(
                              child:
                                  filtered.isEmpty
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
                                              'NO QUANTUM SIGNATURES FOUND',
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
                                              'Neural database query returned empty matrix',
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
                                          0,
                                          8,
                                          0,
                                          100,
                                        ),
                                        itemCount: filtered.length,
                                        itemBuilder: (context, index) {
                                          final record = filtered[index];
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
                ),
            ],
          ),
        ),
      ),
      // Floating Action Button for quick refresh
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
                fetchAllHistory();
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
