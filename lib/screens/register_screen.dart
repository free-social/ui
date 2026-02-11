import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/validation.dart';
import '../utils/snackbar_helper.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController userController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  final Color kPrimaryColor = const Color(0xFF00BFA5);

  @override
  void dispose() {
    userController.dispose();
    emailController.dispose();
    passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ SETUP DYNAMIC COLORS (Strictly typed as 'Color')
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color subTextColor = isDark ? Colors.grey[400]! : Colors.grey;
    final Color inputFillColor = isDark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFF9FAFB);
    final Color borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final Color hintColor = isDark ? Colors.grey[600]! : Colors.grey[400]!;
    final Color iconColor = isDark ? Colors.grey[500]! : Colors.grey[400]!;

    return Scaffold(
      // Background handled by Theme
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // 1. TOP LOGO
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

                const SizedBox(height: 30),

                // 2. HEADER TEXT
                Text(
                  "Create Account",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: textColor, // ✅ Dynamic
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Join us to start tracking your expenses",
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 16,
                  ), // ✅ Dynamic
                ),

                const SizedBox(height: 40),

                // 3. FULL NAME FIELD
                _buildLabel("Full Name", textColor),
                _buildTextField(
                  controller: userController,
                  hint: "John Doe",
                  icon: Icons.person_outline,
                  validator: ValidationUtils.validateUsername,
                  fillColor: inputFillColor,
                  borderColor: borderColor,
                  hintColor: hintColor, // ✅ Clean usage (no !)
                  iconColor: iconColor, // ✅ Clean usage (no !)
                ),

                const SizedBox(height: 20),

                // 4. EMAIL FIELD
                _buildLabel("Email Address", textColor),
                _buildTextField(
                  controller: emailController,
                  hint: "hello@example.com",
                  icon: Icons.email_outlined,
                  validator: ValidationUtils.validateEmail,
                  keyboardType: TextInputType.emailAddress,
                  fillColor: inputFillColor,
                  borderColor: borderColor,
                  hintColor: hintColor,
                  iconColor: iconColor,
                ),

                const SizedBox(height: 20),

                // 5. PASSWORD FIELD
                _buildLabel("Password", textColor),
                _buildTextField(
                  controller: passController,
                  hint: "Create a password",
                  icon: Icons.lock_outline,
                  obscure: _obscurePassword,
                  fillColor: inputFillColor,
                  borderColor: borderColor,
                  hintColor: hintColor,
                  iconColor: iconColor,
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: iconColor, // ✅ Dynamic
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: ValidationUtils.validatePassword,
                ),

                const SizedBox(height: 30),

                // 6. SIGN UP BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: kPrimaryColor.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            "Sign Up",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 30),

                // 9. SIGN IN LINK
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account?",
                      style: TextStyle(
                        color: subTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ), // ✅ Dynamic
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Sign In",
                        style: TextStyle(
                          color: kPrimaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- UI Helpers ---

  Widget _buildLabel(String text, Color color) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: color,
          ),
        ), // ✅ Dynamic
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color fillColor,
    required Color borderColor,
    required Color hintColor,
    required Color iconColor,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      keyboardType: keyboardType,
      style: TextStyle(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black,
      ), // ✅ Dynamic Input Text
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: hintColor), // ✅ Dynamic
        filled: true,
        fillColor: fillColor, // ✅ Dynamic
        prefixIcon: Icon(icon, color: iconColor, size: 22), // ✅ Dynamic
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor), // ✅ Dynamic
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: kPrimaryColor.withOpacity(0.5),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  // --- Logic ---

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await Provider.of<AuthProvider>(context, listen: false).register(
        userController.text.trim(),
        emailController.text.trim(),
        passController.text,
      );

      if (mounted) {
        Navigator.pop(context);
        showSuccessSnackBar(context, 'Success! Please Login.');
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString().replaceFirst('Exception: ', '');
        showErrorSnackBar(context, errorMessage);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
