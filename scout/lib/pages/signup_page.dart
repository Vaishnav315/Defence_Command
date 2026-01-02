import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController(); 
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500)
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_passwordController.text != _confirmPasswordController.text) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match"), backgroundColor: Colors.red),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signup(
        _nameController.text.trim(),
        _emailController.text.trim(), 
        _passwordController.text,
      );
      
      if (!mounted) return;
      Navigator.of(context).pop(); 
      ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text("Registration Successful! Please Login."), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              const Text(
                "Registration Failed",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 16),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("TRY AGAIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF2193b0);

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        child: Column(
          children: [
              ClipPath(
                clipper: SignupHeaderClipper(),
                child: Container(
                  width: double.infinity,
                  height: 250,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF2193b0),
                        Color(0xFF6dd5ed),
                      ],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                         const SizedBox(height: 40),
                         Align(
                           alignment: Alignment.topLeft,
                           child: Padding(
                             padding: const EdgeInsets.only(left: 16),
                             child: IconButton(
                               icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 28),
                               onPressed: () => Navigator.pop(context),
                             ),
                           ),
                         ),
                         const Text(
                          "Create Account",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)],
                          ),
                        ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      
                      // Name (Staggered)
                      SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0.5, 0.0), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.2, 0.6, curve: Curves.easeOutCubic))),
                        child: FadeTransition(
                          opacity: CurvedAnimation(parent: _animationController, curve: const Interval(0.2, 0.6, curve: Curves.easeIn)),
                          child: _buildField("Name", "Enter Full Name", _nameController, primaryColor),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Username (Staggered)
                      SlideTransition(
                         position: Tween<Offset>(begin: const Offset(0.5, 0.0), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic))),
                        child: FadeTransition(
                          opacity: CurvedAnimation(parent: _animationController, curve: const Interval(0.3, 0.7, curve: Curves.easeIn)),
                          child: _buildField("Username", "Enter Username", _emailController, primaryColor),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Password (Staggered)
                      SlideTransition(
                         position: Tween<Offset>(begin: const Offset(0.5, 0.0), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.4, 0.8, curve: Curves.easeOutCubic))),
                        child: FadeTransition(
                          opacity: CurvedAnimation(parent: _animationController, curve: const Interval(0.4, 0.8, curve: Curves.easeIn)),
                          child: _buildField("Password", "****************", _passwordController, primaryColor, isPassword: true),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Confirm Password (Staggered)
                      SlideTransition(
                         position: Tween<Offset>(begin: const Offset(0.5, 0.0), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.5, 0.9, curve: Curves.easeOutCubic))),
                        child: FadeTransition(
                          opacity: CurvedAnimation(parent: _animationController, curve: const Interval(0.5, 0.9, curve: Curves.easeIn)),
                          child: _buildField("Confirm Password", "****************", _confirmPasswordController, primaryColor, isPassword: true, showVisibility: false),
                        ),
                      ),

                      const SizedBox(height: 32),
                      
                      // Sign Up Button (Staggered)
                      SlideTransition(
                         position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic))),
                        child: FadeTransition(
                          opacity: CurvedAnimation(parent: _animationController, curve: const Interval(0.6, 1.0, curve: Curves.easeIn)),
                          child: Container(
                            width: 200,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                 BoxShadow(color: primaryColor.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading 
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                  "SIGN UP",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ),
     );
  }
  
  Widget _buildField(String label, String hint, TextEditingController controller, Color color, {bool isPassword = false, bool showVisibility = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        ),
        TextFormField(
          controller: controller,
          obscureText: isPassword && (showVisibility ? !_isPasswordVisible : true),
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: color, width: 2)),
            prefixIcon: Icon(isPassword ? Icons.lock_outline : (label == "Name" ? Icons.person_outline : Icons.email_outlined), color: color),
            suffixIcon: (isPassword && showVisibility) ? IconButton(
              icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: color),
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            ) : null,
          ),
          validator: (val) {
            if (val == null || val.isEmpty) return 'Required';
            if (isPassword && val.length < 6) return 'At least 6 characters';
            return null;
          },
        ),
      ],
    );
  }
}

class SignupHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    var firstControlPoint = Offset(size.width / 4, size.height);
    var firstEndPoint = Offset(size.width / 2, size.height - 30);
    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy, firstEndPoint.dx, firstEndPoint.dy);
    var secondControlPoint = Offset(size.width - (size.width / 4), size.height - 80);
    var secondEndPoint = Offset(size.width, size.height - 20);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy, secondEndPoint.dx, secondEndPoint.dy);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
