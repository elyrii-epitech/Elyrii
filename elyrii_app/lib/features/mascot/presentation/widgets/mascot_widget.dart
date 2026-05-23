import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../../../../core/theme/app_colors.dart';

// On importe dart:html uniquement sur le Web via conditional import pattern
// ignore: avoid_web_libraries_in_flutter
import 'mascot_skin_js_stub.dart'
    if (dart.library.html) 'mascot_skin_js_web.dart' as skin_js;

/// Définition PBR d'un matériau pour un skin de la mascotte.
/// Chaque entrée représente [r, g, b, a, metallic, roughness].
class _MaterialDef {
  final List<double> color; // [r, g, b, a] — valeurs 0.0 à 1.0
  final double metallic;
  final double roughness;
  const _MaterialDef({
    required this.color,
    this.metallic = 0.0,
    this.roughness = 1.0,
  });
}

/// Cartographie matérielle confirmée par diagnostic colorimétrique :
/// Index 0  → root.0  : Corps / Peau principale
/// Index 1  → root.1  : Ventre / Poitrail
/// Index 2  → root.10 : Œil gauche
/// Index 3  → root.11 : Œil droit
/// Index 4  → root.2  : Patte arrière droite
/// Index 5  → root.3  : Patte arrière gauche
/// Index 6  → root.4  : Oreille externe droite
/// Index 7  → root.5  : Oreille externe gauche
/// Index 8  → root.6  : Patte avant gauche
/// Index 9  → root.7  : Patte avant droite
/// Index 10 → root.8  : Museau / Nez
/// Index 11 → root.9  : Intérieur oreilles / Contours

