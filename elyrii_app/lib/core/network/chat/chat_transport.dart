abstract interface class ChatConnection {
  Stream<Object?> get frames;
  void send(String payload);
  Future<void> close();
}

typedef ChatConnector = Future<ChatConnection> Function(
  Uri uri, {
  String? token,
});

class ChatTransportException implements Exception {
  const ChatTransportException(this.message);
  final String message;
  @override
  String toString() => message;
}
