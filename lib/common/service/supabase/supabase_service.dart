import 'package:supabase_flutter/supabase_flutter.dart';

/// Central Supabase client configuration for Nimiro.
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  static const String url = 'https://qtdtetlyoakqfdwbgfiz.supabase.co';
  static const String anonKey =
      'sb_publishable_BIDUnumhCjZ67pcm912jnQ_S8Hjso3I';
  static const String oauthRedirect = 'nimiro://login-callback';

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    await Supabase.initialize(url: url, anonKey: anonKey);
    _initialized = true;
  }

  SupabaseClient get client => Supabase.instance.client;

  Future<bool> ping() async {
    if (!_initialized) await initialize();
    try {
      await client.from('app_users').select('user_id').limit(1);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Launches native OAuth, waits for the session, and returns a profile.
  Future<({String id, String email, String name})> signInWithOAuth(
      OAuthProvider provider) async {
    if (!_initialized) await initialize();
    await client.auth.signInWithOAuth(
      provider,
      redirectTo: oauthRedirect,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
    final authState = await client.auth.onAuthStateChange
        .firstWhere((s) => s.session != null)
        .timeout(const Duration(seconds: 90));
    final user = authState.session?.user;
    if (user == null) {
      throw Exception('لم يتم استلام بيانات المستخدم من جوجل');
    }
    final email = user.email ?? '';
    final name = (user.userMetadata?['full_name'] ??
            user.userMetadata?['name'] ??
            (email.isNotEmpty ? email.split('@')[0] : 'User'))
        .toString();
    return (id: user.id, email: email, name: name);
  }
}