const Map<String, List<_MaterialDef>> _skinMaterials = {
  // ─────────────────────────────────────────────────────────────────────
  // CLASSIC : réinitialisation vers le beige naturel d'origine
  // ─────────────────────────────────────────────────────────────────────
  'classic': [
    _MaterialDef(color: [0.82, 0.67, 0.52, 1.0], metallic: 0.0, roughness: 0.85), // Corps
    _MaterialDef(color: [0.94, 0.84, 0.70, 1.0], metallic: 0.0, roughness: 0.9),  // Ventre
    _MaterialDef(color: [0.15, 0.10, 0.08, 1.0], metallic: 0.0, roughness: 0.6),  // Œil G
    _MaterialDef(color: [0.15, 0.10, 0.08, 1.0], metallic: 0.0, roughness: 0.6),  // Œil D
    _MaterialDef(color: [0.82, 0.67, 0.52, 1.0], metallic: 0.0, roughness: 0.85), // Patte AR D
    _MaterialDef(color: [0.82, 0.67, 0.52, 1.0], metallic: 0.0, roughness: 0.85), // Patte AR G
    _MaterialDef(color: [0.82, 0.67, 0.52, 1.0], metallic: 0.0, roughness: 0.85), // Oreille ext D
    _MaterialDef(color: [0.82, 0.67, 0.52, 1.0], metallic: 0.0, roughness: 0.85), // Oreille ext G
    _MaterialDef(color: [0.82, 0.67, 0.52, 1.0], metallic: 0.0, roughness: 0.85), // Patte AV G
    _MaterialDef(color: [0.82, 0.67, 0.52, 1.0], metallic: 0.0, roughness: 0.85), // Patte AV D
    _MaterialDef(color: [0.55, 0.38, 0.27, 1.0], metallic: 0.0, roughness: 0.9),  // Museau
    _MaterialDef(color: [0.94, 0.75, 0.65, 1.0], metallic: 0.0, roughness: 0.9),  // Int oreilles
  ],

  // ─────────────────────────────────────────────────────────────────────
  // CHRISTMAS : blanc neige doux, rouge festif velours, yeux verts
  // ─────────────────────────────────────────────────────────────────────
  'christmas': [
    _MaterialDef(color: [0.97, 0.97, 0.98, 1.0], metallic: 0.0, roughness: 0.85), // Corps — Blanc neige
    _MaterialDef(color: [0.87, 0.12, 0.12, 1.0], metallic: 0.0, roughness: 0.7),  // Ventre — Rouge festif
    _MaterialDef(color: [0.05, 0.45, 0.12, 1.0], metallic: 0.4, roughness: 0.5),  // Œil G — Vert sapin
    _MaterialDef(color: [0.05, 0.45, 0.12, 1.0], metallic: 0.4, roughness: 0.5),  // Œil D — Vert sapin
    _MaterialDef(color: [0.95, 0.95, 0.97, 1.0], metallic: 0.0, roughness: 0.9),  // Patte AR D — Blanc
    _MaterialDef(color: [0.95, 0.95, 0.97, 1.0], metallic: 0.0, roughness: 0.9),  // Patte AR G — Blanc
    _MaterialDef(color: [0.87, 0.12, 0.12, 1.0], metallic: 0.0, roughness: 0.7),  // Oreille ext D — Rouge
    _MaterialDef(color: [0.87, 0.12, 0.12, 1.0], metallic: 0.0, roughness: 0.7),  // Oreille ext G — Rouge
    _MaterialDef(color: [0.95, 0.95, 0.97, 1.0], metallic: 0.0, roughness: 0.9),  // Patte AV G — Blanc
    _MaterialDef(color: [0.95, 0.95, 0.97, 1.0], metallic: 0.0, roughness: 0.9),  // Patte AV D — Blanc
    _MaterialDef(color: [0.72, 0.12, 0.12, 1.0], metallic: 0.0, roughness: 0.8),  // Museau — Rouge foncé
    _MaterialDef(color: [1.00, 0.95, 0.95, 1.0], metallic: 0.0, roughness: 0.9),  // Int oreilles — Blanc pur
  ],

  // ─────────────────────────────────────────────────────────────────────
  // CYBERPUNK : carbone gris, cyan néon, magenta électrique
  // ─────────────────────────────────────────────────────────────────────
  'cyberpunk': [
    _MaterialDef(color: [0.12, 0.12, 0.14, 1.0], metallic: 0.9, roughness: 0.25), // Corps — Carbone
    _MaterialDef(color: [0.00, 0.90, 0.95, 1.0], metallic: 0.8, roughness: 0.2),  // Ventre — Cyan néon
    _MaterialDef(color: [1.00, 0.08, 0.78, 1.0], metallic: 0.9, roughness: 0.1),  // Œil G — Magenta
    _MaterialDef(color: [1.00, 0.08, 0.78, 1.0], metallic: 0.9, roughness: 0.1),  // Œil D — Magenta
    _MaterialDef(color: [0.10, 0.10, 0.12, 1.0], metallic: 0.9, roughness: 0.3),  // Patte AR D — Carbone
    _MaterialDef(color: [0.10, 0.10, 0.12, 1.0], metallic: 0.9, roughness: 0.3),  // Patte AR G — Carbone
    _MaterialDef(color: [0.00, 0.85, 0.90, 1.0], metallic: 0.9, roughness: 0.15), // Oreille ext D — Cyan
    _MaterialDef(color: [0.00, 0.85, 0.90, 1.0], metallic: 0.9, roughness: 0.15), // Oreille ext G — Cyan
    _MaterialDef(color: [0.10, 0.10, 0.12, 1.0], metallic: 0.9, roughness: 0.3),  // Patte AV G — Carbone
    _MaterialDef(color: [0.10, 0.10, 0.12, 1.0], metallic: 0.9, roughness: 0.3),  // Patte AV D — Carbone
    _MaterialDef(color: [1.00, 0.75, 0.00, 1.0], metallic: 0.8, roughness: 0.2),  // Museau — Or techno
    _MaterialDef(color: [0.00, 0.90, 0.95, 1.0], metallic: 0.8, roughness: 0.2),  // Int oreilles — Cyan
  ],

  // ─────────────────────────────────────────────────────────────────────
  // GOLD CROWN : or 24 carats poli miroir, violet impérial, obsidienne
  // ─────────────────────────────────────────────────────────────────────
  'gold_crown': [
    _MaterialDef(color: [1.00, 0.84, 0.00, 1.0], metallic: 1.0, roughness: 0.05), // Corps — Or poli
    _MaterialDef(color: [0.45, 0.00, 0.65, 1.0], metallic: 0.2, roughness: 0.7),  // Ventre — Violet impérial
    _MaterialDef(color: [0.04, 0.04, 0.06, 1.0], metallic: 0.9, roughness: 0.05), // Œil G — Obsidienne
    _MaterialDef(color: [0.04, 0.04, 0.06, 1.0], metallic: 0.9, roughness: 0.05), // Œil D — Obsidienne
    _MaterialDef(color: [1.00, 0.84, 0.00, 1.0], metallic: 1.0, roughness: 0.08), // Patte AR D — Or
    _MaterialDef(color: [1.00, 0.84, 0.00, 1.0], metallic: 1.0, roughness: 0.08), // Patte AR G — Or
    _MaterialDef(color: [0.80, 0.65, 0.00, 1.0], metallic: 1.0, roughness: 0.1),  // Oreille ext D — Or sombre
    _MaterialDef(color: [0.80, 0.65, 0.00, 1.0], metallic: 1.0, roughness: 0.1),  // Oreille ext G — Or sombre
    _MaterialDef(color: [1.00, 0.84, 0.00, 1.0], metallic: 1.0, roughness: 0.08), // Patte AV G — Or
    _MaterialDef(color: [1.00, 0.84, 0.00, 1.0], metallic: 1.0, roughness: 0.08), // Patte AV D — Or
    _MaterialDef(color: [0.04, 0.04, 0.06, 1.0], metallic: 0.9, roughness: 0.05), // Museau — Obsidienne
    _MaterialDef(color: [0.55, 0.10, 0.75, 1.0], metallic: 0.3, roughness: 0.6),  // Int oreilles — Violet
  ],
};

