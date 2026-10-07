import 'dart:io';

bool isSocketFailure(Object error) => error is SocketException;
