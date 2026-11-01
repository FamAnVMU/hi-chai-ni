/// Utility to normalize and search Pinyin with or without tone marks / numbers.
class PinyinHelper {
  PinyinHelper._();

  static const Map<String, String> _toneReplacements = {
    'ā': 'a', 'á': 'a', 'ǎ': 'a', 'à': 'a',
    'ē': 'e', 'é': 'e', 'ě': 'e', 'è': 'e',
    'ī': 'i', 'í': 'i', 'ǐ': 'i', 'ì': 'i',
    'ō': 'o', 'ó': 'o', 'ǒ': 'o', 'ò': 'o',
    'ū': 'u', 'ú': 'u', 'ǔ': 'u', 'ù': 'u',
    'ǖ': 'v', 'ǘ': 'v', 'ǚ': 'v', 'ǜ': 'v', 'ü': 'v',
    'Ā': 'a', 'Á': 'a', 'Ǎ': 'a', 'À': 'a',
    'Ē': 'e', 'É': 'e', 'Ě': 'e', 'È': 'e',
    'Ī': 'i', 'Í': 'i', 'Ǐ': 'i', 'Ì': 'i',
    'Ō': 'o', 'Ó': 'o', 'Ǒ': 'o', 'Ò': 'o',
    'Ū': 'u', 'Ú': 'u', 'Ǔ': 'u', 'Ù': 'u',
    'Ǖ': 'v', 'Ǘ': 'v', 'Ǚ': 'v', 'Ǜ': 'v', 'Ü': 'v',
  };

  /// Normalizes accented pinyin or numbered pinyin to a clean tone-free lowercase string.
  /// Example: 'nǐ hǎo' -> 'ni hao'
  /// Example: 'ni3 hao3' -> 'ni hao'
  static String removeTones(String pinyin) {
    String text = pinyin;
    _toneReplacements.forEach((key, val) {
      text = text.replaceAll(key, val);
    });
    // Remove tone numbers (1-5) attached to syllables
    text = text.replaceAll(RegExp(r'[1-5]'), '');
    return text.toLowerCase().trim();
  }

  /// Compacts pinyin by removing all spaces and punctuation.
  /// Example: 'nǐ hǎo' -> 'nihao'
  /// Example: 'ni3 hao3' -> 'nihao'
  static String toCompactPinyin(String pinyin) {
    final clean = removeTones(pinyin);
    return clean.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  }

  /// Checks whether an input string contains Chinese characters.
  static bool containsChinese(String input) {
    return RegExp(r'[\u4e00-\u9fa5]').hasMatch(input);
  }

  /// Checks whether an input string looks like pinyin or western text.
  static bool isPinyinOrLatin(String input) {
    return RegExp(r'^[a-zA-Z0-9\sāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜüĀÁǍÀĒÉĚÈĪÍǏÌŌÓǑÒŪÚǓÙǕǗǙǛÜ.,!?]+$')
        .hasMatch(input.trim());
  }
}
