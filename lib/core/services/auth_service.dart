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

// The user's preferred display currency (P10 C5). `users.preferred_currency`
// is a Phase-5 column that may not exist yet in production — see
// AuthService.getPreferredCurrency. Resolves to null (no signed-in user, no
// value set, or the column doesn't exist yet) rather than throwing; callers
// fall back to a sensible default (e.g. the selected country's currency).
final preferredCurrencyProvider = FutureProvider<String?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return null;
  final authService = ref.read(authServiceProvider);
  return authService.getPreferredCurrency(user.id);
});

// True if [error] looks like Postgres/PostgREST reporting that a referenced
// column doesn't exist — e.g. the pending `preferred_currency` migration on
// `users` (see [[restructuring-phases]], Phase 5). This is diagnostic only:
// `AuthService.getPreferredCurrency`/`setPreferredCurrency` swallow ANY
// error the same way (column-absent or not) since the Settings UI can't act
// differently either way — it's exposed as a top-level function so it can
// be unit-tested without standing up a fake Supabase client.
bool isColumnAbsentError(Object error) {
  if (error is! PostgrestException) return false;
  if (error.code == 'PGRST204' || error.code == '42703') return true;
  final message = error.message.toLowerCase();
  return message.contains('column') &&
      (message.contains('does not exist') ||
          message.contains('preferred_currency'));
}

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

  // Reads the user's preferred display currency (P10 C5). Mirrors the web's
  // getPreferredCurrencyAction: an isolated, single-column SELECT — NOT part
  // of getCurrentUserProfile's main query — because `preferred_currency` is
  // a Phase-5 column that may not exist yet in production (pending
  // migration; see [[restructuring-phases]]). PostgREST 400s an entire
  // SELECT if it names a missing column, so this is wrapped in a broad
  // try/catch: a "column does not exist" PostgrestException, or ANY other
  // error, degrades to null instead of throwing. Never throws to the UI.
  Future<String?> getPreferredCurrency(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('preferred_currency')
          .eq('id', userId)
          .single();
      return response['preferred_currency'] as String?;
    } catch (_) {
      return null;
    }
  }

  // Persists the user's preferred display currency (P10 C5). Like the web's
  // updatePreferredCurrencyAction, this MAY fail if the `preferred_currency`
  // column doesn't exist yet — that's expected pre-migration, not a bug.
  // Returns false on ANY failure (column-absent or otherwise) so the caller
  // can show a neutral "not available yet" message instead of crashing or
  // surfacing a scary error. Never throws.
  Future<bool> setPreferredCurrency(String userId, String currency) async {
    try {
      await _supabase
          .from('users')
          .update({'preferred_currency': currency})
          .eq('id', userId);
      return true;
    } catch (_) {
      return false;
    }
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
