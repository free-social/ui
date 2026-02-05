import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../providers/auth_provider.dart';

class UpdateUserProfile extends StatefulWidget {
  const UpdateUserProfile({super.key});

  @override
  State<UpdateUserProfile> createState() => _UpdateUserProfileState();
}

class _UpdateUserProfileState extends State<UpdateUserProfile> {
  late TextEditingController _nameController;
  File? _imageFile;
  bool _isSaving = false;

  final Color kPrimaryColor = const Color(0xFF00BFA5); 

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    _nameController = TextEditingController(text: user?.username ?? "");
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // --- 1. PICK IMAGE LOGIC ---
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
      });
    }
  }

  // --- 2. SAVE CHANGES LOGIC ---
  Future<void> _handleSave() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final String userId = authProvider.user?.id ?? "";

    if (userId.isEmpty) return; 

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!")),
        );
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;

    // ✅ SETUP DYNAMIC COLORS (Strictly typed)
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color iconColor = isDark ? Colors.white : Colors.black;
    final Color scaffoldBg = theme.scaffoldBackgroundColor;
    
    // ✅ FIX: Force non-null with '!' and explicit types
    final Color inputFill = isDark ? Colors.grey[800]! : Colors.white;
    final Color borderColor = isDark ? Colors.grey[700]! : Colors.grey.shade200;
    final Color hintColor = isDark ? Colors.grey[400]! : Colors.grey[500]!;

    return Scaffold(
      // Background handled by Theme
      appBar: AppBar(
        elevation: 0,
        backgroundColor: scaffoldBg, // ✅ Dynamic
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: iconColor), // ✅ Dynamic
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Edit Profile",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold), // ✅ Dynamic
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  
                  // --- AVATAR SECTION ---
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor, width: 4), // ✅ Dynamic Border
                        ),
                        child: CircleAvatar(
                          radius: 65,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: _imageFile != null
                              ? FileImage(_imageFile!)
                              : (user?.avatar != null && user!.avatar.isNotEmpty)
                                  ? NetworkImage(user.avatar)
                                  : const NetworkImage("https://i.pravatar.cc/150?img=12") 
                                    as ImageProvider,
                        ),
                      ),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: kPrimaryColor,
                            shape: BoxShape.circle,
                            // Border matches scaffold background to create "cutout" effect
                            border: Border.all(color: scaffoldBg, width: 3), // ✅ Dynamic
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Text(
                    _nameController.text.isEmpty ? "No Name" : _nameController.text,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor), // ✅ Dynamic
                  ),
                  
                  TextButton(
                    onPressed: _pickImage,
                    child: Text(
                      "Change Profile Photo",
                      style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // --- FULL NAME INPUT ---
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Full Name",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor), // ✅ Dynamic
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameController,
                        onChanged: (val) => setState(() {}), 
                        style: TextStyle(color: textColor), // ✅ Dynamic Input Text
                        decoration: InputDecoration(
                          hintText: "Enter your name",
                          hintStyle: TextStyle(color: hintColor), // ✅ Dynamic
                          filled: true,
                          fillColor: inputFill, // ✅ Dynamic
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(color: borderColor), // ✅ Dynamic
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(color: borderColor), // ✅ Dynamic
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(color: kPrimaryColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // --- SAVE BUTTON ---
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                child: _isSaving 
                  ? const SizedBox(
                      width: 24, 
                      height: 24, 
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    )
                  : const Text(
                      "Save Changes",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}