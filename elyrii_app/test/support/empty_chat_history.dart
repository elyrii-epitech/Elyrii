import 'package:elyrii_app/features/chatbot/data/entities/chat_session.dart';
import 'package:elyrii_app/features/chatbot/data/repositories/chat_history_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Widget-only fixture. Repository tests exercise real SQLite separately.
class EmptyChatHistory extends ChatHistoryService {
  EmptyChatHistory() : super(factory: databaseFactoryFfi);
  @override
  Future<List<ChatSession>> sessions(
    String owner, {
    ChatSession? before,
  }) async => [];
  @override
  Future<bool> hasLegacyHistory() async => false;
  @override
  Future<void> close() async {}
}
