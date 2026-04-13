import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_spacing.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/auth_screen_shell.dart';
import '../core/widgets/primary_button.dart';
import '../providers/auth_provider.dart';
import '../utils/snackbar_helper.dart';
import '../utils/validation.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _userController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AuthScreenShell(
      eyebrow: 'Create account',
      title: 'Financial workspace.',
      footer: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Already have an account?', style: theme.textTheme.bodyMedium),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Sign in'),
          ),
        ],
      ),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: _userController,
                label: 'Full name',
                hintText: 'John Doe',
                prefixIcon: Icons.person_outline_rounded,
                validator: ValidationUtils.validateUsername,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _emailController,
                label: 'Email',
                hintText: 'hello@example.com',
                prefixIcon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: ValidationUtils.validateEmail,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _passwordController,
                label: 'Password',
                hintText: 'Create a password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  onPressed: () => setState(() {
                    _obscurePassword = !_obscurePassword;
                  }),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
                validator: ValidationUtils.validatePassword,
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'Create account',
                isLoading: _isLoading,
                onPressed: _handleRegister,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await context.read<AuthProvider>().register(
            _userController.text.trim(),
            _emailController.text.trim(),
            _passwordController.text,
          );

      if (mounted) {
        Navigator.pop(context);
        showSuccessSnackBar(
          context,
          'Account created. Sign in to continue.',
        );
      }
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
