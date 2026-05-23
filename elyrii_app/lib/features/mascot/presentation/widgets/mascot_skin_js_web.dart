import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Évalue un script JavaScript dans le contexte du navigateur Web.
/// Utilisé pour modifier les matériaux PBR du model-viewer 3D de la mascotte.
/// Utilise l'API moderne dart:js_interop (recommandée Flutter 3.x+).
void evalJs(String script) {
  try {
    // Injection via un élément <script> temporaire dans le <head> du document.
    // Cela permet d'exécuter du JS complexe (closures, setTimeout) sans
    // problèmes de CSP liés à window.eval().
    final scriptEl = web.HTMLScriptElement()..innerText = script;
    web.document.head!.append(scriptEl);
    // Nettoyage différé pour ne pas polluer le DOM
    Future.delayed(const Duration(milliseconds: 600), () {
      try {
        scriptEl.remove();
      } catch (_) {}
    });
  } catch (e) {
    // Fallback : globalThis.eval() via dart:js_interop
    try {
      _jsEval(script.toJS);
    } catch (_) {}
  }
}

@JS('eval')
external void _jsEval(JSString script);
