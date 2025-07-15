import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<dynamic> history = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchAllHistory();
  }

  Future<void> fetchAllHistory() async {
    final token =
        await Provider.of<AuthService>(context, listen: false).getToken();
    final response = await http.get(
      Uri.parse('http://10.129.38.100:8000/api/attendance/today'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      setState(() {
        history = jsonDecode(response.body);
        loading = false;
      });
    } else {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Failed to load attendance records')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: Text(
          'All Attendance Records',
          style: GoogleFonts.orbitron(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E1E2C),
        foregroundColor: const Color(0xFF00BFA6),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child:
            loading
                ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00BFA6)),
                )
                : history.isEmpty
                ? const Center(
                  child: Text(
                    'No attendance records found.',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
                : ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final record = history[index];
                    final student = record['student'];

                    final name =
                        student != null
                            ? student['name'] ?? 'Unknown'
                            : 'Unknown';
                    final course =
                        student != null ? student['course'] ?? '' : '';
                    final date = record['date'] ?? '--';
                    final time = record['time_marked'] ?? '--:--';

                    return Card(
                      color: const Color(0xFF2C2C3E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: const Icon(
                          Icons.person,
                          color: Color(0xFF00BFA6),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'Course: $course\nDate: $date • Time: $time',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  },
                ),
      ),
    );
  }
}
