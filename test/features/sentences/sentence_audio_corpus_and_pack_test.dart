import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hi_chinese/features/sentences/data/audio_pack_manager.dart';
import 'package:hi_chinese/features/sentences/data/sentence_dao.dart';
import 'package:hi_chinese/features/sentences/domain/models/sentence_models.dart';

class _StubSentenceDao implements SentenceDao {
  final List<SentenceItem> items;
  final Map<String, String> updatedPaths = {};

  _StubSentenceDao(this.items);

  @override
  Future<List<SentenceItem>> getSentencesByHskLevel(
    int hskLevel, {
    int limit = 50,
    int offset = 0,
    bool humanAudioOnly = false,
  }) async =>
      items;

  @override
  Future<void> updateAudioLocalPath(
    String audioId,
    String localPath,
    String status,
  ) async {
    updatedPaths[audioId] = '$status:$localPath';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SentenceAudio Mapping & AudioPackManager Security', () {
    test('SentenceAudio.fromMap resolves audio_id and fallbackSentenceId instead of empty id', () {
      final fromAudioId = SentenceAudio.fromMap({
        'audio_id': 'AUD_99',
        'sentence_id': 'S_99',
        'audio_type': 'human_recording',
      });
      expect(fromAudioId.id, equals('AUD_99'));
      expect(fromAudioId.sentenceId, equals('S_99'));

      final fromFallback = SentenceAudio.fromMap(
        {
          'audio_type': 'studio_simulation',
        },
        fallbackSentenceId: 'S_42',
      );
      expect(fromFallback.id, isNotEmpty);
      expect(fromFallback.sentenceId, equals('S_42'));
    });

    test('SentenceItem.fromJson propagates sentence id to audio variants missing id', () {
      final item = SentenceItem.fromJson({
        'id': 'HSK1_001',
        'chinese': '你好！',
        'pinyin': 'Nǐ hǎo!',
        'meaning_vi': 'Xin chào!',
        'hsk_level': 1,
        'audios': [
          {
            'audio_type': 'human_recording',
            'speaker_name': 'Native',
            'url_remote': 'audio/sentences/hsk1_001.mp3',
          }
        ],
      });

      expect(item.audios, hasLength(1));
      expect(item.audios.first.id, isNotEmpty);
      expect(item.audios.first.sentenceId, equals('HSK1_001'));
    });

    test('AudioPackManager throws on HTTP error or socket failure in production mode', () async {
      final dir = await Directory.systemTemp.createTemp('pack_fail_test_');
      try {
        final httpFailManager = AudioPackManager(
          _StubSentenceDao(const []),
          storageDirectory: dir.path,
          client: MockClient((_) async => http.Response('Not Found', 404)),
        );
        await expectLater(
          httpFailManager.downloadPack('audio_pack_hsk3'),
          throwsA(isA<HttpException>()),
        );

        final netFailManager = AudioPackManager(
          _StubSentenceDao(const []),
          storageDirectory: dir.path,
          client: MockClient((_) async => throw const SocketException('Offline')),
        );
        await expectLater(
          netFailManager.downloadPack('audio_pack_hsk3'),
          throwsA(isA<SocketException>()),
        );
      } finally {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      }
    });

    test('AudioPackManager downloads, verifies SHA256, extracts valid audio, and updates DAO', () async {
      final dir = await Directory.systemTemp.createTemp('pack_ok_test_');
      try {
        final archive = Archive()
          ..addFile(ArchiveFile('AUD_01.mp3', 4, [0x49, 0x44, 0x33, 0x03]));
        final zipBytes = ZipEncoder().encode(archive);
        final digest = sha256.convert(zipBytes).toString();

        final sentence = SentenceItem(
          id: 'S_01',
          chinese: '你好',
          pinyin: 'Nǐ hǎo',
          translationVi: 'Xin chào',
          hskLevel: 3,
          audios: [
            SentenceAudio(
              id: 'AUD_01',
              sentenceId: 'S_01',
              audioType: AudioType.humanRecording,
              speakerName: 'Native',
              urlRemote: 'https://example.com/aud_01.mp3',
            ),
          ],
        );
        final dao = _StubSentenceDao([sentence]);
        final manager = AudioPackManager(
          dao,
          storageDirectory: dir.path,
          client: MockClient((_) async => http.Response.bytes(zipBytes, 200)),
        );

        await manager.downloadPack(
          'audio_pack_hsk3',
          customDownloadUrl: 'https://example.com/audio_pack_hsk3.zip',
          expectedSha256: digest,
        );

        expect(dao.updatedPaths['AUD_01'], startsWith('downloaded:'));
      } finally {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      }
    });
  });
}
