/// Shared new-password policy (P10 C4), mirroring the web `registro` page:
/// at least 8 characters, one uppercase letter, and one digit.
///
/// Applied ONLY where a NEW password is set (register, change-password) —
/// NOT on the login form, where enforcing it would reject legacy accounts
/// created under the old 6-character minimum.
bool isPasswordPolicyValid(String password) {
  if (password.length < 8) return false;
  if (!password.contains(RegExp(r'[A-Z]'))) return false;
  if (!password.contains(RegExp(r'[0-9]'))) return false;
  return true;
}
