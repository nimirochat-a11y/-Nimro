import 'package:appwrite/appwrite.dart';

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
}