/// Génère le code JavaScript à injecter pour appliquer les matériaux PBR
/// d'un skin donné sur le `<model-viewer>` visible dans la page.
String _buildSkinJsScript(String skinId) {
  final defs = _skinMaterials[skinId] ?? _skinMaterials['classic']!;

  final buffer = StringBuffer();
  buffer.write('''
(function() {
  var findVisible = function(root, acc) {
    acc = acc || [];
    if (!root) return acc;
    var mvs = root.querySelectorAll('model-viewer');
    mvs.forEach(function(m) { if (m.offsetWidth > 0 && m.offsetHeight > 0) acc.push(m); });
    root.querySelectorAll('*').forEach(function(child) {
      if (child.shadowRoot) findVisible(child.shadowRoot, acc);
    });
    return acc;
  };
  var list = findVisible(document);
  if (!list.length) return;
  var mv = list[0];
  if (!mv.model) { setTimeout(arguments.callee, 300); return; }

  var defs = [
''');

  for (int i = 0; i < defs.length; i++) {
    final d = defs[i];
    buffer.write(
      '    {c:[${d.color[0]},${d.color[1]},${d.color[2]},${d.color[3]}],'
      'm:${d.metallic},r:${d.roughness}}',
    );
    if (i < defs.length - 1) buffer.write(',\n');
  }

  buffer.write('''
  ];

  mv.model.materials.forEach(function(mat, idx) {
    if (idx >= defs.length) return;
    var d = defs[idx];
    var pbr = mat.pbrMetallicRoughness;
    if (pbr.baseColorTexture && pbr.baseColorTexture.texture) {
      try { pbr.baseColorTexture.setTexture(null); } catch(e) {}
    }
    pbr.setBaseColorFactor(d.c);
    pbr.setMetallicFactor(d.m);
    pbr.setRoughnessFactor(d.r);
  });
})();
''');

  return buffer.toString();
}

/// ─────────────────────────────────────────────────────────────────────────────
/// Widget public : Mascot3DWidget
/// ─────────────────────────────────────────────────────────────────────────────
class Mascot3DWidget extends StatefulWidget {
  final double width;
  final double height;
  final bool autoRotate;
  final bool cameraControls;
  final String? activeAnimation;
  final bool autoPlay;

  /// ID du skin actif : 'classic', 'christmas', 'cyberpunk', 'gold_crown'.
  /// Lorsque ce paramètre change, les matériaux sont mis à jour dynamiquement.
  final String skinId;

  const Mascot3DWidget({
    super.key,
    this.width = 300,
    this.height = 300,
    this.autoRotate = true,
    this.cameraControls = true,
    this.activeAnimation,
    this.autoPlay = true,
    this.skinId = 'classic',
  });

  @override
  State<Mascot3DWidget> createState() => _Mascot3DWidgetState();
}

class _Mascot3DWidgetState extends State<Mascot3DWidget>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    // Le modèle 3D a besoin d'un peu de temps pour charger et parser le GLTF.
    // Après 1.4 secondes on cache le loader, puis on applique le skin.
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() => _isLoading = false);
        // On laisse encore un court délai pour que le rendu WebGL soit stable
        Future.delayed(const Duration(milliseconds: 300), _applySkin);
      }
    });
  }

  @override
  void didUpdateWidget(Mascot3DWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.skinId != widget.skinId && !_isLoading) {
      // Le skin a changé : on réapplique immédiatement
      _applySkin();
    }
  }

  /// Injecte le script JS d'application du skin dans le contexte Web.
  void _applySkin() {
    if (!kIsWeb) return;
    final script = _buildSkinJsScript(widget.skinId);
    skin_js.evalJs(script);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Lecteur 3D principal ──────────────────────────────────────
          Opacity(
            opacity: _isLoading ? 0.0 : 1.0,
            child: ModelViewer(
              backgroundColor: Colors.transparent,
              src: 'assets/base_basic_shaded.glb',
              alt: "Mascotte 3D Elyrii",
              ar: false,
              autoRotate: widget.autoRotate,
              autoRotateDelay: 2000,
              cameraControls: widget.cameraControls,
              autoPlay: widget.autoPlay,
              animationName: widget.activeAnimation,
              shadowIntensity: 0.9,
              shadowSoftness: 0.6,
              exposure: 1.2,
              disablePan: true,
              disableZoom: false,
            ),
          ),

          // ── Écran de chargement premium (Glassmorphism + Pulsation) ──
          if (_isLoading)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: widget.width * 0.8,
                    height: widget.height * 0.8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.15),
                          AppColors.accent.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 3.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Matérialisation 3D...",
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
