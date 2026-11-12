import 'mascot_material_script.dart';
import 'mascot_motion_script.dart';

const String mascotSceneScript =
    '''
$mascotMotionScript
if (!m.elyriiPrepare) {
  const scene = m[Object.getOwnPropertySymbols(m).find(key => key.description === 'scene')];
  const frame = () => new Promise(resolve => requestAnimationFrame(resolve));
  m.elyriiPrepare = function (revision, look, initialPose) {
    m.elyriiLookRevision = revision;
    m.elyriiAppearanceRevision = revision;
    m.elyriiPrepared = [revision, 'pending'];
    m.elyriiPreparationQueue = (m.elyriiPreparationQueue || Promise.resolve()).then(async function () {
      const current = () => m.elyriiLookRevision === revision;
      if (!current()) return;
      const variant = look.variant || null;
      if ((m.variantName || null) !== variant) {
        await new Promise(resolve => {
          m.addEventListener('variant-applied', resolve, {once:true});
          m.variantName = variant;
        });
      }
      if (!current()) return;
      const appearance = {colors:look.colors, finish:look.finish};
      await (async function () {
$mascotMaterialScript
      })();
      if (!current()) return;
      m.cameraOrbit = look.orbit || 'auto auto auto';
      m.cameraTarget = look.target || 'auto auto auto';
      await m.updateComplete;
      if (!current()) return;
      if (!m.elyriiWasPresented) {
        if (initialPose) m.elyriiRestorePose(initialPose);
        else {
          m.pause();
          m.animationName = 'idle';
          await m.updateComplete;
          m.currentTime = 0;
        }
      }
      m.jumpCameraToGoal();
      m.dismissPoster();
      while (current()) {
        const wasPaused = m.paused;
        m.pause();
        const motion = m.veloursVersion;
        const rendered = scene.renderCount;
        scene.queueRender();
        do { await frame(); } while (current() && scene.renderCount === rendered);
        if (!current()) {
          if (!wasPaused && motion === m.veloursVersion) m.play();
          return;
        }
        if (motion !== m.veloursVersion) continue;
        const png = m.toDataURL('image/png');
        const pose = m.elyriiCapturePose();
        if (!wasPaused) m.play();
        m.elyriiWasPresented = true;
        m.elyriiPrepared = [revision, 'ready', png, JSON.stringify(pose)];
        return;
      }
    }).catch(function (error) {
      if (m.elyriiLookRevision === revision) {
        m.elyriiPrepared = [revision, 'error', String(error)];
      }
    });
  };
}
''';
