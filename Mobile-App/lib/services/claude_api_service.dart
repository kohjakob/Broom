import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'settings_service.dart';

class ItemDetectionResult {
  final String? name;
  final String? category;

  const ItemDetectionResult({this.name, this.category});
}

class ClaudeApiService {
  final SettingsService _settings;
  static const _model = 'claude-haiku-4-5-20251001';
  static const _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const _timeout = Duration(seconds: 15);

  ClaudeApiService(this._settings);

  Future<String?> detectItemName(File imageFile) async {
    final result = await detectItem(imageFile, []);
    return result.name;
  }

  Future<ItemDetectionResult> detectItem(File imageFile, List<String> categoryNames) async {
    try {
      final apiKey = await _settings.getApiKey();
      if (apiKey.isEmpty) return const ItemDetectionResult();

      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      String prompt;
      if (categoryNames.isNotEmpty) {
        final catList = categoryNames.map((c) => '"$c"').join(', ');
        prompt = 'Look at this photo. Respond with JSON only, no other text.\n'
            '{"name": "<object name, max 3 words>", "category": "<one of: $catList, or null if none fit>"}\n'
            'Identify the single most prominent object. Pick the best matching category or null.';
      } else {
        prompt = 'What is the single most prominent object in this photo? Reply with at most 3 words. Just the object name, nothing else.';
      }

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': 100,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image',
                  'source': {
                    'type': 'base64',
                    'media_type': imageFile.path.endsWith('.png') ? 'image/png' : 'image/jpeg',
                    'data': base64Image,
                  },
                },
                {
                  'type': 'text',
                  'text': prompt,
                },
              ],
            },
          ],
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['content'] as List?;
        if (content != null && content.isNotEmpty) {
          final text = (content[0]['text'] as String?)?.trim();
          if (text == null) return const ItemDetectionResult();

          if (categoryNames.isNotEmpty) {
            // Strip markdown code fences if present
            var jsonText = text;
            jsonText = jsonText.replaceAll(RegExp(r'^```\w*\s*', multiLine: true), '');
            jsonText = jsonText.replaceAll(RegExp(r'```\s*$', multiLine: true), '');
            jsonText = jsonText.trim();

            try {
              final json = jsonDecode(jsonText) as Map<String, dynamic>;
              final name = json['name'] as String?;
              final category = json['category'];
              return ItemDetectionResult(
                name: name?.trim(),
                category: (category is String && category != 'null') ? category.trim() : null,
              );
            } catch (_) {
              // Fallback: treat as plain name, use stripped text
              return ItemDetectionResult(name: jsonText);
            }
          } else {
            return ItemDetectionResult(name: text);
          }
        }
      } else {
        debugPrint('Claude API error ${response.statusCode}: ${response.body}');
      }
      return const ItemDetectionResult();
    } catch (e) {
      debugPrint('Claude API exception: $e');
      return const ItemDetectionResult();
    }
  }

  Future<bool> testApiKey() async {
    try {
      final apiKey = await _settings.getApiKey();
      if (apiKey.isEmpty) return false;

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': 10,
          'messages': [
            {
              'role': 'user',
              'content': 'Hi',
            },
          ],
        }),
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('Claude API test failed ${response.statusCode}: ${response.body}');
      }
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Claude API test exception: $e');
      return false;
    }
  }
}
