const String baseURL = 'https://nimiro.chat/';
const String apiURL = '${baseURL}api/';
const String apiKey =
    '96dc536390951bf3a6bfc46a1d536ca0493cb58637390ff8faf410ea04f793b1';

// If you change this topic you also change backend .env file
String notificationTopic = "nimiro";

// Crisp live-chat website ID (Crisp dashboard > Settings > Website Settings).
// This ID is public and is required by the native Crisp SDK at runtime.
const String crispWebsiteId = '463c5a98-2443-4d67-a1c4-3b346a143d56';

// RevenueCat is disabled while these values are empty or placeholders.
// Add real public keys (goog_... for Android, appl_... for iOS) to enable it.
String revenueCatAndroidApiKey = "";
String revenueCatAppleApiKey = "";
