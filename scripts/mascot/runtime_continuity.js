function sceneOf(m) {
  const key = Object.getOwnPropertySymbols(m).find(s => s.description === 'scene');
  const scene = m[key];
  if (!scene?.mixer || !scene.animationsByName?.get('idle')) throw new Error('Pinned renderer scene is unavailable');
  return scene;
}

function poseOf(scene) {
  return scene.animationsByName.get('idle').tracks.map(track => {
    const dot = track.name.lastIndexOf('.');
    const node = scene.getObjectByName(track.name.slice(0, dot));
    const value = node?.[track.name.slice(dot + 1)];
    if (!value) throw new Error('Unresolved pose channel ' + track.name);
    return {name:track.name, type:track.ValueTypeName,
      values:value.toArray ? value.toArray() : Array.from(value)};
  });
}

function difference(a, b) {
  let angle = 0, component = 0;
  for (let i = 0; i < a.length; i++) {
    if (a[i].name !== b[i].name) throw new Error('Pose channel order changed');
    const x = a[i].values, y = b[i].values;
    if (a[i].type === 'quaternion') {
      const norm = Math.hypot(...x) * Math.hypot(...y);
      const dot = Math.abs(x.reduce((sum, v, j) => sum + v*y[j], 0) / norm);
      angle = Math.max(angle, 2*Math.acos(Math.min(1, dot)));
    } else {
      component = Math.max(component, ...x.map((v,j) => Math.abs(v-y[j])));
    }
  }
  return {angleRadians:angle, maxComponent:component};
}

const frame = () => new Promise(resolve => requestAnimationFrame(resolve));
async function advance(milliseconds) {
  const start = performance.now();
  while (performance.now()-start < milliseconds) await frame();
}
function require(ok, message) { if (!ok) throw new Error(message); }
function continuous(delta, label) {
  require(delta.angleRadians < 0.00001 && delta.maxComponent < 0.000001,
    label + ' has a discontinuous pose ' + JSON.stringify(delta));
}

export async function verifyContinuity(m, install) {
  require(m.loaded, 'Model must be loaded before verification');
  const scene = sceneOf(m), original = scene.playAnimation;
  m.animationCrossfadeDuration = 320;
  install(m);
  const bridged = scene.playAnimation;
  const results = {kind:'pose continuity, not latency or device performance', trials:[], transitions:[]};
  for (const phase of [2, 4.3, 6.2, 8, 9.4]) {
    for (const side of ['before', 'after']) {
      scene.playAnimation = original;
      m.pause(); m.animationName = 'idle';
      await m.updateComplete;
      m.currentTime = phase;
      const before = poseOf(scene);
      if (side === 'before') {
        m.pause(); m.animationName = ''; m.animationName = 'curious';
        await m.updateComplete;
        m.currentTime = 0; m.play({repetitions:1});
      } else {
        scene.playAnimation = bridged;
        m.veloursVersion = (m.veloursVersion || 0) + 1;
        m.elyriiPlay('curious', 1);
      }
      const after = poseOf(scene), delta = difference(before, after);
      results.trials.push({phase,side,delta,before,after});
      if (side === 'after') continuous(delta, 'idle to curious');
      await advance(120);
      if (side === 'after') require(scene.currentAnimationAction.time > .05,
        'Target animation did not advance');
      m.pause();
    }
  }
  require(results.trials.filter(t => t.side === 'before').every(t =>
    t.delta.angleRadians > .001 || t.delta.maxComponent > .001),
    'Known-bad reset did not reproduce; comparison is inconclusive');
  scene.playAnimation = bridged;
  const play = name => {
    const before = poseOf(scene);
    m.veloursVersion = (m.veloursVersion || 0) + 1;
    m.elyriiPlay(name, name === 'idle' ? Infinity : 1);
    const delta = difference(before, poseOf(scene));
    continuous(delta, name);
    results.transitions.push({name,delta});
  };
  play('greet');
  await advance(500);
  play('greet');
  require(scene.currentAnimationAction.time < .001, 'Same clip was not restarted');
  let previous = 0;
  for (let i = 0; i < 8; i++) {
    await frame();
    const time = scene.currentAnimationAction.time;
    require(time >= previous, 'Delayed renderer callback restarted the target');
    previous = time;
  }
  for (const delay of [120,260]) {
    play('curious'); await advance(delay);
    play('delight'); await advance(delay);
    play('curious'); await advance(delay);
  }
  const paused = poseOf(scene), time = scene.currentAnimationAction.time;
  m.pause(); await advance(80); m.play({repetitions:1});
  continuous(difference(paused, poseOf(scene)), 'pause resume');
  require(Math.abs(time-scene.currentAnimationAction.time) < .001, 'Resume reset the target clock');
  m.pause(); m.animationName = 'breathe'; await m.updateComplete;
  m.currentTime = .7;
  play('idle'); await advance(400);
  play('acknowledge');
  await new Promise((resolve,reject) => {
    const timeout = setTimeout(() => {m.removeEventListener('finished', done);reject(new Error('One-shot never finished'));}, 4000);
    function done() {clearTimeout(timeout);m.removeEventListener('finished', done);resolve();}
    m.addEventListener('finished', done);
  });
  require(scene.currentAnimationAction.time >= 2.59, 'One-shot finished prematurely');
  m.pause();
  results.passed = true;
  return results;
}
