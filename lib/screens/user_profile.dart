import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/notification_service.dart';
import 'update_user_profile.dart';
import 'login_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/snackbar_helper.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _notificationsEnabled = true;

  final Color kPrimaryColor = const Color(0xFF00BFA5);
  final Color kRedColor = const Color(0xFFFF5252);

  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    final isEnabled = await NotificationService.areNotificationsEnabled();
    setState(() {
      _notificationsEnabled = isEnabled;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      // Enable notifications
      final granted = await NotificationService.requestPermissions();
      if (granted) {
        await NotificationService.scheduleDailyNotification();
        setState(() => _notificationsEnabled = true);
        if (mounted) {
          showInfoSnackBar(context, 'Daily notifications enabled at 11:50 PM');
        }
      }
    } else {
      // Disable notifications
      await NotificationService.cancelAllNotifications();
      setState(() => _notificationsEnabled = false);
      if (mounted) {
        showInfoSnackBar(context, 'Daily notifications disabled');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    // ✅ ACCESS THEME PROVIDER
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ✅ DYNAMIC COLORS (Strictly Typed)
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.grey[400]! : Colors.grey;
    final Color cardColor = theme.cardColor;
    // final Color iconColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor, // ✅ Dynamic
        title: Text(
          "Settings",
          style: TextStyle(
            color: textColor, // ✅ Dynamic
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // 1. PROFILE HEADER
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UpdateUserProfile()),
              ),
              child: Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: cardColor,
                              width: 4,
                            ), // ✅ Dynamic Border
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor:
                                Colors.grey[200]!, // ✅ Force non-null
                            backgroundImage:
                                (user?.avatar != null &&
                                    user!.avatar.isNotEmpty)
                                ? NetworkImage(user.avatar)
                                : const NetworkImage(
                                        "https://i.pravatar.cc/150?img=12",
                                      )
                                      as ImageProvider,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: kPrimaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: cardColor,
                                width: 3,
                              ), // ✅ Dynamic Border
                            ),
                            child: const Icon(
                              Icons.edit,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user?.username ?? "Default",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColor, // ✅ Dynamic
                      ),
                    ),
                    Text(
                      user?.email ?? "@example.com",
                      style: TextStyle(
                        fontSize: 14,
                        color: subTextColor,
                      ), // ✅ Dynamic
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 2. PREFERENCES SECTION
            _buildSectionHeader("PREFERENCES"),
            _buildContainerGroup(context, [
              _buildListTile(
                icon: Icons.notifications_none,
                iconColor: Colors.teal,
                title: "Enable Notifications",
                textColor: textColor,
                trailing: Switch.adaptive(
                  value: _notificationsEnabled,
                  activeColor: kPrimaryColor,
                  onChanged: _toggleNotifications,
                ),
              ),
              _buildDivider(context),
              _buildListTile(
                icon: Icons.dark_mode_outlined,
                iconColor: isDark ? Colors.white : Colors.blueGrey,
                title: "Dark Mode",
                textColor: textColor,
                trailing: Switch.adaptive(
                  value: themeProvider.isDarkMode,
                  activeColor: kPrimaryColor,
                  onChanged: (val) => themeProvider.toggleTheme(val),
                ),
              ),
            ]),
            const SizedBox(height: 24),

            // 3. ACCOUNT SECTION
            _buildSectionHeader("ACCOUNT"),
            _buildContainerGroup(context, [
              _buildListTile(
                icon: Icons.attach_money,
                iconColor: Colors.blueAccent,
                title: "Currency",
                textColor: textColor,
                trailing: Text(
                  "USD",
                  style: TextStyle(
                    color: subTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildDivider(context),
              _buildListTile(
                icon: Icons.lock_outline,
                iconColor: Colors.green,
                title: "Security",
                textColor: textColor,
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: subTextColor,
                ),
                onTap: () {
                  // Security Page
                },
              ),
            ]),
            const SizedBox(height: 24),

            // 4. SUPPORT SECTION
            _buildSectionHeader("SUPPORT"),
            _buildContainerGroup(context, [
              _buildListTile(
                icon: Icons.help_outline,
                iconColor: Colors.purpleAccent,
                title: "Help & Support",
                textColor: textColor,
                onTap: () async {
                  final Uri emailUri = Uri(
                    scheme: 'mailto',
                    path: 'oeunnuphea@gmail.com',
                  );
                  await launchUrl(emailUri);
                },
              ),
            ]),
            const SizedBox(height: 30),

            // 5. LOGOUT BUTTON
            InkWell(
              onTap: () async {
                await authProvider.logout();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: cardColor, // ✅ Dynamic
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    "Log Out",
                    style: TextStyle(
                      color: kRedColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Version 1.0.0",
              style: TextStyle(color: subTextColor, fontSize: 12),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- Helpers ---

  Widget _buildContainerGroup(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, // ✅ Dynamic Background
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider(BuildContext context) => Divider(
    height: 1,
    color: Theme.of(context).dividerColor,
    indent: 60,
    endIndent: 20,
  );

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: Colors.grey[600]!, // ✅ Force non-null
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color textColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: textColor, // ✅ Dynamic
        ),
      ),
      trailing: trailing,
    );
  }
}
