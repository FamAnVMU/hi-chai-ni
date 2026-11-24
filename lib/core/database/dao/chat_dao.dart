import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';

class ChatDao {
  final DatabaseExecutor _db;

  ChatDao(this._db);

  Future<void> insertSession(Map<String, dynamic> session, {Transaction? txn}) async {
    final executor = txn ?? _db;
    if (session.isEmpty) return;

    final cols = session.keys.toList();
    final colNames = cols.join(', ');
    final placeholders = List.filled(cols.length, '?').join(', ');
    final args = cols.map((k) => session[k]).toList();
    final updatableCols = cols.where((k) => k != 'id' && k != 'created_at').toList();

    final conflictClause = updatableCols.isEmpty
        ? 'ON CONFLICT(id) DO NOTHING'
        : 'ON CONFLICT(id) DO UPDATE SET ${updatableCols.map((k) => '$k = excluded.$k').join(', ')}';

    await executor.rawInsert(
      'INSERT INTO ${DatabaseConstants.tableChatSessions} ($colNames) VALUES ($placeholders) $conflictClause',
      args,
    );
  }

  Future<Map<String, dynamic>?> getSessionById(String id) async {
    final results = await _db.query(
      DatabaseConstants.tableChatSessions,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getActiveSessions({int limit = 30}) async {
    return await _db.query(
      DatabaseConstants.tableChatSessions,
      where: 'deleted_at IS NULL AND is_archived = 0',
      orderBy: 'updated_at DESC',
      limit: limit,
    );
  }

  Future<void> insertMessage(Map<String, dynamic> message, {Transaction? txn}) async {
    final executor = txn ?? _db;
    await executor.insert(
      DatabaseConstants.tableChatMessages,
      message,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves up to [limit] most recent messages for a session, ordered chronologically (ASC).
  ///
  /// Uses a sliding window query (ORDER BY created_at DESC LIMIT [limit]) and reverses
  /// the resulting list to ensure chronological order for AI context building (F-08).
  Future<List<Map<String, dynamic>>> getSessionMessages(
    String sessionId, {
    int limit = 20,
  }) async {
    if (limit <= 0) return [];
    final rows = await _db.query(
      DatabaseConstants.tableChatMessages,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return rows.reversed.toList();
  }

  /// Backward-compatible alias for retrieving messages for a session.
  /// If [limit] is provided, applies sliding window; otherwise retrieves all messages ordered ASC for full session inspection.
  Future<List<Map<String, dynamic>>> getMessagesBySessionId(
    String sessionId, {
    int? limit,
  }) async {
    if (limit != null) {
      return getSessionMessages(sessionId, limit: limit);
    }
    return await _db.query(
      DatabaseConstants.tableChatMessages,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> updateSessionTitle(String sessionId, String newTitle, {Transaction? txn}) async {
    final executor = txn ?? _db;
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    await executor.update(
      DatabaseConstants.tableChatSessions,
      {
        'title': newTitle.trim(),
        'updated_at': nowUtc,
      },
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [sessionId],
    );
  }

  Future<void> deleteSession(String sessionId, {Transaction? txn}) async {
    final executor = txn ?? _db;
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    await executor.delete(
      DatabaseConstants.tableChatMessages,
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    await executor.update(
      DatabaseConstants.tableChatSessions,
      {
        'deleted_at': nowUtc,
        'updated_at': nowUtc,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> deleteMessage(String messageId, {Transaction? txn}) async {
    final executor = txn ?? _db;
    await executor.delete(
      DatabaseConstants.tableChatMessages,
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> deleteLastAssistantTurn(String sessionId, {Transaction? txn}) async {
    final executor = txn ?? _db;
    final messages = await executor.query(
      DatabaseConstants.tableChatMessages,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (messages.isNotEmpty && messages.first['role'] == 'assistant') {
      await executor.delete(
        DatabaseConstants.tableChatMessages,
        where: 'id = ?',
        whereArgs: [messages.first['id']],
      );
    }
  }

  Future<void> touchSession(String sessionId, {Transaction? txn}) async {
    final executor = txn ?? _db;
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    await executor.update(
      DatabaseConstants.tableChatSessions,
      {'updated_at': nowUtc},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }
}
