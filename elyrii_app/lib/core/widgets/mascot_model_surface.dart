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

import 'launch_scope.dart';
import '../../features/mascot/data/models/mascot_appearance.dart';
import 'mascot_material_script.dart';

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
        'if(!m)return [];'
        'var version=m.veloursVersion=(m.veloursVersion||0)+1;'
        '$cleanOp'
        'return [];'
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

  /// Public model-viewer material variants select a fitted accessory without
  /// reloading the GLB or interrupting its current gesture.
  void setAccessoryVariant(String? accessoryId) {
    if (!onModelLoaded.value || _source == null) return;
    _source!.executeCustomJsCodeWithResult(
      '(function(){'
      'var m=document.getElementById(${jsonEncode(_id)});'
      'if(m)m.variantName=${jsonEncode(accessoryId)};return [];'
      '})();',
    );
  }

  void setAppearance(MascotAppearance appearance) {
    if (!onModelLoaded.value || _source == null) return;
    _source!.executeCustomJsCodeWithResult(
      '(function(){'
      'var m=document.getElementById(${jsonEncode(_id)});'
      'if(!m)return [];'
      'var appearance=${jsonEncode(appearance.toJson())};'
      'm.elyriiAppearance=appearance;'
      'm.elyriiApplyAppearance=function(){'
      'var appearance=m.elyriiAppearance;'
      'var revision=m.elyriiAppearanceRevision=(m.elyriiAppearanceRevision||0)+1;'
      'm.updateComplete.then(async function(){'
      'if(m.elyriiAppearanceRevision!==revision)return;'
      '$mascotMaterialScript'
      '}).catch(function(error){console.error("Elyrii appearance",error);});'
      '};'
      'if(!m.elyriiVariantListener){'
      'm.elyriiVariantListener=true;'
      'm.addEventListener("variant-applied",function(){m.elyriiApplyAppearance();});'
      '}'
      'if(!m.elyriiAppearanceTimer){'
      'm.elyriiAppearanceTimer=setTimeout(function(){'
      'm.elyriiAppearanceTimer=null;m.elyriiApplyAppearance();'
      '},60);'
      '}'
      'return [];'
      '})();',
    );
  }

  void _sceneCommand(String operation) {
    if (!onModelLoaded.value || _source == null) return;
    _source!.executeCustomJsCodeWithResult(
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
    required this.onLoad,
    required this.onError,
    this.interactive = false,
    this.accessoryVariant,
    this.appearance = const MascotAppearance(),
  });

  final String src;
  final MascotModelController controller;
  final ValueChanged<String> onLoad;
  final ValueChanged<String> onError;
  final bool interactive;
  final String? accessoryVariant;
  final MascotAppearance appearance;

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
  void didUpdateWidget(MascotModelSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.accessoryVariant != oldWidget.accessoryVariant) {
      widget.controller.setAccessoryVariant(widget.accessoryVariant);
    }
    if (widget.appearance != oldWidget.appearance ||
        widget.accessoryVariant != oldWidget.accessoryVariant) {
      widget.controller.setAppearance(widget.appearance);
    }
    if (widget.interactive != oldWidget.interactive) {
      widget.controller.setStudioRenderQuality(widget.interactive);
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
  Widget build(BuildContext context) {
    // Native WebViews / web platform views do not reliably blend with a
    // Flutter opacity overlay. Do not create the surface until the splash
    // has fully faded; the Flutter placeholder covers loading afterwards.
    if (LaunchScope.isRevealingOf(context)) return const SizedBox.shrink();

    return ModelViewer(
      id: _id,
      // Flutter places asset keys under an additional assets/ directory on
      // web. Native ModelViewer resolves the original bundle key itself.
      src: kIsWeb && widget.src.startsWith('assets/')
          ? 'assets/${widget.src}'
          : widget.src,
      variantName: widget.accessoryVariant,
      relatedJs: _utils.injectedJS(_id, 'flutter-3d-controller'),
      cameraControls: widget.interactive,
      disablePan: true,
      disableZoom: true,
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
        widget.controller.setStudioRenderQuality(widget.interactive);
        widget.controller.setAccessoryVariant(widget.accessoryVariant);
        widget.controller.setAppearance(widget.appearance);
        widget.onLoad(address);
      },
      onError: (error) {
        widget.controller.onModelLoaded.value = false;
        widget.onError(error);
      },
    );
  }
}
