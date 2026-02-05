class ValidationUtils {
  static bool isValidPassword(String password) {
    // Password must be at least 6 chars and include uppercase, lowercase, number, and special character
    final regex = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*])[A-Za-z\d!@#$%^&*]{6,}$',
    );
    return regex.hasMatch(password);
  }

  static bool isValidEmail(String email) {
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return regex.hasMatch(email);
  }

  static bool isValidUsername(String username) {
    return username.length >= 3;
  }

  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) return 'Password is required';
    if (password.length < 6) return 'Password must be at least 6 characters';
    if (!password.contains(RegExp(r'[a-z]')))
      return 'Password must contain lowercase letter';
    if (!password.contains(RegExp(r'[A-Z]')))
      return 'Password must contain uppercase letter';
    if (!password.contains(RegExp(r'[0-9]')))
      return 'Password must contain number';
    if (!password.contains(RegExp(r'[!@#\$%^&*]')))
      return 'Password must contain special character (!@#\$%^&*)';
    return null;
  }

  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) return 'Email is required';
    if (!isValidEmail(email)) return 'Please enter a valid email';
    return null;
  }

  static String? validateUsername(String? username) {
    if (username == null || username.isEmpty) return 'Username is required';
    if (username.length < 3) return 'Username must be at least 3 characters';
    return null;
  }
}
