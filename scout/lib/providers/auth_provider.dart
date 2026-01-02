import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
// import 'package:uuid/uuid.dart'; // No longer needed for Identity generation if using username

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  String? _token;
  String? _role;
  String? _identity; // Unique Identity for LiveKit
  bool _isLoading = false;
  String? _errorMessage;

  bool get isAuthenticated => _token != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get role => _role ?? 'soldier';
  String get identity => _identity ?? 'Unknown';
  String get username => _identity ?? 'Unknown'; // Alias

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('userData')) {
      return;
    }
    // Simple check. Real app would check expiry.
    final extractedUserData = prefs.getString('userData');
    if (extractedUserData != null) {
      _token = 'dummy_stored_token'; 
      _role = prefs.getString('userRole') ?? 'soldier';
      _identity = prefs.getString('userIdentity');
      
      // If identity is missing (legacy), force re-login or handle gracefully
      if (_identity == null) {
         // Should not happen for new flow where identity = username
      }
      
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.login(email, password);
      // Backend returns 'access_token', not 'token'
      _token = response['access_token'];
      
      final prefs = await SharedPreferences.getInstance();
      final userData = DateTime.now().toIso8601String(); 
      
      _role = 'soldier'; // Scout app is for soldiers
      
      // USE USERNAME AS IDENTITY (Scout-ID)
      // We store the raw username entered by user (e.g. "vaishnav")
      // The backend has "scout:vaishnav", but for the app UI and LiveKit, we use the simple name.
      _identity = email; 
      
      prefs.setString('userData', userData);
      prefs.setString('userRole', _role!);
      prefs.setString('userIdentity', _identity!);
      

      notifyListeners();
    } catch (error) {

      _errorMessage = error.toString().replaceAll('Exception: ', '');
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signup(String name, String email, String password, {String role = 'soldier'}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.signup(name, email, password, role: role);
      // Auto Login
      await login(email, password);
    } catch (error) {
      _errorMessage = error.toString().replaceAll('Exception: ', '');
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _token = null;
    _role = null;
    _identity = null;
    final prefs = await SharedPreferences.getInstance();
    prefs.clear();
    notifyListeners();
  }
}
