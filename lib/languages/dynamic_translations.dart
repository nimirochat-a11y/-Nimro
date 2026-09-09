import 'package:get/get.dart';
import 'package:nimiro/languages/local_translations.dart';

class DynamicTranslations extends Translations {
  final Map<String, Map<String, String>> _keys = {
    for (final entry in LocalTranslations.maps.entries)
      entry.key: Map<String, String>.from(entry.value),
  };

  @override
  Map<String, Map<String, String>> get keys => _keys;

  void addTranslations(Map<String, Map<String, String>> map) {
    map.forEach((lang, translations) {
      if (_keys.containsKey(lang)) {
        _keys[lang]?.addAll(translations); // Update existing translations
      } else {
        _keys[lang] = translations; // Add new language
      }
    });
  }
}
