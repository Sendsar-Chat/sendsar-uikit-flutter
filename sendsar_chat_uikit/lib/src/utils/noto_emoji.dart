import 'dart:convert';

import 'package:http/http.dart' as http;

const notoLottieBase = 'https://fonts.gstatic.com/s/e/notoemoji/latest';
const notoIndexUrl =
    'https://googlefonts.github.io/noto-emoji-animation/data/api.json';

final _availabilityCache = <String, bool>{};
Future<Set<String>?>? _notoIndexFuture;

/// Convert an emoji grapheme to Noto's codepoint key (e.g. "1f979").
String emojiToCodepointKey(String emoji) {
  final codePoints = <int>[];
  for (final rune in emoji.runes) {
    codePoints.add(rune);
  }
  return codePoints.map((cp) => cp.toRadixString(16)).join('_');
}

/// Lottie JSON URL for a Noto animated emoji.
String notoLottieUrl(String emoji) {
  return '$notoLottieBase/${emojiToCodepointKey(emoji)}/lottie.json';
}

Future<Set<String>?> _loadNotoAnimationIndex() {
  return _notoIndexFuture ??= () async {
    try {
      final response = await http.get(Uri.parse(notoIndexUrl));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final icons = data['icons'] as List<dynamic>? ?? [];
      return icons
          .map((icon) => (icon as Map<String, dynamic>)['codepoint'] as String?)
          .whereType<String>()
          .map((cp) => cp.toLowerCase())
          .toSet();
    } catch (_) {
      return null;
    }
  }();
}

/// Check whether Google hosts an animation for this emoji (cached).
Future<bool> hasNotoAnimation(String emoji) async {
  final key = emojiToCodepointKey(emoji);
  final cached = _availabilityCache[key];
  if (cached != null) return cached;

  final index = await _loadNotoAnimationIndex();
  if (index != null) {
    final available = index.contains(key);
    _availabilityCache[key] = available;
    return available;
  }

  try {
    final response = await http.head(Uri.parse(notoLottieUrl(emoji)));
    final available = response.statusCode == 200;
    _availabilityCache[key] = available;
    return available;
  } catch (_) {
    _availabilityCache[key] = false;
    return false;
  }
}

/// Clears caches — useful in tests.
void resetNotoEmojiCache() {
  _availabilityCache.clear();
  _notoIndexFuture = null;
}
