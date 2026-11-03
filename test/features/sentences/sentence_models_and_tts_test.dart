import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/features/sentences/domain/models/sentence_models.dart';

void main() {
  group('SentenceModels & AudioType', () {
    test('AudioType fromString parses human, tts, studio properly', () {
      expect(AudioType.fromString('human_recording'), AudioType.humanRecording);
      expect(AudioType.fromString('native_os_tts'), AudioType.nativeOsTts);
      expect(AudioType.fromString('studio_simulation'), AudioType.studioSimulation);
      expect(AudioType.fromString('invalid'), AudioType.unknown);
    });

    test('AudioType displayLabel and isHumanVoice are explicit and accurate', () {
      expect(AudioType.humanRecording.isHumanVoice, isTrue);
      expect(AudioType.nativeOsTts.isHumanVoice, isFalse);
      expect(AudioType.humanRecording.displayLabel, contains('Tatoeba'));
      expect(AudioType.nativeOsTts.displayLabel, contains('TTS'));
    });

    test('SentenceItem parses from JSON with tokens and audios', () {
      final json = {
        'id': 'tat_1',
        'chinese': '老师，您好！',
        'traditional': '老師，您好！',
        'pinyin': 'lǎo shī nín hǎo',
        'translation_vi': 'Chào thầy cô!',
        'translation_en': 'Hello, teacher!',
        'hsk_level': 1,
        'tokens': [
          {'word': '老师', 'pinyin': 'lǎo shī', 'meaning_vi': 'thầy cô', 'hsk_level': 1},
          {'word': '您好', 'pinyin': 'nín hǎo', 'meaning_vi': 'chào bạn', 'hsk_level': 1},
        ],
        'audios': [
          {
            'audio_id': 'audio_1276691',
            'audio_type': 'human_recording',
            'speaker': 'LeviHighway',
            'audio_url': 'https://tatoeba.org/audio/download/1276691',
            'license': 'CC BY-NC 4.0'
          }
        ],
        'has_human_audio': 1,
      };

      final sentence = SentenceItem.fromJson(json);
      expect(sentence.id, 'tat_1');
      expect(sentence.chinese, '老师，您好！');
      expect(sentence.hskLevel, 1);
      expect(sentence.hasHumanAudio, isTrue);
      expect(sentence.tokens.length, 2);
      expect(sentence.tokens.first.word, '老师');
      expect(sentence.audios.length, 1);
      expect(sentence.audios.first.audioType, AudioType.humanRecording);
      expect(sentence.audios.first.speakerName, 'LeviHighway');
    });

    test('AudioPack calculates size in MB and status correctly', () {
      const pack = AudioPack(
        id: 'audio_pack_hsk1',
        title: 'Gói âm thanh HSK 1',
        hskLevel: 1,
        sentenceCount: 250,
        totalSizeBytes: 3145728, // 3MB
        downloadStatus: 'downloaded',
        progress: 1.0,
      );

      expect(pack.isDownloaded, isTrue);
      expect(pack.isDownloading, isFalse);
      expect(pack.sizeMb, '3.0');
    });
  });
}
