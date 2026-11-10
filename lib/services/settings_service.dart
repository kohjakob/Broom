import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _apiKeyKey = 'claude_api_key';
  static const _showSegmentedKey = 'show_segmented';
  bool _showSegmentedCache = true;

  bool getShowSegmentedSync() => _showSegmentedCache;

  Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyKey) ?? '';
  }

  Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, key);
  }

  Future<bool> hasApiKey() async {
    final key = await getApiKey();
    return key.isNotEmpty;
  }

  Future<bool> getShowSegmented() async {
    final prefs = await SharedPreferences.getInstance();
    _showSegmentedCache = prefs.getBool(_showSegmentedKey) ?? true;
    return _showSegmentedCache;
  }

  Future<void> setShowSegmented(bool value) async {
    _showSegmentedCache = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showSegmentedKey, value);
  }
}
