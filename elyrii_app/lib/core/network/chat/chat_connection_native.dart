import 'dart:io';

import 'chat_transport.dart';

Future<ChatConnection> connect(Uri uri, {String? token}) async {
  if (token == null || token.isEmpty) {
    throw const ChatTransportException('Connecte-toi pour envoyer un message.');
  }
  var expired = false;
  final opening = WebSocket.connect(
    uri.toString(),
    headers: {'Authorization': 'Bearer $token'},
  );
  opening.then((socket) {
    if (expired) socket.close();
  }, onError: (Object _) {});
  final socket = await opening.timeout(
    const Duration(seconds: 15),
    onTimeout: () {
      expired = true;
      throw const ChatTransportException(
        'La connexion au chat a expiré. Réessaie.',
      );
    },
  );
  return _NativeConnection(socket);
}

class _NativeConnection implements ChatConnection {
  _NativeConnection(this.socket);
  final WebSocket socket;
  @override
  Stream<Object?> get frames => socket;
  @override
  void send(String payload) => socket.add(payload);
  @override
  Future<void> close() async {
    await socket.close();
  }
}
