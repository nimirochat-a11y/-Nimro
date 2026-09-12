import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart' as enums;
import 'package:appwrite/models.dart' as models;

/// Central Appwrite client configuration for Nimiro.
class AppwriteService {
  AppwriteService._();

  static final AppwriteService instance = AppwriteService._();

  static const String endpoint = 'https://fra.cloud.appwrite.io/v1';
  static const String projectId = '6aa0cebd002a5e332081';
  static const String callbackScheme = 'appwrite-callback-$projectId';

  // Databases
  static const String databaseId = 'nimiro_db';
  static const String appUsersCollectionId = 'app_users';

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

  /// Opens the native OAuth callback, exchanges userId/secret for a session,
  /// and returns the authenticated Appwrite profile.
  Future<models.User> signInWithOAuth(enums.OAuthProvider provider) async {
    if (!_initialized) initialize();

    final callback = await account.createOAuth2Token(
      provider: provider,
      success: '$callbackScheme://success',
      failure: '$callbackScheme://failure',
    );
    final callbackUri = Uri.parse(callback.toString());
    final userId = callbackUri.queryParameters['userId'];
    final secret = callbackUri.queryParameters['secret'];
    if (userId == null || secret == null || userId.isEmpty || secret.isEmpty) {
      throw AppwriteException('OAuth callback did not contain a userId and secret');
    }

    await account.createSession(userId: userId, secret: secret);
    return account.get();
  }
}
