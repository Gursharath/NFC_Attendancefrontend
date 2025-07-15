import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthService extends ChangeNotifier {
  final storage = const FlutterSecureStorage();
  String? token;

  Future<bool> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('http://10.129.38.100:8000/api/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (res.statusCode == 200) {
      token = jsonDecode(res.body)['token'];
      await storage.write(key: 'token', value: token);
      notifyListeners();
      return true;
    } else {
      return false;
    }
  }

  Future<void> logout() async {
    token = null;
    await storage.delete(key: 'token');
    notifyListeners();
  }

  Future<String?> getToken() async {
    token ??= await storage.read(key: 'token');
    return token;
  }
}
