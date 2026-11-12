// flutter_3d_controller 2.3.0's public widget hides the model-viewer seek API.
// Keep the dependency on its implementation in this single adapter. This is
// the same platform renderer/asset loader, with cancellable play and pose seek.
// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:flutter_3d_controller/src/core/modules/model_viewer/model_viewer.dart';
import 'package:flutter_3d_controller/src/data/datasources/i_flutter_3d_datasource.dart';
import 'package:flutter_3d_controller/src/data/repositories/flutter_3d_repository.dart';
import 'package:flutter_3d_controller/src/utils/utils.dart';

import '../diagnostics/app_diagnostics.dart';
import 'mascot_look.dart';
import 'mascot_poster.dart';
import 'mascot_scene_script.dart';

class MascotModelController extends Flutter3DController {
  MascotModelController({this._sendCommand});
  final Future<Object?> Function(String)? _sendCommand;
  IFlutter3DDatasource? _source;
  String? _id;
  bool _sceneInitialized = false;

  void _attach(String id, IFlutter3DDatasource source) {
    _id = id;
    _source = source;
    _sceneInitialized = false;
    init(Flutter3DRepository(source));
  }

  void _detach(String id) {
    if (_id != id) return;
    _source = null;
    _id = null;
    _sceneInitialized = false;
  }

  void _command(String operation) {
    final cleanOp = operation.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    final js =
        '(function(){'
        'var m=document.getElementById(${jsonEncode(_id)});'
        'if(!m)return [];'
        'var version=m.veloursVersion=(m.veloursVersion||0)+1;'
        '$cleanOp'
        'return [];'
        '})();';
    _sendJavascript(js);
  }

  void _sendJavascript(String js) {
    final source = _source;
    final send = _sendCommand ?? source?.executeCustomJsCodeWithResult;
    if (!onModelLoaded.value || send == null) return;
    unawaited(_executeCommand(send, js, source));
  }

  Future<void> _executeCommand(
    Future<Object?> Function(String) send,
    String js,
    IFlutter3DDatasource? source,
  ) async {
    try {
      await send(js);
    } catch (error) {
      if (identical(_source, source) && onModelLoaded.value) {
        AppDiagnostics.record('mascot_command_failed', error);
      }
    }
  }

  @override
  void playAnimation({String? animationName, int loopCount = 0}) {
    if (animationName == null) {
      _command('m.play();');
      return;
    }
    final loop = loopCount <= 0 ? 'Infinity' : loopCount.toString();
    _command('m.elyriiPlay(${jsonEncode(animationName)},$loop);');
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

  static const prepareTimeout = Duration(seconds: 20);

  void prepareLook(MascotLook look, int revision, List<List<double>>? pose) {
    final initialize = _sceneInitialized ? '' : mascotSceneScript;
    _sceneInitialized = true;
    _sendJavascript(
      '(function(){'
      'var m=document.getElementById(${jsonEncode(_id)});'
      'if(!m)return [];'
      'try{'
      '$initialize'
      'm.elyriiPrepare($revision,${jsonEncode(look.toJson())},${jsonEncode(pose)});'
      '}catch(error){m.elyriiPrepared=[$revision,"error",String(error)];}'
      'return [];})();',
    );
  }

  Future<List<dynamic>> preparationStatus() async {
    final send = _sendCommand ?? _source?.executeCustomJsCodeWithResult;
    if (!onModelLoaded.value || send == null) return const [];
    final result = await send(
      '(function(){var m=document.getElementById(${jsonEncode(_id)});'
      'return m&&m.elyriiPrepared||[];})();',
    );
    if (result is! List) {
      throw const FormatException('Invalid mascot frame receipt');
    }
    return result;
  }

  void _sceneCommand(String operation) {
    _sendJavascript(
      '(function(){var m=document.getElementById(${jsonEncode(_id)});'
      'if(m){$operation}return [];})();',
    );
  }

  /// Keep the editor sharp when the renderer adapts to a slower device.
  /// Restore its previous global floor when the studio leaves the screen.
  void setStudioRenderQuality(bool enabled) => _sceneCommand(
    enabled
        ? 'if(m.elyriiPreviousRenderScale===undefined){'
              'var scale=m.constructor.minimumRenderScale;'
              'm.elyriiPreviousRenderScale=typeof scale==="number"?scale:0.25;'
              '}'
              'if(m.elyriiPreviousRenderScale!==undefined){'
              'm.constructor.minimumRenderScale=Math.max(0.75,m.elyriiPreviousRenderScale);'
              '}'
        : 'if(m.elyriiPreviousRenderScale!==undefined){'
              'm.constructor.minimumRenderScale=m.elyriiPreviousRenderScale;'
              'delete m.elyriiPreviousRenderScale;'
              '}',
  );

  @override
  void setCameraOrbit(double theta, double phi, double radius) => _sceneCommand(
    'm.cameraOrbit=${jsonEncode('${theta}deg ${phi}deg $radius%')};',
  );

  @override
  void setCameraTarget(double x, double y, double z) =>
      _sceneCommand('m.cameraTarget=${jsonEncode('${x}m ${y}m ${z}m')};');

  @override
  void startRotation({int rotationSpeed = 10}) => _sceneCommand(
    'm.autoRotate=true;m.rotationPerSecond=${jsonEncode('${rotationSpeed}deg')};',
  );

  @override
  void pauseRotation() => _sceneCommand('m.autoRotate=false;');

  @override
  void stopRotation() =>
      _sceneCommand('m.autoRotate=false;m.resetTurntableRotation(0);');
}

class MascotModelSurface extends StatefulWidget {
  const MascotModelSurface({
    super.key,
    required this.src,
    required this.controller,
    required this.look,
    required this.onLoad,
    required this.onError,
    this.initialPoster,
    this.interactive = false,
  });

