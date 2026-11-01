import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';

class ChatDao {
  final DatabaseExecutor _db;

  ChatDao(this._db);

  Future<void> insertSession(Map<String, dynamic> session, {Transaction? txn}) async {
    final executor = txn ?? _db;
    await executor.insert(
      DatabaseConstants.tableChatSessions,
      session,
      conflictAlgorithm: ConflictAlgorithm.replace,
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

  Future<List<Map<String, dynamic>>> getMessagesBySessionId(String sessionId) async {
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
