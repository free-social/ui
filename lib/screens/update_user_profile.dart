import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 56,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          backgroundImage: _imageFile != null
                              ? FileImage(_imageFile!)
                              : (user?.avatar != null &&
                                      user!.avatar.isNotEmpty)
                                  ? CachedNetworkImageProvider(user.avatar)
                                  : null,
                          child: (_imageFile == null &&
                                  (user?.avatar == null || user!.avatar.isEmpty))
                              ? const Icon(Icons.person_rounded, size: 54)
                              : null,
                        ),
                        IconButton.filled(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.camera_alt_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Profile photo',
                      style: theme.textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
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
    );
  }
}
