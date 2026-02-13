import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';
import 'main_screen.dart';
import '../utils/snackbar_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  final Color kPrimaryColor = const Color(0xFF00BFA5);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color subTextColor = isDark ? Colors.grey[400]! : Colors.grey;
    final Color inputFill = isDark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFF9FAFB);
    final Color borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final Color hintColor = isDark ? Colors.grey[600]! : Colors.grey[400]!;
    final Color iconColor = isDark ? Colors.grey[500]! : Colors.grey[400]!;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    size: 45,
                    color: kPrimaryColor,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Welcome Back",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Sign in to manage your expenses",
                  style: TextStyle(color: subTextColor, fontSize: 16),
                ),
                const SizedBox(height: 40),

                _buildLabel("Email Address", textColor),
                _buildTextField(
                  emailController,
                  "hello@example.com",
                  Icons.email_outlined,
                  false,
                  null,
                  inputFill,
                  borderColor,
                  hintColor,
                  iconColor,
                ),

                const SizedBox(height: 25),

                _buildLabel("Password", textColor),
                _buildTextField(
                  passController,
                  "Enter password",
                  Icons.lock_outline,
                  _obscurePassword,
                  IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: iconColor,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  inputFill,
                  borderColor,
                  hintColor,
                  iconColor,
                ),

                const SizedBox(height: 30),

                // --- MANUAL LOGIN BUTTON ---
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Sign In",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 30),

                // --- DIVIDER ---
                Row(
                  children: [
                    Expanded(child: Divider(color: borderColor)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "Or continue with",
                        style: TextStyle(color: subTextColor, fontSize: 14),
                      ),
                    ),
                    Expanded(child: Divider(color: borderColor)),
                  ],
                ),

                const SizedBox(height: 30),

                // --- ✅ GOOGLE LOGIN BUTTON ---
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _handleGoogleLogin,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      backgroundColor: isDark
                          ? Colors.transparent
                          : Colors.white,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // If you have an asset, use: Image.asset('assets/google.png', height: 24),
                        // For now, we use a styled letter 'G' or generic icon
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Image(
                            image: NetworkImage(
                              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                            ),
                            height: 24,
                            width: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Sign in with Google",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(color: subTextColor),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
                      child: Text(
                        "Sign Up",
                        style: TextStyle(
                          color: kPrimaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, Color color) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon,
    bool obscure,
    Widget? suffix,
    Color fill,
    Color border,
    Color hintColor,
    Color iconColor,
  ) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: hintColor),
        filled: true,
        fillColor: fill,
        prefixIcon: Icon(icon, color: iconColor),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await Provider.of<AuthProvider>(
        context,
        listen: false,
      ).login(emailController.text.trim(), passController.text);
      if (mounted)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ NEW: Handle Google Login
  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    try {
      await Provider.of<AuthProvider>(context, listen: false).googleLogin();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Google Login Failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
