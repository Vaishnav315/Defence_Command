import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'signup_page.dart';

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
  bool _isLoading = false;
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
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.login(
        _emailController.text,
        _passwordController.text,
      );
    } catch (error) {
      if (!mounted) return;
      _showErrorDialog(error.toString().replaceAll("Exception: ", ""));
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
                "Access Denied",
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
    final primaryColor = const Color(0xFF2193b0); // Vibrant Blue
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // --- CURVED HEADER SECTION ---
                    ClipPath(
                      clipper: HeaderClipper(),
                      child: Container(
                        width: double.infinity,
                        height: 320,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF2193b0), // Vibrant Blue
                              Color(0xFF6dd5ed), // Bright Cyan
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 50),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                               ScaleTransition(
                                 scale: CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.5, curve: Curves.elasticOut)),
                                 child: const Icon(Icons.shield, size: 80, color: Colors.white),
                               ),
                               const SizedBox(height: 16),
                               FadeTransition(
                                 opacity: CurvedAnimation(parent: _animationController, curve: const Interval(0.2, 0.6, curve: Curves.easeIn)),
                                 child: const Text(
                                  "Welcome Back",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    shadows: [Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)],
                                  ),
                                                         ),
                               ),
                               FadeTransition(
                                 opacity: CurvedAnimation(parent: _animationController, curve: const Interval(0.4, 0.8, curve: Curves.easeIn)),
                                 child: const Text(
                                  "Soldier!",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 40,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    shadows: [Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)],
                                  ),
                                                         ),
                               ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // --- FORM SECTION ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),
                            
                            // Username Field (Staggered)
                            SlideTransition(
                               position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.3, 0.7, curve: Curves.easeOutBack))),
                               child: FadeTransition(
                                 opacity: CurvedAnimation(parent: _animationController, curve: const Interval(0.3, 0.7, curve: Curves.easeIn)),
                                 child: TextFormField(
                                   controller: _emailController,
                                   style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                   decoration: InputDecoration(
                                     labelText: "Username",
                                     labelStyle: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                     hintText: "Enter your Username",
                                     hintStyle: const TextStyle(color: Colors.black26),
                                     contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                     border: OutlineInputBorder(
                                       borderRadius: BorderRadius.zero,
                                       borderSide: BorderSide(color: primaryColor),
                                     ),
                                     enabledBorder: OutlineInputBorder(
                                       borderRadius: BorderRadius.zero,
                                       borderSide: const BorderSide(color: Colors.black12),
                                     ),
                                     focusedBorder: OutlineInputBorder(
                                       borderRadius: BorderRadius.zero,
                                       borderSide: BorderSide(color: primaryColor, width: 2),
                                     ),
                                     prefixIcon: Icon(Icons.person_outline, color: primaryColor),
                                   ),
                                   validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
                                 ),
                               ),
                             ),
                             const SizedBox(height: 24),
                             
                             // Password Field (Staggered)
                             SlideTransition(
                               position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.4, 0.8, curve: Curves.easeOutBack))),
                               child: FadeTransition(
                                 opacity: CurvedAnimation(parent: _animationController, curve: const Interval(0.4, 0.8, curve: Curves.easeIn)),
                                 child: TextFormField(
                                   controller: _passwordController,
                                   obscureText: !_isPasswordVisible,
                                   style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                   decoration: InputDecoration(
                                     labelText: "Password",
                                     labelStyle: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                     hintText: "••••••••",
                                     hintStyle: const TextStyle(color: Colors.black26),
                                     contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                     border: OutlineInputBorder(
                                       borderRadius: BorderRadius.zero,
                                       borderSide: BorderSide(color: primaryColor),
                                     ),
                                     enabledBorder: OutlineInputBorder(
                                       borderRadius: BorderRadius.zero,
                                       borderSide: const BorderSide(color: Colors.black12),
                                     ),
                                     focusedBorder: OutlineInputBorder(
                                       borderRadius: BorderRadius.zero,
                                       borderSide: BorderSide(color: primaryColor, width: 2),
                                     ),
                                     prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
                                      suffixIcon: IconButton(
                                       icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: primaryColor),
                                       onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                     ),
                                   ),
                                   validator: (val) => (val == null || val.length < 6) ? 'At least 6 characters' : null,
                                 ),
                               ),
                             ),

                            const SizedBox(height: 48),

                            // Login Button (Staggered)
                            SlideTransition(
                              position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.5, 0.9, curve: Curves.easeOutBack))),
                              child: FadeTransition(
                                opacity: CurvedAnimation(parent: _animationController, curve: const Interval(0.5, 0.9, curve: Curves.easeIn)),
                                child: Container(
                                  width: 200,
                                  height: 50,
                                   decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                       BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
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
                                        "LOGIN",
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
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 30), 
                    
                    // Register Link
                    SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 1.0), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.6, 1.0, curve: Curves.easeOut))),
                      child: FadeTransition(
                        opacity: CurvedAnimation(parent: _animationController, curve: const Interval(0.6, 1.0, curve: Curves.easeIn)),
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpPage()));
                          },
                          child: Text(
                            "New Recruit? Join Force",
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }
}

class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 50);
    final firstControlPoint = Offset(size.width / 4, size.height);
    final firstEndPoint = Offset(size.width / 2.25, size.height - 30);
    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy, firstEndPoint.dx, firstEndPoint.dy);
    final secondControlPoint = Offset(size.width - (size.width / 3.25), size.height - 65);
    final secondEndPoint = Offset(size.width, size.height - 40);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy, secondEndPoint.dx, secondEndPoint.dy);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
