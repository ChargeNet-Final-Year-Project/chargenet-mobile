/// Form validators shared by the login and register screens.
///
/// The rules sit in one place so the login and register forms cannot drift
/// apart, and so the messages the user reads are worded identically.
class AuthValidators {
  /// Minimum password length the backend accepts.
  static const int minPasswordLength = 8;

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? name(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Enter your name';
    if (name.length < 2) return 'That name looks too short';
    return null;
  }

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email';
    if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address';
    return null;
  }

  /// Login only checks presence: the length rule is enforced at registration,
  /// so an older account is never locked out on the client.
  static String? requiredPassword(String? value) =>
      (value == null || value.isEmpty) ? 'Enter your password' : null;

  static String? newPassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Enter your password';
    if (password.length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Re-enter your password';
    if (value != password) return 'Passwords do not match';
    return null;
  }
}
