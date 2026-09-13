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
    // Start listening BEFORE launching the browser, so we never miss the
    // auth state change event if it fires before we'd otherwise subscribe.
    final sessionFuture = client.auth.onAuthStateChange
        .firstWhere((s) => s.session != null)
        .timeout(const Duration(seconds: 90));
    await client.auth.signInWithOAuth(
      provider,
      redirectTo: oauthRedirect,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
    // If the session was already established by the time signInWithOAuth
    // returned (deep link processed faster than we could await), use it
    // directly instead of waiting on the stream.
    final existingSession = client.auth.currentSession;
    final authUser = existingSession?.user ?? (await sessionFuture).session?.user;
    if (authUser == null) {
      throw Exception('لم يتم استلام بيانات المستخدم من جوجل');
    }
    final email = authUser.email ?? '';
    final name = (authUser.userMetadata?['full_name'] ??
            authUser.userMetadata?['name'] ??
            (email.isNotEmpty ? email.split('@')[0] : 'User'))
        .toString();
    return (id: authUser.id, email: email, name: name);
  }
}
