import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  // Hardcoded for now, or could use config. 
  // Should ideally match main.dart's _serverUrl or be injected.
  static const String _baseUrl = "https://flabbergastedly-censerless-tanna.ngrok-free.dev/auth";

  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$_baseUrl/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': email, 
          'password': password,
        }),
      );

      if (response.statusCode != 200) {
        String errorMessage = 'Login failed';
        try {
          final errorJson = json.decode(response.body);
          // FastAPI returns 'detail' for HTTPExceptions
          errorMessage = errorJson['detail'] ?? errorJson['msg'] ?? errorMessage;
        } catch (_) {
           errorMessage = 'Server Error (${response.statusCode}).';
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
          'username': email, 
          'password': password,
          'role': role,
        }),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        String errorMessage = 'Signup failed';
        try {
          final errorJson = json.decode(response.body);
          // FastAPI returns 'detail' for HTTPExceptions
          errorMessage = errorJson['detail'] ?? errorJson['msg'] ?? errorMessage;
        } catch (_) {
          errorMessage = 'Server Error (${response.statusCode}).';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e.toString().contains('Server Error')) rethrow;
      throw Exception('Failed to connect to server: $e');
    }
  }
  static Map<String, dynamic>? currentUser; 

  Future<void> signOut() async {
    currentUser = null;
    await Future.delayed(const Duration(milliseconds: 500)); 
  }
}
