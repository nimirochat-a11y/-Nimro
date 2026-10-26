import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:nimiro/common/extensions/string_extension.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/model/general/settings_model.dart';

void main() {
  setUpAll(() async {
    // Initialise an in-memory GetStorage container for tests.
    await GetStorage.init('nimiro');
  });

  tearDown(() {
    // Clear settings between tests so they don't bleed into each other.
    SessionManager.instance.storage.remove(SessionKeys.setting);
  });

  group('addBaseURL()', () {
    test('returns empty string when settings are not loaded (null)', () {
      // No settings written → getSettings() returns null.
      expect('images/photo.jpg'.addBaseURL(), '');
    });

    test('returns empty string when itemBaseUrl is null', () {
      // Write a Setting with no itemBaseUrl (null).
      SessionManager.instance.setSettings(Setting(itemBaseUrl: null));
      expect('images/photo.jpg'.addBaseURL(), '');
    });

    test('returns empty string when itemBaseUrl is empty', () {
      SessionManager.instance.setSettings(Setting(itemBaseUrl: ''));
      expect('images/photo.jpg'.addBaseURL(), '');
    });

    test('returns full URL when itemBaseUrl is set', () {
      SessionManager.instance
          .setSettings(Setting(itemBaseUrl: 'https://cdn.example.com'));
      expect('images/photo.jpg'.addBaseURL(), 'https://cdn.example.comimages/photo.jpg');
    });

    test('does not crash when the string itself is empty', () {
      SessionManager.instance
          .setSettings(Setting(itemBaseUrl: 'https://cdn.example.com'));
      expect(''.addBaseURL(), 'https://cdn.example.com');
    });
  });
}
