import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../providers/supabase_provider.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseClientProvider));
});

final authStateProvider = StreamProvider<User?>((ref) {
  // Pull the client from the provider graph so tests can override it.
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.onAuthStateChange.map(
    (event) => event.session?.user,
  );
});

final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) async {
      if (user == null) return null;
      final authService = ref.read(authServiceProvider);
      return await authService.getCurrentUserProfile();
    },
    loading: () => null,
    error: (_, _) => null,
  );
});

class AuthService {
  final SupabaseClient _supabase;

  AuthService(this._supabase);

  // Web Client ID from Google Cloud Console / Firebase
  static const String _webClientId =
      '306853215674-r4d0tl2sol50k1chms3jssk6742pe6md.apps.googleusercontent.com';

  // google_sign_in 7.x: the plugin now uses a singleton (`GoogleSignIn.instance`)
  // and must be `initialize()`-d once before use. The old per-instance
  // constructor + `.signIn()` + `.accessToken` API is gone — `.authentication`
  // only exposes `idToken`; access tokens now require an explicit
  // `authorizeScopes()` call which is out of scope for the basic Google sign-in
  // flow Supabase needs.
  bool _initialized = false;

  Future<void> _ensureGoogleInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(serverClientId: _webClientId);
    _initialized = true;
  }

  User? get currentUser => _supabase.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  // Email & Password Sign Up
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );

    if (response.user != null) {
      await _createUserProfile(response.user!, name);
    }

    return response;
  }

  // Email & Password Sign In
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Google Sign In
  Future<AuthResponse> signInWithGoogle() async {
    await _ensureGoogleInitialized();

    final GoogleSignInAccount googleUser =
        await GoogleSignIn.instance.authenticate();

    final GoogleSignInAuthentication googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;

    if (idToken == null) {
      throw Exception('No ID Token found');
    }

    final response = await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      // google_sign_in 7.x: no accessToken on GoogleSignInAuthentication
      // (only idToken). Supabase's google id-token flow accepts idToken
      // alone, so we omit accessToken.
    );

    if (response.user != null) {
      // Check if profile exists, if not create it
      final existingProfile = await getCurrentUserProfile();
      if (existingProfile == null) {
        await _createUserProfile(
          response.user!,
          googleUser.displayName,
          avatarUrl: googleUser.photoUrl,
        );
      }
    }

    return response;
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // signOut can throw if GoogleSignIn was never initialized; safe to ignore.
    }
    await _supabase.auth.signOut();
  }

  // Reset Password
  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  // Resend email verification
  Future<void> resendVerificationEmail(String email) async {
    try {
      await _supabase.auth.resend(type: OtpType.email, email: email);
    } catch (e) {
      throw Exception('Could not resend verification email: $e');
    }
  }

  // Get Current User Profile
  Future<AppUser?> getCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .single();

      return AppUser.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // Update User Profile
  Future<void> updateUserProfile({
    String? name,
    String? phone,
    String? avatarUrl,
    String? countryCode,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (name != null) updates['name'] = name;
    if (phone != null) updates['phone'] = phone;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (countryCode != null) updates['country_code'] = countryCode;

    await _supabase.from('users').update(updates).eq('id', user.id);
  }

  // Create User Profile
  Future<void> _createUserProfile(
    User user,
    String? name, {
    String? avatarUrl,
  }) async {
    await _supabase.from('users').upsert({
      'id': user.id,
      'email': user.email,
      'name':
          name ?? user.userMetadata?['name'] ?? user.email?.split('@').first,
      'avatar_url': avatarUrl ?? user.userMetadata?['avatar_url'],
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // Delete Account — runs server-side via the `delete-account` edge function,
  // which deletes the auth user (cascading to profile, listings and favorites).
  // The client can't do this itself: it can't touch auth.users, and RLS blocks
  // deleting the public.users row, so the previous client-side deletes silently
  // left the account intact and the user could still log back in.
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    final res = await _supabase.functions.invoke('delete-account');
    if (res.status != 200) {
      final error = (res.data is Map) ? res.data['error'] as String? : null;
      throw Exception(error ?? '${res.status}');
    }

    await signOut();
  }

  // Update the current user's password.
  Future<void> updatePassword(String newPassword) async {
    await _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }
}
