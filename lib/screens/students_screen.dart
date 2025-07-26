import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:lottie/lottie.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../services/auth_service.dart';
import 'student_attendance_screen.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _allStudents = [];
  List<dynamic> _filteredStudents = [];
  bool _isLoading = false;
  String _sortBy = 'Name';

  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late AnimationController _cardController;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _cardAnimation;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _cardController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _cardAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.elasticOut),
    );

    _searchController.addListener(_onSearchChanged);
    _slideController.forward();
    _pulseController.repeat(reverse: true);
    _glowController.repeat(reverse: true);
    _loadStudents();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    _cardController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _filteredStudents = _filterStudents(_searchController.text);
    });
    _cardController.reset();
    _cardController.forward();
  }

  List<dynamic> _filterStudents(String query) {
    List<dynamic> filtered = _allStudents;
    if (query.isNotEmpty) {
      final searchQuery = query.toLowerCase().trim();
      filtered =
          _allStudents.where((student) {
            final name = (student['name'] ?? '').toString().toLowerCase();
            final course = (student['course'] ?? '').toString().toLowerCase();
            final email = (student['email'] ?? '').toString().toLowerCase();
            final nfcId = (student['nfc_id'] ?? '').toString().toLowerCase();
            return name.contains(searchQuery) ||
                course.contains(searchQuery) ||
                email.contains(searchQuery) ||
                nfcId.contains(searchQuery);
          }).toList();
    }

    // Sort the filtered list
    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'Course':
          return (a['course'] ?? '').compareTo(b['course'] ?? '');
        case 'NFC ID':
          return (a['nfc_id'] ?? '').compareTo(b['nfc_id'] ?? '');
        default:
          return (a['name'] ?? '').compareTo(b['name'] ?? '');
      }
    });

    return filtered;
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final token =
          await Provider.of<AuthService>(context, listen: false).getToken();
      final response = await http.get(
        Uri.parse('http://10.148.36.100:8000/api/students'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final students = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _allStudents = students;
          _filteredStudents = _filterStudents(_searchController.text);
        });
        _cardController.forward();
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _shareCSV() async {
    _showTechSnackBar(
      '📊 Generating neural data export...',
      const Color(0xFF00D4FF),
    );

    List<List<dynamic>> rows = [
      ['ID', 'Name', 'Email', 'Course', 'NFC ID'],
      ..._filteredStudents.map(
        (s) => [s['id'], s['name'], s['email'], s['course'], s['nfc_id']],
      ),
    ];

    String csvData = const ListToCsvConverter().convert(rows);
    await Share.share(csvData, subject: 'Neural Entity Database Export');

    _showTechSnackBar(
      '✅ Data matrix exported successfully',
      const Color(0xFF00FF88),
    );
  }

  Future<void> _printStudents() async {
    _showTechSnackBar(
      '🖨️ Initializing quantum printer...',
      const Color(0xFF00D4FF),
    );

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build:
            (context) => [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '🤖 NEURAL ENTITY DATABASE',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.cyan800,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Active Entities: ${_filteredStudents.length}',
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                  pw.SizedBox(height: 16),
                ],
              ),
              pw.Table.fromTextArray(
                headers: [
                  'ENTITY_ID',
                  'IDENTITY',
                  'COMM_LINK',
                  'PROGRAM',
                  'QUANTUM_SIG',
                ],
                data:
                    _filteredStudents.map((student) {
                      return [
                        student['id']?.toString() ?? '',
                        student['name'] ?? '',
                        student['email'] ?? '',
                        student['course'] ?? '',
                        student['nfc_id'] ?? '',
                      ];
                    }).toList(),
                border: pw.TableBorder.all(color: PdfColors.cyan400),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.cyan700,
                ),
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(3),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FlexColumnWidth(2),
                },
                rowDecoration: pw.BoxDecoration(color: PdfColors.cyan50),
                cellPadding: const pw.EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 6,
                ),
              ),
            ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
    _showTechSnackBar(
      '✅ Neural database printed successfully',
      const Color(0xFF00FF88),
    );
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

  Widget _buildTechButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    String? tooltip,
  }) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: IconButton(
              onPressed: onPressed,
              tooltip: tooltip,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00D4FF).withOpacity(0.1),
            const Color(0xFF00FF88).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.3)),
      ),
      child: DropdownButton<String>(
        value: _sortBy,
        dropdownColor: const Color(0xFF1A1A2E),
        underline: const SizedBox.shrink(),
        items:
            ['Name', 'Course', 'NFC ID'].map((value) {
              return DropdownMenuItem(
                value: value,
                child: Text(
                  'SORT BY $value',
                  style: GoogleFonts.orbitron(
                    color: const Color(0xFF00D4FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
        onChanged: (val) {
          if (val != null) {
            setState(() {
              _sortBy = val;
              _filteredStudents = _filterStudents(_searchController.text);
            });
            _cardController.reset();
            _cardController.forward();
          }
        },
      ),
    );
  }

  bool _isRecentlyAdded(String? createdAt) {
    if (createdAt == null) return false;
    final studentDate = DateTime.tryParse(createdAt);
    if (studentDate == null) return false;
    return DateTime.now().difference(studentDate).inDays <= 7;
  }

  Widget _buildStudentCard(Map<String, dynamic> student, int index) {
    final isRecent = _isRecentlyAdded(student['created_at']);

    return SlideTransition(
      position: Tween<Offset>(begin: Offset(1, 0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _cardController,
          curve: Interval(
            (index * 0.1).clamp(0.0, 1.0),
            1.0,
            curve: Curves.easeOutCubic,
          ),
        ),
      ),
      child: FadeTransition(
        opacity: _cardAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1A1A2E).withOpacity(0.9),
                const Color(0xFF16213E).withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isRecent
                      ? const Color(0xFF00FF88).withOpacity(0.5)
                      : const Color(0xFF00D4FF).withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    isRecent
                        ? const Color(0xFF00FF88).withOpacity(0.1)
                        : const Color(0xFF00D4FF).withOpacity(0.1),
                blurRadius: 15,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => StudentAttendanceScreen(
                          studentId: student['id'],
                          studentName: student['name'] ?? 'Unknown Entity',
                        ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF00D4FF).withOpacity(0.2),
                            const Color(0xFF00FF88).withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF00D4FF).withOpacity(0.5),
                        ),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Color(0xFF00D4FF),
                        size: 24,
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Student Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  student['name'] ?? 'Unknown Entity',
                                  style: GoogleFonts.orbitron(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isRecent)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF00FF88,
                                    ).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF00FF88,
                                      ).withOpacity(0.5),
                                    ),
                                  ),
                                  child: Text(
                                    'NEW',
                                    style: GoogleFonts.sourceCodePro(
                                      fontSize: 10,
                                      color: const Color(0xFF00FF88),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '🏫 ${student['course'] ?? 'Unknown Program'}',
                            style: GoogleFonts.sourceCodePro(
                              color: const Color(0xFF00D4FF),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '📧 ${student['email'] ?? 'No comm link'}',
                            style: GoogleFonts.sourceCodePro(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // NFC ID
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B6B).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFFF6B6B).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            student['nfc_id'] ?? 'NO_SIG',
                            style: GoogleFonts.sourceCodePro(
                              color: const Color(0xFFFF6B6B),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'QUANTUM_ID',
                          style: GoogleFonts.sourceCodePro(
                            color: Colors.white38,
                            fontSize: 8,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00D4FF).withOpacity(0.1),
                  const Color(0xFF00FF88).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF00D4FF).withOpacity(0.3),
              ),
            ),
            child: const Icon(
              Icons.search_off,
              size: 64,
              color: Color(0xFF00D4FF),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'NO ENTITIES DETECTED',
            style: GoogleFonts.orbitron(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF00D4FF),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Neural database scan complete\nNo matching entities found',
            textAlign: TextAlign.center,
            style: GoogleFonts.sourceCodePro(
              fontSize: 14,
              color: Colors.white54,
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
          'NEURAL ENTITIES',
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
          _buildTechButton(
            icon: Icons.file_download,
            onPressed: _shareCSV,
            color: const Color(0xFF00FF88),
            tooltip: 'Export Matrix',
          ),
          _buildTechButton(
            icon: Icons.print,
            onPressed: _printStudents,
            color: const Color(0xFF00D4FF),
            tooltip: 'Print Database',
          ),
          _buildTechButton(
            icon: Icons.refresh,
            onPressed: _loadStudents,
            color: const Color(0xFFFF6B6B),
            tooltip: 'Refresh Scan',
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
          child: Column(
            children: [
              // Search and controls
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.5),
                  end: Offset.zero,
                ).animate(_slideAnimation),
                child: Container(
                  margin: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Search bar
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF00D4FF).withOpacity(0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00D4FF).withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: GoogleFonts.sourceCodePro(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'SCAN FOR ENTITIES...',
                            hintStyle: GoogleFonts.sourceCodePro(
                              color: Colors.white38,
                              fontWeight: FontWeight.w400,
                            ),
                            prefixIcon: Container(
                              margin: const EdgeInsets.all(12),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00D4FF).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.search,
                                color: Color(0xFF00D4FF),
                                size: 20,
                              ),
                            ),
                            suffixIcon:
                                _searchController.text.isNotEmpty
                                    ? IconButton(
                                      icon: const Icon(
                                        Icons.clear,
                                        color: Colors.white54,
                                      ),
                                      onPressed:
                                          () => _searchController.clear(),
                                    )
                                    : null,
                            filled: true,
                            fillColor: const Color(0xFF1A1A2E).withOpacity(0.8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Stats and sort
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF00FF88).withOpacity(0.1),
                                  const Color(0xFF00D4FF).withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF00FF88).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              'ENTITIES: ${_filteredStudents.length}',
                              style: GoogleFonts.orbitron(
                                color: const Color(0xFF00FF88),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          _buildSortDropdown(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Student list
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadStudents,
                  color: const Color(0xFF00D4FF),
                  backgroundColor: const Color(0xFF1A1A2E),
                  child:
                      _isLoading
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(
                                  color: Color(0xFF00D4FF),
                                  strokeWidth: 3,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'SCANNING NEURAL DATABASE...',
                                  style: GoogleFonts.orbitron(
                                    color: const Color(0xFF00D4FF),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                          : _filteredStudents.isEmpty
                          ? _buildEmptyState()
                          : AnimatedBuilder(
                            animation: _glowAnimation,
                            builder: (context, child) {
                              return ListView.builder(
                                padding: const EdgeInsets.only(bottom: 20),
                                itemCount: _filteredStudents.length,
                                itemBuilder: (context, index) {
                                  final student = _filteredStudents[index];
                                  return _buildStudentCard(student, index);
                                },
                              );
                            },
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
