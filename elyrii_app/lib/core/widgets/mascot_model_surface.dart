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

  void setVariant(String variantName) {
    _command('m.variantName = ${jsonEncode(variantName)};');
  }

  /// Orbite avec distance en % du cadrage auto model-viewer (ex. 105).
  void setCameraOrbitPercent(double theta, double phi, double percent) {
    final orbit = '${theta}deg ${phi}deg ${percent}%';
    _command('m.cameraOrbit = ${jsonEncode(orbit)};');
  }

  /// Active ou désactive les accessoires 3D en ajustant leur scale dans la scène.
  void setVisibleAccessories(List<String> visibleAccessoryIds) {
    final idsJson = jsonEncode(visibleAccessoryIds);
    _command(
      'm.updateComplete.then(function(){'
      'var scene = null;'
      'var symbols = Object.getOwnPropertySymbols(m);'
      'for (var i = 0; i < symbols.length; i++) {'
      '  var desc = symbols[i].toString();'
      '  if (desc.indexOf("scene") !== -1) {'
      '    scene = m[symbols[i]];'
      '    break;'
      '  }'
      '}'
      'if (!scene && m.model) {'
      '  for (var j = 0; j < symbols.length; j++) {'
      '    var d = symbols[j].toString();'
      '    if (d.indexOf("model") !== -1) {'
      '      var mObj = m[symbols[j]];'
      '      if (mObj && mObj.scene) scene = mObj.scene;'
      '      break;'
      '    }'
      '  }'
      '}'
      'if (!scene) return;'
      'var active = new Set($idsJson);'
      'var scales = {'
      '  "scarf_cozy": [0.85, 0.85, 0.85],'
      '  "bowtie_chic": [0.72, 0.72, 0.72],'
      '  "zen_necklace": [0.88, 0.88, 0.88],'
      '  "custom1": [0.90, 0.90, 0.90],'
      '  "crown_laurel": [0.85, 0.85, 0.85],'
      '  "headphones_zen": [1.0, 1.0, 1.0],'
      '  "glasses_round": [1.0, 1.0, 1.0],'
      '  "flower_mouth": [1.0, 1.0, 1.0]'
      '};'
      'scene.traverse(function(obj){'
      '  if (obj.name && obj.name.indexOf("acc_") === 0) {'
      '    var accId = obj.name.replace("acc_", "");'
      '    var isAct = active.has(accId);'
      '    obj.visible = isAct;'
      '    var targetScale = isAct ? (scales[accId] || [1, 1, 1]) : [0.0001, 0.0001, 0.0001];'
      '    obj.scale.set(targetScale[0], targetScale[1], targetScale[2]);'
      '  }'
      '});'
      '});'
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
    this.variantName,
    this.animated = true,
    this.interactive = false,
  });

  final String src;
  final MascotModelController controller;
  final ValueChanged<String> onLoad;
  final ValueChanged<String> onError;
  final String? variantName;
  final bool animated;
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
    animationName: widget.animated ? 'idle' : null,
    variantName: widget.variantName,
    autoPlay: widget.animated,
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
