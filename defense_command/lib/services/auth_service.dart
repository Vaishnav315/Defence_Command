import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class AuthService {
  final String _baseUrl = '${ApiService.baseUrl}/auth';

  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$_baseUrl/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': email, // Mapping email to username
          'password': password,
        }),
      );

      if (response.statusCode != 200) {
        String errorMessage = 'Login failed';
        try {
          final errorJson = json.decode(response.body);
          errorMessage = errorJson['msg'] ?? errorMessage;
        } catch (_) {
           errorMessage = 'Server Error (${response.statusCode}). Please check backend logs.';
        }
        throw Exception(errorMessage);
      }

      return json.decode(response.body); 
    } catch (e) {
       if (e.toString().contains('Server Error')) rethrow;
      throw Exception('Failed to connect to server: $e');
    }
  }

  Future<void> signup(String name, String email, String password, {String role = 'soldier'}) async {
    final url = Uri.parse('$_baseUrl/signup');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': email, // Mapping email to username
          'password': password,
          'role': role,
        }),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        String errorMessage = 'Signup failed';
        try {
          final errorJson = json.decode(response.body);
          errorMessage = errorJson['msg'] ?? errorMessage;
        } catch (_) {
          // If response is not JSON (e.g. HTML 500 error), use a generic message
          errorMessage = 'Server Error (${response.statusCode}). Please check backend logs.';
        }
        throw Exception(errorMessage);
      }
      
      // Signup successful (if we got 200/201)
      // Note: If the body was empty or not JSON, we shouldn't try to decode it if we don't need to.
      // But usually we might want to check for 'status': 'success'
    } catch (e) {
      // Rethrow cleanly so UI shows the message
      if (e.toString().contains('Server Error')) rethrow;
      throw Exception('Failed to connect to server: $e');
    }
  }
  static Map<String, dynamic>? currentUser; // Simple global state for demo

  Future<void> signOut() async {
    currentUser = null;
    await Future.delayed(const Duration(milliseconds: 500)); 
  }
}
