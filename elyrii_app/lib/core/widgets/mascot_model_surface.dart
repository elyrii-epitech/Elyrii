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
    try {
      _source!.executeCustomJsCodeWithResult(js);
    } catch (_) {}
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

  /// Applique les teintes du thème aux matériaux PBR 3D et via le filtre de couleur CSS
  void setThemeColors(List<Color>? paletteColors, List<double>? matrix) {
    final hasMatrix = matrix != null && matrix.length == 20;
    const identity = <double>[
      1, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ];
    final isIdentity = !hasMatrix || List.generate(
      20,
      (i) => (matrix[i] - identity[i]).abs() < 0.001,
    ).every((v) => v);


    String pbrJs = '';
    if (isIdentity) {
      pbrJs = '''
        if (m.model && m.model.materials) {
          var mats = m.model.materials;
          if (mats.length > 0 && mats[0].pbrMetallicRoughness) mats[0].pbrMetallicRoughness.setBaseColorFactor([1.0, 1.0, 1.0, 1.0]);
          if (mats.length > 1 && mats[1].pbrMetallicRoughness) mats[1].pbrMetallicRoughness.setBaseColorFactor([1.0, 1.0, 1.0, 1.0]);
          if (mats.length > 2 && mats[2].pbrMetallicRoughness) mats[2].pbrMetallicRoughness.setBaseColorFactor([1.0, 1.0, 1.0, 1.0]);
          if (mats.length > 3 && mats[3].pbrMetallicRoughness) mats[3].pbrMetallicRoughness.setBaseColorFactor([0.888, 0.631, 0.392, 1.0]);
        }
      ''';
    } else if (paletteColors != null && paletteColors.isNotEmpty) {
      final fur = paletteColors[0];
      final ears = paletteColors.length > 1 ? paletteColors[1] : fur;
      final r0 = (fur.r).toStringAsFixed(3);
      final g0 = (fur.g).toStringAsFixed(3);
      final b0 = (fur.b).toStringAsFixed(3);
      final r1 = (ears.r).toStringAsFixed(3);
      final g1 = (ears.g).toStringAsFixed(3);
      final b1 = (ears.b).toStringAsFixed(3);
      pbrJs = '''
        if (m.model && m.model.materials) {
          var mats = m.model.materials;
          if (mats.length > 0 && mats[0].pbrMetallicRoughness) mats[0].pbrMetallicRoughness.setBaseColorFactor([1.0, 1.0, 1.0, 1.0]);
          if (mats.length > 1 && mats[1].pbrMetallicRoughness) mats[1].pbrMetallicRoughness.setBaseColorFactor([$r0, $g0, $b0, 1.0]);
          if (mats.length > 2 && mats[2].pbrMetallicRoughness) mats[2].pbrMetallicRoughness.setBaseColorFactor([$r1, $g1, $b1, 1.0]);
          if (mats.length > 3 && mats[3].pbrMetallicRoughness) mats[3].pbrMetallicRoughness.setBaseColorFactor([$r0, $g0, $b0, 1.0]);
        }
      ''';
    }

    final js = '''
      m.updateComplete.then(function(){
        $pbrJs
      });
    ''';
    _command(js);
  }

  /// Applique un filtre de couleur CSS (feColorMatrix) directement sur le canvas 3D WebGL
  void setColorMatrix(List<double>? matrix) => setThemeColors(null, matrix);

  /// Orbite avec distance en % du cadrage auto model-viewer (ex. 105).
  void setCameraOrbitPercent(double theta, double phi, double percent) {
    final orbit = '${theta}deg ${phi}deg $percent%';
    _command('m.cameraOrbit = ${jsonEncode(orbit)};');
  }

  /// Active ou désactive les accessoires 3D en ajustant leur scale dans la scène.
  void setVisibleAccessories(List<String> visibleAccessoryIds) {
    final idsJson = jsonEncode(visibleAccessoryIds);
    _command('''
      function applyAcc(m) {
        var scene = m._cachedScene;
        if (!scene) {
          var symbols = Object.getOwnPropertySymbols(m);
          for (var i = 0; i < symbols.length; i++) {
            if (symbols[i].toString().indexOf("scene") !== -1) {
              scene = m[symbols[i]];
              break;
            }
          }
          if (!scene && m.model) {
            for (var j = 0; j < symbols.length; j++) {
              if (symbols[j].toString().indexOf("model") !== -1) {
                var mObj = m[symbols[j]];
                if (mObj && mObj.scene) scene = mObj.scene;
                break;
              }
            }
          }
          if (scene) m._cachedScene = scene;
        }
        if (!scene) return;
        var active = new Set($idsJson);
        var scales = {
          "scarf_cozy": [1.0, 1.0, 1.0],
          "bowtie_chic": [1.0, 1.0, 1.0],
          "zen_necklace": [1.0, 1.0, 1.0],
          "custom1": [1.0, 1.0, 1.0],
          "crown_laurel": [1.0, 1.0, 1.0],
          "headphones_zen": [1.0, 1.0, 1.0],
          "glasses_round": [1.0, 1.0, 1.0],
          "flower_mouth": [1.0, 1.0, 1.0]
        };
        scene.traverse(function(obj){
          if (obj.name && obj.name.indexOf("acc_") === 0) {
            var accId = obj.name.replace("acc_", "");
            var isAct = active.has(accId);
            obj.visible = isAct;
            var targetScale = isAct ? (scales[accId] || [1, 1, 1]) : [0.0001, 0.0001, 0.0001];
            obj.scale.set(targetScale[0], targetScale[1], targetScale[2]);
          }
        });
      }
      applyAcc(m);
      m.updateComplete.then(function(){ applyAcc(m); });
    ''');
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
    this.cameraOrbit,
    this.cameraTarget,
    this.animated = true,
    this.interactive = false,
  });

  final String src;
  final MascotModelController controller;
  final ValueChanged<String> onLoad;
  final ValueChanged<String> onError;
  final String? variantName;
  final String? cameraOrbit;
  final String? cameraTarget;
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
    cameraOrbit: widget.cameraOrbit,
    cameraTarget: widget.cameraTarget,
    autoPlay: widget.animated,
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
