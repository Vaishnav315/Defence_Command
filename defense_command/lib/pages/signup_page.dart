import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../main.dart';

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
  String _selectedRole = 'soldier';
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500)
    );
     // Slide from Right Animation for Fields
    _slideAnimation = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
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
    FocusScope.of(context).unfocus();

    try {
      await Provider.of<AuthProvider>(context, listen: false).signup(
        _nameController.text,
        _emailController.text,
        _passwordController.text,
        role: _selectedRole,
      );
      
      // Store user info globally (mirroring Login Page logic)
      AuthService.currentUser = {
        'username': _emailController.text,
        'email': _emailController.text,
        'name': _nameController.text,
        'role': _selectedRole,
      };

      if (!mounted) return;
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
                "Could not create account. Please try again later.",
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

     // NovaPass Colors (High Contrast)
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor), // Chevron style
          onPressed: () => Navigator.of(context).pop(),
        ),
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
                
                const SizedBox(height: 16),
                
                // Icon (Top)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: buttonColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.flight_takeoff, // Matching Login Page
                    color: buttonTextColor,
                    size: 28,
                  ),
                ),
                
                const SizedBox(height: 24),

                // Title (Slide from Right)
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _animationController,
                    child: Text(
                      'Sign up',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        fontSize: 32,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                FadeTransition(
                  opacity: _animationController,
                  child: Text(
                    "Let's keep it quick, just 2 steps",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       // Name (Slide from Right)
                      SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0.5, 0), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.2, 0.6, curve: Curves.easeOutCubic))),
                        child: FadeTransition(
                          opacity: CurvedAnimation(parent: _animationController, curve: const Interval(0.2, 0.6, curve: Curves.easeIn)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 4, bottom: 8),
                                child: Text("Full Name", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              ),
                              TextFormField(
                                controller: _nameController,
                                style: TextStyle(color: textColor),
                                decoration: InputDecoration(
                                  hintText: 'John Doe',
                                   hintStyle: TextStyle(color: Colors.grey[400]),
                                  prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                  border: UnderlineInputBorder(
                                    borderSide: BorderSide(color: inputBorderColor),
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: inputBorderColor),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: textColor, width: 1.5),
                                  ),
                                ),
                                validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),

                      // Email (Slide from Right)
                      SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0.5, 0), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic))),
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
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                   border: UnderlineInputBorder(
                                    borderSide: BorderSide(color: inputBorderColor),
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: inputBorderColor),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: textColor, width: 1.5),
                                  ),
                                ),
                                validator: (val) => (val == null || !val.contains('@')) ? 'Invalid Email' : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),

                      // Password (Slide from Right)
                      SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0.5, 0), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.4, 0.8, curve: Curves.easeOutCubic))),
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
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                   border: UnderlineInputBorder(
                                    borderSide: BorderSide(color: inputBorderColor),
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: inputBorderColor),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: textColor, width: 1.5),
                                  ),
                                ),
                                validator: (val) => (val == null || val.length < 6) ? 'Min 6 characters' : null,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      // Confirm Password (Slide from Right)
                      SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0.5, 0), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.5, 0.9, curve: Curves.easeOutCubic))),
                        child: FadeTransition(
                          opacity: CurvedAnimation(parent: _animationController, curve: const Interval(0.5, 0.9, curve: Curves.easeIn)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 4, bottom: 8),
                                child: Text("Confirm Password", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              ),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: !_isPasswordVisible,
                                style: TextStyle(color: textColor),
                                 decoration: InputDecoration(
                                  hintText: '••••••••',
                                   hintStyle: TextStyle(color: Colors.grey[400]),
                                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                   border: UnderlineInputBorder(
                                    borderSide: BorderSide(color: inputBorderColor),
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: inputBorderColor),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: textColor, width: 1.5),
                                  ),
                                ),
                                validator: (val) => (val != _passwordController.text) ? 'Mismatch' : null,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      
                      // Role Selection (Slide from Right)
                      SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0.5, 0), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic))),
                        child: FadeTransition(
                          opacity: CurvedAnimation(parent: _animationController, curve: const Interval(0.6, 1.0, curve: Curves.easeIn)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                               Padding(
                                padding: const EdgeInsets.only(left: 4, bottom: 8),
                                child: Text("Role", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(color: inputBorderColor)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedRole,
                                    isExpanded: true,
                                    dropdownColor: bgColor,
                                    icon: Icon(Icons.keyboard_arrow_down, color: textColor),
                                    style: TextStyle(color: textColor, fontSize: 16),
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        _selectedRole = newValue!;
                                      });
                                    },
                                    items: <String>['soldier', 'commander']
                                        .map<DropdownMenuItem<String>>((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: 12),
                                          child: Text(
                                            value.toUpperCase(),
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Large Login Button (Slide from Right)
                      SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0.5, 0), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.7, 1.0, curve: Curves.easeOutCubic))),
                        child: FadeTransition(
                          opacity: CurvedAnimation(parent: _animationController, curve: const Interval(0.7, 1.0, curve: Curves.easeIn)),
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
                                : const Text('Sign Up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ),
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
