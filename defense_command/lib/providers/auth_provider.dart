import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'package:uuid/uuid.dart';

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
  bool get isCommander => _role == 'commander';
  String get identity => _identity ?? 'Unknown';

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('userData')) {
      return;
    }
    final extractedUserData = prefs.getString('userData'); // simple check
    if (extractedUserData != null) {
      _token = 'dummy_stored_token'; // In real app, parse from userData
      _role = prefs.getString('userRole') ?? 'soldier';
      _identity = prefs.getString('userIdentity');
      
      // Fallback if identity was missing in deprecated generic storage
      if (_identity == null) {
         _identity = _generateIdentity(_role!);
         prefs.setString('userIdentity', _identity!);
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
      _token = response['token'];
      
      final prefs = await SharedPreferences.getInstance();
      final userData = DateTime.now().toIso8601String(); // Dummy expiry not implemented yet
      
      _role = response['role'] ?? 'soldier';
      
      // Generate unique identity
      // Make it consistent if possible, or new per login if simpler. 
      // User asked for "Soldier-${Uuid().v4().substring(0,4)}" or manual name.
      // We will stick to the UUID approach attached to the device/login.
      // Ideally we'd use the backend ID, but this fixes the collision.
      _identity = _generateIdentity(_role!);
      
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
      // 1. Perform Signup
      await _authService.signup(name, email, password, role: role);
      
      // 2. Perform Auto-Login to get token
      final response = await _authService.login(email, password);
      _token = response['token'];
      
      final prefs = await SharedPreferences.getInstance();
      final userData = DateTime.now().toIso8601String(); 
      
      _role = response['role'] ?? 'soldier';
      _identity = _generateIdentity(_role!);
      
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
  
  String _generateIdentity(String role) {
    // If Commander, keep it simple? Or unique?
    // "Kick-Off Bug" implies Commanders conflict too if multiple commanders login?
    // User specifically said "In the Soldier App...".
    // But uniqueness is good for everyone.
    if (role == 'commander') {
       // Allow multiple commanders? LiveKit kicks duplicates.
       // So yes, unique ID for commanders too if we want multi-device.
       return 'Commander-${const Uuid().v4().substring(0,4)}';
    }
    return 'Soldier-${const Uuid().v4().substring(0,4)}';
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
