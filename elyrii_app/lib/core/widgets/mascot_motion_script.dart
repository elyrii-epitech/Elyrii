/// Instance-local pose blending for flutter_3d_controller 2.3.0's bundled engine.
/// Execute after model load with the model-viewer element in `m`.
const String mascotMotionScript = r'''
(function () {
  'use strict';
  const contract = 'elyrii-motion/flutter_3d_controller-2.3.0/1';
  const loopOnce = 2200;
  const loopRepeat = 2201;
  const normalBlend = 2500;
  const linearInterpolation = 2301;

  function requireContract(condition, detail) {
    if (!condition) {
      throw new Error('Elyrii motion contract: ' + detail);
    }
  }

  function fingerprint(method) {
    const source = Function.prototype.toString.call(method);
    let hash = 2166136261;
    for (let i = 0; i < source.length; i++) {
      hash = Math.imul(hash ^ source.charCodeAt(i), 16777619);
    }
    return (hash >>> 0).toString(16).padStart(8, '0');
  }

  requireContract(m && m.loaded && typeof m.play === 'function' &&
    typeof m.pause === 'function', 'install only on a loaded model-viewer');
  const sceneSymbols = Object.getOwnPropertySymbols(m).filter(function (key) {
    return key.description === 'scene';
  });
  requireContract(sceneSymbols.length === 1, 'expected one scene symbol');
  const sceneSymbol = sceneSymbols[0];
  const scene = m[sceneSymbol];
  requireContract(scene && scene.element === m && scene._currentGLTF &&
    scene.mixer && Array.isArray(scene.animations), 'missing loaded scene');
  const mixer = scene.mixer;
  const clips = scene.animations;
  const installed = scene.elyriiMotionBridge;
  if (installed) {
    requireContract(installed.contract === contract &&
      installed.clips === clips && installed.model === scene._currentGLTF &&
      scene.playAnimation === installed.playAnimation &&
      m.elyriiPlay === installed.play, 'installed bridge was replaced or model changed');
    return;
  }

  requireContract(!m.elyriiPlay && typeof scene.playAnimation === 'function' &&
    typeof scene.updateAnimation === 'function' &&
    typeof scene.queueRender === 'function' &&
    typeof mixer.clipAction === 'function' &&
    typeof mixer.stopAllAction === 'function' &&
    scene.animationsByName instanceof Map, 'missing pinned animation API');
  requireContract(fingerprint(scene.playAnimation) === 'e6e077dd' &&
    fingerprint(mixer.clipAction) === '9c526660' &&
    fingerprint(mixer.stopAllAction) === '0cc0c3e5' &&
    fingerprint(m.play) === '1afb1c92', 'bundled renderer differs from the pinned engine');

  const idleClip = scene.animationsByName.get('idle');
  requireContract(idleClip && Array.isArray(idleClip.tracks) &&
    idleClip.tracks.length > 0, 'missing canonical idle tracks');
  const referenceTracks = idleClip.tracks;
  const trackShape = referenceTracks.map(function (track) {
    requireContract(typeof track.getValueSize === 'function', 'missing track size');
    const size = track.getValueSize();
    requireContract(Number.isSafeInteger(size) && size > 0, 'invalid track size');
    return [track.name, track.ValueTypeName, size];
  });
  const actions = new Map();
  requireContract(clips.length > 0, 'missing authored clips');
  for (let i = 0; i < clips.length; i++) {
    const clip = clips[i];
    requireContract(scene.animationsByName.get(clip.name) === clip &&
      clip.blendMode === normalBlend && Number.isFinite(clip.duration) &&
      clip.duration > 0 && Array.isArray(clip.tracks) &&
      clip.tracks.length === trackShape.length, 'unexpected clip ' + clip.name);
    for (let j = 0; j < trackShape.length; j++) {
      const track = clip.tracks[j];
      const shape = trackShape[j];
      requireContract(track.name === shape[0] && track.ValueTypeName === shape[1] &&
        typeof track.getValueSize === 'function' && track.getValueSize() === shape[2] &&
        typeof track.getInterpolation === 'function' &&
        track.getInterpolation() === linearInterpolation &&
        track.times instanceof Float32Array && track.times.length > 0 &&
        track.values instanceof Float32Array &&
        track.values.length === track.times.length * shape[2] &&
        track.constructor === referenceTracks[j].constructor,
        'unexpected track shape in ' + clip.name + ' at ' + j);
    }
    const action = mixer.clipAction(clip, scene);
    requireContract(action && typeof action.getClip === 'function' && action.getClip() === clip &&
      Array.isArray(action._propertyBindings) &&
      action._propertyBindings.length === trackShape.length &&
      typeof action.reset === 'function' && fingerprint(action.reset) === '75417c83' &&
      typeof action.play === 'function' && typeof action.setLoop === 'function' &&
      typeof action.setEffectiveWeight === 'function' &&
      typeof action.setEffectiveTimeScale === 'function' &&
      typeof action.crossFadeFrom === 'function', 'unexpected action for ' + clip.name);
    actions.set(clip.name, action);
  }

  const poseTracks = new Array(trackShape.length);
  const bindings = new Array(trackShape.length);
  const idleAction = actions.get('idle');
  for (let i = 0; i < trackShape.length; i++) {
    const sourceTrack = referenceTracks[i];
    const track = new sourceTrack.constructor(sourceTrack.name,
      new Float32Array([0]), new Float32Array(trackShape[i][2]), linearInterpolation);
    const propertyMixer = idleAction._propertyBindings[i];
    const binding = propertyMixer && propertyMixer.binding;
    requireContract(binding && typeof binding.bind === 'function' &&
      typeof binding.getValue === 'function', 'missing binding for ' + track.name);
    binding.bind();
    track.values.fill(NaN);
    binding.getValue(track.values, 0);
    for (let j = 0; j < track.values.length; j++) {
      requireContract(Number.isFinite(track.values[j]), 'unresolved binding for ' + track.name);
    }
    poseTracks[i] = track;
    bindings[i] = binding;
  }
  const poseClip = new idleClip.constructor('__elyrii_composite_pose', 1, poseTracks, normalBlend);
  const poseAction = mixer.clipAction(poseClip, scene);
  requireContract(poseAction && Array.isArray(poseAction._interpolants) &&
    poseAction._interpolants.length === poseTracks.length &&
    Array.isArray(poseAction._propertyBindings) &&
    poseAction._propertyBindings.length === poseTracks.length,
    'missing snapshot interpolants');
  for (let i = 0; i < poseTracks.length; i++) {
    requireContract(poseAction._interpolants[i] &&
      poseAction._interpolants[i].sampleValues === poseTracks[i].values &&
      poseAction._propertyBindings[i] && poseAction._propertyBindings[i].binding === bindings[i],
      'snapshot does not share the validated binding buffers');
  }

  const originalPlay = scene.playAnimation;
  const state = {
    contract: contract,
    clips: clips,
    model: scene._currentGLTF,
    sequence: 0,
    command: null,
    play: null,
    playAnimation: null
  };

  function requireScene() {
    requireContract(m[sceneSymbol] === scene && scene.animations === clips &&
      scene._currentGLTF === state.model && scene.mixer === mixer,
      'model changed after bridge installation');
  }

  function isCurrent(command) {
    return state.command === command && m.veloursVersion === command.version;
  }

  function start(command, duration) {
    requireContract(Number.isFinite(duration) && duration > 0,
      'animationCrossfadeDuration must be positive');
    /* Capture the evaluated composite before stopAllAction restores bind values. */
    for (let i = 0; i < bindings.length; i++) {
      bindings[i].getValue(poseTracks[i].values, 0);
    }
    mixer.stopAllAction();
    poseAction.reset();
    poseAction.setLoop(loopRepeat, Infinity);
    poseAction.setEffectiveTimeScale(1);
    poseAction.setEffectiveWeight(1);
    poseAction.clampWhenFinished = false;
    poseAction.play();
    poseAction.paused = true;

    const target = command.action;
    target.reset();
    target.setLoop(command.loop, command.repetitions);
    target.setEffectiveTimeScale(1);
    target.setEffectiveWeight(1);
    target.clampWhenFinished = true;
    target.play();
    target.crossFadeFrom(poseAction, duration, false);
    scene.currentAnimationAction = target;
    command.applied = true;
    /* Reapply synchronously. The next renderer frame must never see bind pose. */
    scene.updateAnimation(0);
    scene.queueRender();
  }

  state.playAnimation = function (name, duration, loop, repetitions) {
    requireScene();
    const selectedName = name == null ? clips[0].name : name;
    requireContract(actions.has(selectedName), 'unknown animation ' + selectedName);
    const command = state.command;
    if (command && command.name === selectedName) {
      if (!isCurrent(command)) return;
      if (!command.applied) start(command, duration);
      /* updated() supplies default Infinity after play(). Keep this command's mode. */
      return;
    }
    /* Public paused selections and intentional seeks remain owned by the caller. */
    state.command = null;
    return originalPlay.call(scene, name, duration, loop, repetitions);
  };

  state.play = function (name, repetitions) {
    requireScene();
    requireContract(typeof name === 'string' && actions.has(name), 'unknown animation ' + name);
    if (repetitions === undefined) repetitions = Infinity;
    requireContract(repetitions === Infinity ||
      (Number.isSafeInteger(repetitions) && repetitions > 0),
      'repetitions must be a positive integer or Infinity');
    requireContract(Number.isFinite(m.animationCrossfadeDuration) &&
      m.animationCrossfadeDuration > 0, 'animationCrossfadeDuration must be positive');
    const command = {
      id: ++state.sequence,
      version: m.veloursVersion,
      name: name,
      repetitions: repetitions,
      loop: repetitions === 1 ? loopOnce : loopRepeat,
      action: actions.get(name),
      applied: false
    };
    state.command = command;
    m.animationName = name;
    /* play() is also required for same-name replays, which never reach updated(). */
    m.play({repetitions: repetitions});
    requireContract(command.applied, 'public play did not select the requested action');
    return command.id;
  };

  m.elyriiCapturePose = function () {
    requireScene();
    return bindings.map(function (binding, i) {
      const values = new Array(trackShape[i][2]);
      binding.getValue(values, 0);
      return values;
    });
  };

  m.elyriiRestorePose = function (pose) {
    requireScene();
    requireContract(Array.isArray(pose) && pose.length === poseTracks.length,
      'cached pose has different channels');
    for (let i = 0; i < poseTracks.length; i++) {
      requireContract(Array.isArray(pose[i]) &&
        pose[i].length === poseTracks[i].values.length &&
        pose[i].every(Number.isFinite), 'invalid cached pose channel');
    }
    m.pause();
    state.command = null;
    mixer.stopAllAction();
    for (let i = 0; i < poseTracks.length; i++) {
      poseTracks[i].values.set(pose[i]);
    }
    poseAction.reset();
    poseAction.setLoop(loopRepeat, Infinity);
    poseAction.setEffectiveWeight(1);
    poseAction.play();
    poseAction.paused = true;
    scene.currentAnimationAction = poseAction;
    scene.updateAnimation(0);
    scene.queueRender();
  };

  scene.playAnimation = state.playAnimation;
  m.elyriiPlay = state.play;
  scene.elyriiMotionBridge = state;
})();
''';
