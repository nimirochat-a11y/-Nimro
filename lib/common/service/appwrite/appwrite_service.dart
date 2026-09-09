import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart' as enums;
import 'package:appwrite/models.dart' as models;

/// Central Appwrite client configuration for Nimiro.
///
/// This is intentionally additive: Firebase remains active until each feature
/// is migrated and verified. No Appwrite API key or server secret belongs in
/// the mobile application.
class AppwriteService {
  AppwriteService._();

  static final AppwriteService instance = AppwriteService._();

  static const String endpoint = 'https://fra.cloud.appwrite.io/v1';
  static const String projectId = '6aa0cebd002a5e332081';
  static const String callbackScheme = 'appwrite-callback-$projectId';
  static const String callbackUrl = '$callbackScheme://auth';

  late final Client client;
  late final Account account;
  late final Databases databases;
  late final Realtime realtime;

  bool _initialized = false;

  bool get isInitialized => _initialized;

  void initialize() {
    if (_initialized) return;

    client = Client()
      ..setEndpoint(endpoint)
      ..setProject(projectId);

    account = Account(client);
    databases = Databases(client);
    realtime = Realtime(client);
    _initialized = true;
  }

  /// Verifies that the configured Appwrite endpoint is reachable.
  Future<bool> ping() async {
    if (!_initialized) initialize();
    try {
      await client.ping();
      return true;
    } on AppwriteException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Starts an Appwrite OAuth session and returns the authenticated profile.
  /// The provider must be enabled and configured in the Appwrite Console.
  Future<models.User> signInWithOAuth(enums.OAuthProvider provider) async {
    if (!_initialized) initialize();
    await account.createOAuth2Session(
      provider: provider,
      success: callbackUrl,
    );
    return account.get();
  }
}
