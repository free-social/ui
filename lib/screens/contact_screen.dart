import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; 

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  
  final Color kPrimaryColor = const Color(0xFF00BFA5); 
  final String supportEmail = "nupheaoeun@gmail.com"; 

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    if (_subjectController.text.trim().isEmpty || _messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    final String subject = _subjectController.text.trim();
    final String body = _messageController.text.trim();

    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        _subjectController.clear();
        _messageController.clear();
        FocusScope.of(context).unfocus();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not open email app.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color textColor = isDark ? Colors.white : const Color(0xFF1D1D1D);
    final Color subTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey[50]!;
    final Color inputFillColor = isDark ? const Color(0xFF2C2C2C) : Colors.grey[200]!;
    final Color borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Text(
          "Get in Touch",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    "We're here to help",
                    style: TextStyle(
                      fontSize: 22, 
                      fontWeight: FontWeight.bold, 
                      color: textColor
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Have a question about your expenses? Choose an option below.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subTextColor, fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            _buildOptionCard(
              icon: Icons.email_outlined,
              title: "Email Us",
              subtitle: supportEmail, 
              isLink: true,
              cardColor: cardColor,
              textColor: textColor,
              onTap: () async {
                 final Uri emailUri = Uri(scheme: 'mailto', path: supportEmail);
                 if (await canLaunchUrl(emailUri)) {
                   await launchUrl(emailUri);
                 }
              }
            ),
            const SizedBox(height: 16),
            _buildOptionCard(
              icon: Icons.menu_book_rounded,
              title: "Help Center",
              subtitle: "Visit FAQ & Guides",
              isLink: false,
              cardColor: cardColor,
              textColor: textColor,
              onTap: () {}
            ),

            const SizedBox(height: 40),
            Divider(color: borderColor, thickness: 1),
            const SizedBox(height: 30),

            Text(
              "Send a Message",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 20),

            _buildLabel("Subject", textColor),
            _buildTextField(
              controller: _subjectController, 
              hint: "What is this regarding?", 
              fillColor: inputFillColor, 
              hintColor: subTextColor
            ),
            const SizedBox(height: 20),

            _buildLabel("Message", textColor),
            _buildTextField(
              controller: _messageController, 
              hint: "How can we help you today?", 
              fillColor: inputFillColor, 
              hintColor: subTextColor,
              maxLines: 5
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _handleSend, 
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      "Send Message",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon, 
    required String title, 
    required String subtitle, 
    required Color cardColor, 
    required Color textColor,
    required VoidCallback onTap,
    bool isLink = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]
        ),
        child: Row(
          children: [
            // ✅ UPDATED CONTAINER TO MATCH SETTINGS ICON SIZE
            Container(
              padding: const EdgeInsets.all(8), // Changed from 12 to 8
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: kPrimaryColor, size: 22), // Changed from 24 to 22
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle, 
                    style: TextStyle(
                      color: isLink ? kPrimaryColor : Colors.grey[500],
                      fontWeight: isLink ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13
                    )
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 14)),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller, 
    required String hint, 
    required Color fillColor, 
    required Color hintColor,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: hintColor, fontSize: 14),
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.all(20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: kPrimaryColor.withOpacity(0.5), width: 1.5),
        ),
      ),
    );
  }
}