import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import 'signup_page.dart';
import '../main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800)
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.login(
        _emailController.text,
        _passwordController.text,
      );
      
      // Store user info globally
      AuthService.currentUser = {
        'username': _emailController.text,
        'email': _emailController.text,
        'name': _emailController.text.split('@')[0], 
      };
      
      if (!mounted) return;
      // Navigate to AuthWrapper to restore the main app structure
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
        (route) => false,
      );

    } catch (error) {
    if (!mounted) return;
    
    // Custom "Clean" Error Toast
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Unable to sign in. Please check your credentials.",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF333333), // Dark elegant grey
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        duration: const Duration(seconds: 3),
        elevation: 4,
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isDark = theme.brightness == Brightness.dark;

    // NovaPass High Contrast Colors
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final buttonColor = isDark ? Colors.white : Colors.black;
    final buttonTextColor = isDark ? Colors.black : Colors.white;
    final inputBorderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // No leading/back button on Login Page
      ),
      body: SafeArea(
        child: Align(
          alignment: const Alignment(0.0, -0.2), // Slightly up from center
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // Wrap content
                children: [
                const SizedBox(height: 16),
                
                // Icon (Moved to Top)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: buttonColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.flight_takeoff, // "Crossed"/Angled flight icon
                    color: buttonTextColor,
                    size: 28,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Title
                // Title (Staggered)
                FadeTransition(
                  opacity: CurvedAnimation(parent: _animationController, curve: const Interval(0.2, 0.6, curve: Curves.easeIn)),
                  child: Text(
                    'Login',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      fontSize: 32,
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                FadeTransition(
                  opacity: CurvedAnimation(parent: _animationController, curve: const Interval(0.3, 0.7, curve: Curves.easeIn)),
                  child: Text(
                    'Please login to your account',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Email (Staggered Slide)
                      SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.3, 0.7, curve: Curves.easeOutBack))),
                        child: FadeTransition(
                          opacity: CurvedAnimation(parent: _animationController, curve: const Interval(0.3, 0.7, curve: Curves.easeIn)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 4, bottom: 8),
                                child: Text("Email Address", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              ),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: TextStyle(color: textColor),
                                decoration: InputDecoration(
                                  hintText: 'user@example.com',
                                  hintStyle: TextStyle(color: Colors.grey[400]),
                                  prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(50),
                                    borderSide: BorderSide(color: inputBorderColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(50),
                                    borderSide: BorderSide(color: inputBorderColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(50),
                                    borderSide: BorderSide(color: textColor, width: 1.5),
                                  ),
                                ),
                                validator: (val) => (val == null || !val.contains('@')) ? 'Invalid Email' : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),

                      // Password (Staggered Slide)
                       SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.4, 0.8, curve: Curves.easeOutBack))),
                        child: FadeTransition(
                          opacity: CurvedAnimation(parent: _animationController, curve: const Interval(0.4, 0.8, curve: Curves.easeIn)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 4, bottom: 8),
                                child: Text("Password", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              ),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: !_isPasswordVisible,
                                style: TextStyle(color: textColor),
                                decoration: InputDecoration(
                                  hintText: '••••••••',
                                  hintStyle: TextStyle(color: Colors.grey[400]),
                                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                                  suffixIcon: IconButton(
                                    icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(50),
                                    borderSide: BorderSide(color: inputBorderColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(50),
                                    borderSide: BorderSide(color: inputBorderColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(50),
                                    borderSide: BorderSide(color: textColor, width: 1.5),
                                  ),
                                ),
                                validator: (val) => (val == null || val.length < 6) ? 'Min 6 characters' : null,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Forgot Password Link (Visual Only)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          child: const Text(
                            "Forgot password?",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Large Login Button (Staggered)
                      SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.5, 0.9, curve: Curves.easeOutBack))),
                          child: FadeTransition(
                            opacity: CurvedAnimation(parent: _animationController, curve: const Interval(0.5, 0.9, curve: Curves.easeIn)),
                            child: SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: authProvider.isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: buttonColor,
                                  foregroundColor: buttonTextColor,
                                  elevation: 0,
                                  shape: const StadiumBorder(), // Fully rounded
                                ),
                                child: authProvider.isLoading
                                  ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: buttonTextColor, strokeWidth: 2))
                                  : const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 32),
                      
                      // Footer Link (No Socials) - Staggered
                      SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0, 1.0), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.6, 1.0, curve: Curves.easeOut))),
                          child: FadeTransition(
                            opacity: CurvedAnimation(parent: _animationController, curve: const Interval(0.6, 1.0, curve: Curves.easeIn)),
                            child: Center(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (context) => const SignUpPage()),
                                  );
                                },
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(color: Colors.grey[600]),
                                    children: [
                                      const TextSpan(text: "Don't have account? "),
                                      TextSpan(
                                        text: "Sign up",
                                        style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }
}