  final String src;
  final MascotModelController controller;
  final MascotLook look;
  final MascotPosterFrame? initialPoster;
  final ValueChanged<MascotPosterFrame> onLoad;
  final ValueChanged<String> onError;
  final bool interactive;

  @override
  State<MascotModelSurface> createState() => _MascotModelSurfaceState();
}

class _MascotModelSurfaceState extends State<MascotModelSurface> {
  final _utils = Utils();
  late final String _id = _utils.generateId();
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      widget.controller._attach(_id, IFlutter3DDatasource(_id, null, false));
    }
  }

  @override
  void didUpdateWidget(MascotModelSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.look != oldWidget.look &&
        widget.controller.onModelLoaded.value) {
      unawaited(_prepare());
    }
    if (widget.interactive != oldWidget.interactive) {
      widget.controller.setStudioRenderQuality(widget.interactive);
    }
  }

  Future<void> _prepare({bool initial = false}) async {
    final revision = ++_revision;
    final clock = Stopwatch()..start();
    widget.controller.prepareLook(
      widget.look,
      revision,
      initial ? widget.initialPoster?.pose : null,
    );
    try {
      while (mounted && revision == _revision) {
        final result = await widget.controller.preparationStatus();
        if (!mounted || revision != _revision) return;
        if (result.length >= 2 && result[0] == revision) {
          if (result[1] == 'error') throw StateError(result[2].toString());
          if (result[1] == 'ready' && result.length == 4) {
            final data = result[2] as String;
            if (!data.startsWith('data:image/png;base64,')) {
              throw const FormatException('Invalid mascot frame image');
            }
            final frame = MascotPosterFrame.fromJson({
              'png': data.substring(data.indexOf(',') + 1),
              'pose': jsonDecode(result[3] as String),
            });
            widget.onLoad(frame);
            return;
          }
        }
        if (clock.elapsed >= MascotModelController.prepareTimeout) {
          throw TimeoutException('Mascot frame was not rendered');
        }
        await Future<void>.delayed(const Duration(milliseconds: 32));
      }
    } catch (error) {
      if (mounted && revision == _revision) widget.onError(error.toString());
    }
  }

  @override
  void deactivate() {
    widget.controller.setStudioRenderQuality(false);
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    widget.controller.setStudioRenderQuality(widget.interactive);
  }

  @override
  void dispose() {
    _revision++;
    widget.controller._detach(_id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ModelViewer(
      id: _id,
      src: kIsWeb && widget.src.startsWith('assets/')
          ? 'assets/${widget.src}'
          : widget.src,
      reveal: Reveal.manual,
      loading: Loading.eager,
      relatedJs: _utils.injectedJS(_id, 'flutter-3d-controller'),
      innerModelViewerHtml:
          '<div slot="poster"></div><div slot="progress-bar"></div>',
      cameraOrbit: widget.look.cameraOrbit,
      cameraTarget: widget.look.cameraTarget,
      cameraControls: widget.interactive,
      disablePan: true,
      disableZoom: true,
      activeGestureInterceptor: widget.interactive,
      interactionPrompt: InteractionPrompt.none,
      animationCrossfadeDuration: 320,
      animationName: 'idle',
      autoPlay: false,
      autoRotate: false,
      ar: false,
      disableTap: true,
      debugLogging: false,
      progressBarColor: Colors.transparent,
      onWebViewCreated: kIsWeb
          ? null
          : (webView) {
              if (!mounted) return;
              widget.controller._attach(
                _id,
                IFlutter3DDatasource(_id, webView, widget.interactive),
              );
            },
      onLoad: (address) {
        if (!mounted) return;
        widget.controller.onModelLoaded.value = true;
        widget.controller.setStudioRenderQuality(widget.interactive);
        unawaited(_prepare(initial: true));
      },
      onError: (error) {
        if (!mounted) return;
        _revision++;
        widget.controller.onModelLoaded.value = false;
        widget.onError(error);
      },
    );
  }
}
