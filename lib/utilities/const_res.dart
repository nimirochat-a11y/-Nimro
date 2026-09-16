const String baseURL = 'https://nimiro.chat/';
const String apiURL = '${baseURL}api/';

/// SECURITY (S6): the literal `retry123` used to be compiled into every build
/// and sent as `apikey` on all ~90 /api endpoints — a publicly known constant
/// guarding the whole backend. The value is now injected at build time:
///   flutter build apk --dart-define=NIMIRO_API_KEY=<rotated key>
/// An empty value means the backend rejects every request, which is the safe
/// failure mode (fail-closed) rather than shipping a known secret.
const String apiKey = String.fromEnvironment('NIMIRO_API_KEY', defaultValue: '');

// If you change this topic you also change backend .env file
String notificationTopic = "nimiro";

String revenueCatAndroidApiKey = "______"; // revenueCat android api
String revenueCatAppleApiKey = "________"; // revenueCat apple api
