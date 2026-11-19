import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';

/// Decodes a native photo at its displayed size, with asynchronous error UI.
class LocalAvatarImage extends StatefulWidget {
  const LocalAvatarImage({
    super.key,
    required this.path,
    required this.decodeSize,
  });
  final String path;
  final int decodeSize;
  @override
  State<LocalAvatarImage> createState() => _LocalAvatarImageState();
}

class _LocalAvatarImageState extends State<LocalAvatarImage> {
  late Future<Uint8List> _bytes = XFile(widget.path).readAsBytes();
  @override
  void didUpdateWidget(LocalAvatarImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _bytes = XFile(widget.path).readAsBytes();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _bytes,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
          cacheWidth: widget.decodeSize,
          cacheHeight: widget.decodeSize,
        );
      }
      if (snapshot.hasError) return const Icon(Icons.person_rounded);
      return const Center(child: CircularProgressIndicator());
    },
  );
}
