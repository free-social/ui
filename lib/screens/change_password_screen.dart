import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_radii.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/primary_button.dart';
import '../core/widgets/section_card.dart';
import '../providers/auth_provider.dart';
import '../utils/snackbar_helper.dart';
import '../utils/validation.dart';
import 'login_screen.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Change password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Use a strong password you do not reuse elsewhere.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.verified_user_outlined,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Security update',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Updating your password will sign you in again with the new credentials.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                SectionCard(
                  title: 'Password details',
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        children: [
                          AppTextField(
                            controller: _currentPasswordController,
                            label: 'Current password',
                            hintText: 'Enter current password',
                            prefixIcon: Icons.lock_clock_outlined,
                            obscureText: _obscureCurrent,
                            suffixIcon: IconButton(
                              onPressed: () => setState(() {
                                _obscureCurrent = !_obscureCurrent;
                              }),
                              icon: Icon(
                                _obscureCurrent
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Current password is required'
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppTextField(
                            controller: _newPasswordController,
                            label: 'New password',
                            hintText: 'Create a new password',
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: _obscureNew,
                            suffixIcon: IconButton(
                              onPressed: () => setState(() {
                                _obscureNew = !_obscureNew;
                              }),
                              icon: Icon(
                                _obscureNew
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                            validator: ValidationUtils.validatePassword,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppTextField(
                            controller: _confirmPasswordController,
                            label: 'Confirm new password',
                            hintText: 'Re-enter the new password',
                            prefixIcon: Icons.lock_reset_outlined,
                            obscureText: _obscureConfirm,
                            suffixIcon: IconButton(
                              onPressed: () => setState(() {
                                _obscureConfirm = !_obscureConfirm;
                              }),
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your new password';
                              }
                              if (value != _newPasswordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Update password',
                  isLoading: authProvider.isLoading,
                  onPressed: _handleSubmit,
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: authProvider.isLoading
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;
    if (userId == null) {
      showErrorSnackBar(context, 'User session not found');
      return;
    }

    try {
      final message = await authProvider.updatePassword(
        userId,
        _currentPasswordController.text,
        _newPasswordController.text,
      );

      if (!mounted) return;
      showSuccessSnackBar(context, message);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}
