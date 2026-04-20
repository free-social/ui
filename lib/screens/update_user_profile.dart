import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radii.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/primary_button.dart';
import '../core/widgets/section_card.dart';
import '../providers/auth_provider.dart';
import '../utils/snackbar_helper.dart';

class UpdateUserProfile extends StatefulWidget {
  const UpdateUserProfile({super.key});

  @override
  State<UpdateUserProfile> createState() => _UpdateUserProfileState();
}

class _UpdateUserProfileState extends State<UpdateUserProfile> {
  late final TextEditingController _nameController;
  File? _imageFile;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController = TextEditingController(text: user?.username ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _imageFile = File(image.path));
    }
  }

  Future<void> _handleSave() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id ?? '';
    if (userId.isEmpty) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_nameController.text.trim().isNotEmpty &&
          _nameController.text.trim() != authProvider.user?.username) {
        await authProvider.updateUsername(userId, _nameController.text.trim());
      }

      if (_imageFile != null) {
        await authProvider.uploadAvatar(userId, _imageFile!);
      }

      if (mounted) {
        showSuccessSnackBar(context, 'Profile updated successfully');
        Navigator.pop(context);
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
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthProvider>().user;
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF10201D) : Colors.white;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 180.0,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.primary,
                        AppColors.accent,
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        const BackButton(color: Colors.white),
                        const SizedBox(width: AppSpacing.sm),
                        const Text(
                          'Edit profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: AppSpacing.xl,
                  right: AppSpacing.xl,
                  bottom: -56.0,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 46,
                              backgroundColor: scheme.primary.withValues(alpha: 0.12),
                              backgroundImage: _imageFile != null
                                  ? FileImage(_imageFile!)
                                  : (user?.avatar != null && user!.avatar.isNotEmpty)
                                      ? CachedNetworkImageProvider(user.avatar)
                                      : null,
                              child: (_imageFile == null &&
                                      (user?.avatar == null || user!.avatar.isEmpty))
                                  ? Icon(Icons.person_rounded, size: 46, color: scheme.primary)
                                  : null,
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: cardColor, width: 3),
                              ),
                              child: IconButton(
                                onPressed: _pickImage,
                                icon: const Icon(Icons.camera_alt_rounded, size: 20),
                                color: scheme.onPrimary,
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 56.0 + AppSpacing.xl),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionCard(
                      title: 'Profile details',
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppTextField(
                                controller: _nameController,
                                label: 'Display name',
                                hintText: 'Enter your name',
                                prefixIcon: Icons.person_outline_rounded,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(AppRadii.md),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.email_outlined,
                                      color: scheme.primary,
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Email',
                                            style: theme.textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: AppSpacing.xs),
                                          Text(
                                            user?.email ?? 'No email available',
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      label: 'Save changes',
                      isLoading: _isSaving,
                      onPressed: _handleSave,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
