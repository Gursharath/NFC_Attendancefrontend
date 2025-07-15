import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
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

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  List<dynamic> history = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchAttendanceHistory();
  }

  Future<void> fetchAttendanceHistory() async {
    final token =
        await Provider.of<AuthService>(context, listen: false).getToken();
    final response = await http.get(
      Uri.parse(
        'http://10.129.38.100:8000/api/attendance/${widget.studentId}/history',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        history = jsonDecode(response.body);
        loading = false;
      });
    } else {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Failed to load attendance')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: const Text('Student Attendance'),
        backgroundColor: const Color(0xFF1E1E2C),
        foregroundColor: const Color(0xFF00BFA6),
      ),
      body:
          loading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00BFA6)),
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: const Color(0xFF2C2C3E),
                    child: Text(
                      '👤 ${widget.studentName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  history.isEmpty
                      ? const Expanded(
                        child: Center(
                          child: Text(
                            'No attendance records.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      )
                      : Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: history.length,
                          itemBuilder: (context, index) {
                            final record = history[index];
                            return Card(
                              color: const Color(0xFF2C2C3E),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.event_available,
                                  color: Color(0xFF00BFA6),
                                ),
                                title: Text(
                                  'Date: ${record['date']}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'Time: ${record['time_marked']}',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                ],
              ),
    );
  }
}
