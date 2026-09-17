// flutter_3d_controller 2.3.0's public widget hides the model-viewer seek API.
// Keep the dependency on its implementation in this single adapter. This is
// the same platform renderer/asset loader, with cancellable play and pose seek.
// ignore_for_file: implementation_imports

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:flutter_3d_controller/src/core/modules/model_viewer/model_viewer.dart';
import 'package:flutter_3d_controller/src/data/datasources/i_flutter_3d_datasource.dart';
import 'package:flutter_3d_controller/src/data/repositories/flutter_3d_repository.dart';
import 'package:flutter_3d_controller/src/utils/utils.dart';

/// Commandes atomiques : attendre updateComplete avant de jouer/chercher évite
/// que model-viewer réinitialise le temps, la pause ou le nombre de répétitions.
class MascotModelController extends Flutter3DController {
  IFlutter3DDatasource? _source;
  String? _id;

  void _attach(String id, IFlutter3DDatasource source) {
    _id = id;
    _source = source;
    init(Flutter3DRepository(source));
  }

  void _command(String operation) {
    if (!onModelLoaded.value || _source == null) return;
    final cleanOp = operation.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    final js =
        '(function(){'
        'var m=document.getElementById(${jsonEncode(_id)});'
        'if(!m)return;'
        'var version=m.veloursVersion=(m.veloursVersion||0)+1;'
        '$cleanOp'
        '})();';
    _source!.executeCustomJsCodeWithResult(js);
  }

  @override
  void playAnimation({String? animationName, int loopCount = 0}) {
    final loop = loopCount <= 0 ? 'Infinity' : loopCount.toString();
    if (animationName == null) {
      _command(
        'm.updateComplete.then(function(){'
        'if(m.veloursVersion!==version)return;'
        'm.play({repetitions:$loop});'
        '});',
      );
    } else {
      final nameJson = jsonEncode(animationName);
      _command(
        'm.pause();'
        'm.animationName="";'
        'm.animationName=$nameJson;'
        'm.updateComplete.then(function(){'
        'if(m.veloursVersion!==version)return;'
        'm.currentTime=0;'
        'm.play({repetitions:$loop});'
        '});',
      );
    }
  }

  @override
  void pauseAnimation() => _command('m.pause();');

  void seekBreath(double progress) {
    final time = progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;
    _command(
      'm.pause();'
      'if(m.animationName!=="breathe"){m.animationName="breathe";}'
      'm.updateComplete.then(function(){'
      'if(m.veloursVersion!==version)return;'
      'm.pause();'
      'm.currentTime=$time;'
      '});',
    );
  }

  void restPose() {
    _command(
      'm.pause();'
      'm.animationName="idle";'
      'm.updateComplete.then(function(){'
      'if(m.veloursVersion!==version)return;'
      'm.pause();'
      'm.currentTime=0;'
      '});',
    );
  }
}

class MascotModelSurface extends StatefulWidget {
  const MascotModelSurface({
    super.key,
    required this.src,
    required this.controller,
    required this.onLoad,
    required this.onError,
    this.interactive = false,
  });

  final String src;
  final MascotModelController controller;
  final ValueChanged<String> onLoad;
  final ValueChanged<String> onError;
  final bool interactive;

  @override
  State<MascotModelSurface> createState() => _MascotModelSurfaceState();
}

class _MascotModelSurfaceState extends State<MascotModelSurface> {
  final _utils = Utils();
  late final String _id = _utils.generateId();

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      widget.controller._attach(_id, IFlutter3DDatasource(_id, null, false));
    }
  }

  @override
  Widget build(BuildContext context) => ModelViewer(
    id: _id,
    src: widget.src,
    relatedJs: _utils.injectedJS(_id, 'flutter-3d-controller'),
    cameraControls: widget.interactive,
    activeGestureInterceptor: widget.interactive,
    interactionPrompt: InteractionPrompt.none,
    animationCrossfadeDuration: 320,
    animationName: 'idle',
    autoPlay: true,
    autoRotate: false,
    ar: false,
    disableTap: true,
    debugLogging: false,
    progressBarColor: Colors.transparent,
    onWebViewCreated: kIsWeb
        ? null
        : (webView) {
            widget.controller._attach(
              _id,
              IFlutter3DDatasource(_id, webView, widget.interactive),
            );
          },
    onLoad: (address) {
      widget.controller.onModelLoaded.value = true;
      widget.onLoad(address);
    },
    onError: (error) {
      widget.controller.onModelLoaded.value = false;
      widget.onError(error);
    },
  );
}
