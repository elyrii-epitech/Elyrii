import 'chat_connection_native.dart' as native;
import 'chat_transport.dart';
export 'chat_transport.dart';

Future<ChatConnection> openChatConnection(Uri uri, {String? token}) =>
    native.connect(uri, token: token);
