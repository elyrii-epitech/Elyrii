// Import from /runtime_wardrobe.js after starting serve_studio.py, then call
// verifyWardrobe(document.querySelector('model-viewer')) on /wardrobe.
// Checks evaluated renderer materials, rather than only GLB variant metadata.
const frame = () => new Promise(resolve => requestAnimationFrame(resolve));

function require(ok, message) {
  if (!ok) throw new Error('Wardrobe regression: ' + message);
}

function sceneOf(m) {
  const keys = Object.getOwnPropertySymbols(m).filter(key => key.description === 'scene');
  require(keys.length === 1, 'expected one pinned renderer scene');
  const scene = m[keys[0]];
  require(scene?.element === m && typeof scene.traverse === 'function',
    'pinned renderer scene is unavailable');
  return scene;
}

async function selectVariant(m, variant) {
  if ((m.variantName || null) === variant) {
    await m.updateComplete;
    return;
  }
  await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      m.removeEventListener('variant-applied', applied);
      reject(new Error('Wardrobe variant was not applied: ' + variant));
    }, 10000);
    function applied() {
      if ((m.variantName || null) !== variant) return;
      clearTimeout(timeout);
      m.removeEventListener('variant-applied', applied);
      resolve();
    }
    m.addEventListener('variant-applied', applied);
    m.variantName = variant;
  });
}

function visibleAccessories(scene) {
  const visible = [];
  scene.traverse(attachment => {
    if (!attachment.name.startsWith('Accessory_')) return;
    let shown = false;
    attachment.traverse(mesh => {
      if (!mesh.isMesh) return;
      let node = mesh;
      while (node) {
        if (!node.visible) return;
        node = node.parent;
      }
      for (const material of [mesh.material].flat()) {
        require(material?.isMaterial && Number.isFinite(material.opacity) &&
          Number.isFinite(material.alphaTest), 'unexpected accessory material');
        // These authored accessories use solid materials. Refuse a textured
        // alpha mask rather than claiming that opacity alone proves visibility.
        require(!material.map && !material.alphaMap, 'accessory alpha needs pixel verification');
        if (material.visible && material.opacity >= material.alphaTest &&
            (!material.transparent || material.opacity > 0)) shown = true;
      }
    });
    if (shown) visible.push(attachment.name.slice('Accessory_'.length));
  });
  return visible.sort();
}

export async function verifyWardrobe(m) {
  require(m?.loaded, 'model must be loaded before verification');
  const scene = sceneOf(m);
  const variants = Array.from(m.availableVariants);
  require(variants.length > 0 && new Set(variants).size === variants.length,
    'expected unique wardrobe variants');
  const attachments = [];
  scene.traverse(node => {
    if (node.name.startsWith('Accessory_')) attachments.push(node.name.slice('Accessory_'.length));
  });
  require(attachments.length > 0 && new Set(attachments).size === attachments.length,
    'expected unique accessory attachments');
  for (const variant of variants) {
    require(variant.split('+').every(id => attachments.includes(id)),
      'variant refers to a missing attachment: ' + variant);
  }
  const originalVariant = m.variantName || null;
  const wasPaused = m.paused;
  const results = {kind:'evaluated wardrobe materials, not a device screenshot',
    variants:variants.length, transitions:[]};
  m.pause();
  // Let the model's initial variant update finish before listening for changes.
  await m.updateComplete;
  await frame();
  const check = async (variant, label) => {
    await selectVariant(m, variant);
    const expected = variant ? variant.split('+').sort() : [];
    const visible = visibleAccessories(scene);
    results.transitions.push({label, variant, expected, visible});
    require(JSON.stringify(visible) === JSON.stringify(expected),
      label + ': expected ' + JSON.stringify(expected) + ', visible ' + JSON.stringify(visible));
  };
  try {
    await check(null, 'bare');
    // Replacements in one slot, removals from multi-piece outfits, and a bare
    // bear between identical selections exercise user actions explicitly.
    const actions = ['beret', 'beanie', 'beanie+round_glasses+cozy_scarf+mini_backpack',
      'beanie+cozy_scarf+mini_backpack', 'cozy_scarf', null, 'cozy_scarf', null, null];
    for (const [index, variant] of actions.entries()) {
      require(variant === null || variants.includes(variant), 'missing action fixture ' + variant);
      await check(variant, 'action ' + index);
    }
    for (const [index, variant] of variants.entries()) await check(variant, 'forward ' + index);
    for (const [index, variant] of [...variants].reverse().entries()) await check(variant, 'reverse ' + index);
    await check(null, 'final removal');
    results.passed = true;
    return results;
  } finally {
    await selectVariant(m, originalVariant);
    if (!wasPaused) m.play();
  }
}
