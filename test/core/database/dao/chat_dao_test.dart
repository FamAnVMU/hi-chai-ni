import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/dao/chat_dao.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ChatDao Sliding Window & Session Message Tests (F-08)', () {
    late Database db;
    late ChatDao chatDao;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (d, v) async {
          await d.execute('''
            CREATE TABLE ${DatabaseConstants.tableChatSessions} (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              scenario_code TEXT NOT NULL,
              is_archived INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              deleted_at TEXT
            );
          ''');
          await d.execute('''
            CREATE TABLE ${DatabaseConstants.tableChatMessages} (
              id TEXT PRIMARY KEY,
              session_id TEXT NOT NULL,
              role TEXT NOT NULL,
              content TEXT NOT NULL,
              pinyin TEXT,
              translation_vi TEXT,
              audio_uri TEXT,
              tokens_used INTEGER DEFAULT 0,
              created_at TEXT NOT NULL
            );
          ''');
          await d.execute(
            'CREATE INDEX idx_chat_messages_session ON ${DatabaseConstants.tableChatMessages} (session_id, created_at);',
          );
        },
      );
      chatDao = ChatDao(db);

      // Insert primary test session
      await chatDao.insertSession({
        'id': 'session_primary',
        'title': 'Test Session Primary',
        'scenario_code': 'free_chat',
        'is_archived': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Insert secondary test session for isolation check
      await chatDao.insertSession({
        'id': 'session_secondary',
        'title': 'Test Session Secondary',
        'scenario_code': 'ordering_food',
        'is_archived': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> insertMessages(String sessionId, int count) async {
      final baseTime = DateTime.parse('2026-01-01T08:00:00.000Z');
      for (int i = 1; i <= count; i++) {
        final messageTime = baseTime.add(Duration(minutes: i)).toIso8601String();
        await chatDao.insertMessage({
          'id': '${sessionId}_msg_$i',
          'session_id': sessionId,
          'role': (i % 2 == 1) ? 'user' : 'assistant',
          'content': 'Message #$i from $sessionId',
          'pinyin': null,
          'translation_vi': null,
          'audio_uri': null,
          'tokens_used': 10,
          'created_at': messageTime,
        });
      }
    }

    test('1. Empty session returns empty list', () async {
      final messages = await chatDao.getSessionMessages('session_primary');
      expect(messages, isEmpty);
    });

    test('2. Session with 10 messages returns all 10 messages in ASC order', () async {
      await insertMessages('session_primary', 10);

      final messages = await chatDao.getSessionMessages('session_primary');
      expect(messages.length, equals(10));
      expect(messages.first['content'], equals('Message #1 from session_primary'));
      expect(messages.last['content'], equals('Message #10 from session_primary'));

      // Verify strict ASC order
      for (int i = 0; i < messages.length - 1; i++) {
        final current = DateTime.parse(messages[i]['created_at'] as String);
        final next = DateTime.parse(messages[i + 1]['created_at'] as String);
        expect(current.isBefore(next), isTrue);
      }
    });

    test('3. Session with exactly 20 messages returns all 20 messages in ASC order', () async {
      await insertMessages('session_primary', 20);

      final messages = await chatDao.getSessionMessages('session_primary');
      expect(messages.length, equals(20));
      expect(messages.first['content'], equals('Message #1 from session_primary'));
      expect(messages.last['content'], equals('Message #20 from session_primary'));
    });

    test('4. Session with 30 messages returns only the 20 most recent messages in ASC order', () async {
      await insertMessages('session_primary', 30);

      final messages = await chatDao.getSessionMessages('session_primary');
      expect(messages.length, equals(20));

      // Should contain messages 11 through 30 (not 1 through 20)
      expect(messages.first['content'], equals('Message #11 from session_primary'));
      expect(messages.last['content'], equals('Message #30 from session_primary'));

      // Verify ascending order
      for (int i = 0; i < messages.length - 1; i++) {
        final current = DateTime.parse(messages[i]['created_at'] as String);
        final next = DateTime.parse(messages[i + 1]['created_at'] as String);
        expect(current.isBefore(next), isTrue);
      }
    });

    test('5. Session with 100 messages returns only the 20 most recent messages in ASC order', () async {
      await insertMessages('session_primary', 100);

      final messages = await chatDao.getSessionMessages('session_primary');
      expect(messages.length, equals(20));

      // Should contain messages 81 through 100
      expect(messages.first['content'], equals('Message #81 from session_primary'));
      expect(messages.last['content'], equals('Message #100 from session_primary'));
    });

    test('6. Session isolation: Messages from another session are never included', () async {
      await insertMessages('session_primary', 15);
      await insertMessages('session_secondary', 15);

      final primaryMessages = await chatDao.getSessionMessages('session_primary');
      expect(primaryMessages.length, equals(15));
      for (final m in primaryMessages) {
        expect(m['session_id'], equals('session_primary'));
      }

      final secondaryMessages = await chatDao.getSessionMessages('session_secondary');
      expect(secondaryMessages.length, equals(15));
      for (final m in secondaryMessages) {
        expect(m['session_id'], equals('session_secondary'));
      }
    });

    test('7. Boundary condition: limit <= 0 safely returns empty list without SQL error', () async {
      await insertMessages('session_primary', 10);

      expect(await chatDao.getSessionMessages('session_primary', limit: 0), isEmpty);
      expect(await chatDao.getSessionMessages('session_primary', limit: -5), isEmpty);
    });

    test('8. Custom limit parameter works properly', () async {
      await insertMessages('session_primary', 30);

      final messages = await chatDao.getSessionMessages('session_primary', limit: 5);
      expect(messages.length, equals(5));
      // Should be messages 26 to 30
      expect(messages.first['content'], equals('Message #26 from session_primary'));
      expect(messages.last['content'], equals('Message #30 from session_primary'));
    });

    test('9. Full database retention: getMessagesBySessionId still retrieves all messages', () async {
      await insertMessages('session_primary', 50);

      // getSessionMessages caps at default 20
      final limited = await chatDao.getSessionMessages('session_primary');
      expect(limited.length, equals(20));

      // getMessagesBySessionId without limit returns all 50 messages for full UI inspection
      final all = await chatDao.getMessagesBySessionId('session_primary');
      expect(all.length, equals(50));
      expect(all.first['content'], equals('Message #1 from session_primary'));
      expect(all.last['content'], equals('Message #50 from session_primary'));
    });
  });
}
