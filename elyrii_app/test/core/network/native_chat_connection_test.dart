import 'dart:async';
import 'dart:io';

import 'package:elyrii_app/core/network/chat/chat_connection.dart';
import 'package:flutter_test/flutter_test.dart';

// Widget binding mocks HTTP by default; this local fixture uses real IO.
class _LocalNetwork extends HttpOverrides {}

void main() {
  test(
    'native WebSocket authenticates its handshake and exchanges real frames',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      WebSocket? serverSocket;
      ChatConnection? connection;
      final authorization = Completer<String?>();
      final received = Completer<String>();
      final subscription = server.listen((request) async {
        authorization.complete(
          request.headers.value(HttpHeaders.authorizationHeader),
        );
        serverSocket = await WebSocketTransformer.upgrade(request);
        serverSocket!.listen((frame) {
          received.complete(frame as String);
          serverSocket!.add('fixture reply');
        });
      });
      addTearDown(() async {
        await connection?.close();
        await serverSocket?.close();
        await subscription.cancel();
        await server.close(force: true);
      });
      final uri = Uri(
        scheme: 'ws',
        host: server.address.address,
        port: server.port,
        path: '/chat',
      );
      final opened = await HttpOverrides.runWithHttpOverrides(
        () => openChatConnection(uri, token: 'fixture-token'),
        _LocalNetwork(),
      );
      connection = opened;
      expect(
        await authorization.future.timeout(const Duration(seconds: 5)),
        'Bearer fixture-token',
      );
      expect(uri.hasQuery, isFalse);
      final reply = opened.frames.first;
      opened.send('fixture request');
      expect(
        await received.future.timeout(const Duration(seconds: 5)),
        'fixture request',
      );
      expect(await reply.timeout(const Duration(seconds: 5)), 'fixture reply');
    },
  );

  test('native WebSocket rejects missing credentials before a connection is opened', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    final subscription = server.listen((request) {
      requests++;
      request.response.close();
    });
    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
    });
    final uri = Uri(
      scheme: 'ws',
      host: server.address.address,
      port: server.port,
    );
    for (final token in <String?>[null, '']) {
      await expectLater(
        openChatConnection(uri, token: token),
        throwsA(isA<ChatTransportException>()),
      );
    }
    expect(requests, 0);
  });
}
