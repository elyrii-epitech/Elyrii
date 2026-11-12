# Elyrii outfits and collection

The collection starts from the actual 3D bear: a very large round head, large
pink ears, plum eyes, white muzzle/belly, and matte cream material. Pieces use
rounded volumes and a sage, pink, lavender, cream, and soft gold palette.
Open glasses preserve its gaze; only the sleep mask intentionally covers its
eyes. The small backpack is visible from behind.

## Collection and progression

The shared `MascotAccessories` catalog defines names, categories, and thresholds.
Every completed challenge counts; active challenges unlock nothing. An outfit
combines one piece per zone: Head, Face, Neck, and Back. Selecting another piece
replaces only that zone; selecting the equipped piece removes it. The 15 pieces
allow 320 outfits, including the bear without accessories.

| Piece | ID | Completed challenges |
| --- | --- | ---: |
| Graduation cap | `graduate_cap` | 1 |
| Sage beret | `beret` | 2 |
| Cozy beanie | `beanie` | 3 |
| Laurel crown | `laurel_crown` | 3 |
| Celestial sparkle | `cheek_sparkle` | 4 |
| Flower crown | `flower_crown` | 5 |
| Star crown | `star_crown` | 7 |
| Moon pin | `moon_pin` | 9 |
| Round glasses | `round_glasses` | 12 |
| Pastel headphones | `headphones` | 15 |
| Sleep mask | `sleep_mask` | 18 |
| Cozy scarf | `cozy_scarf` | 22 |
| Bow tie | `bow_tie` | 26 |
| Leaf pendant | `leaf_pendant` | 30 |
| Mini backpack | `mini_backpack` | 36 |

The dressing room opens from the outfit action in Home's capsule. The
accessories tab filters portraits by Head, Face, Neck, and Back. A locked piece
shows its threshold and explains the remaining challenges without changing the
preview. Progression stays unavailable until challenges load.

`MascotProvider` checks new equipment when saving. An already equipped,
restored piece can still be removed when progression is unavailable. This
check remains client-side; the server adds no inventory system. Existing
thresholds are preserved.

## Dressing room and saving

The dressing room shares Home's 3D model. Color, accessory, and scene tabs scroll
beneath a preview that stays mounted. Closing discards the draft. Saving writes
the outfit, then the local scene. If the scene write fails, the dressing room
restores the previous outfit and stays open with an error.

The eight palettes in `MascotThemes.all` recolor model materials. Velvet, Satin,
and Porcelain finishes adjust rendering. Free colors in an existing outfit
remain until a palette is selected. Restoring the original look resets the
default model in the draft.

Arches, Hills, and Waves scenes are immediately available. Clearing requires
ten completed challenges. Hills shows dawn in light mode. `AccueilActivities`
encrypts the scene in an account-specific document. It is not sent to the
server, which does not recognize that field.

Local saves use `elyrii_mascot_theme_<userId>`,
`elyrii_mascot_customization_<userId>`, and `elyrii_mascot_appearance_<userId>`.
Demo and visitor sessions use their own `demo` and `guest` suffixes. A restored
session can migrate legacy global keys once; `elyrii_mascot_legacy_owner`
prevents another account from inheriting them. Legacy Lucas accessory IDs are
normalized without losing the outfit. A cache from his local studio synchronizes
before reading a possible default server look;
`elyrii_mascot_schema_version_<userId>` marks this migration. The old workshop
screen and `/mascot-customization` route are removed. The server stores colors
and finish in `personality.customization`, validated by
`modules/user/mascot.validation.ts`. The existing merge preserves other
personality traits.

Server writes are sequential. On network failure, the look stays saved on the
device; `elyrii_mascot_pending_sync_<userId>` prevents stale server state from
replacing it on reopening. The UI offers synchronization retry, also attempted
on loading.

Session changes invalidate the previous account's pending loads, drafts, and
synchronizations. Challenge progression and dashboard statistics reset; the
dashboard cache is also account-scoped. Demo mode provides local progression
without changing real progression or sending choices to the server.

## Integrating Lucas's work

Source: `origin/feature/lucas-debize/mascott-customisation-color-accessory`,
commits `cdc5ece` and `37bd94d`, reviewed at tip `1b6e6c2`. The integration
includes Spirits, preference isolation, equipped-zone indicators, and three
distinctive models: graduation cap, laurel crown, and glowing sparkle.
Equivalent accessories map to catalog pieces through aliases. The sparkle is
reduced and moved to the cheek to preserve the gaze; the laurel is simplified
for the mobile budget, with normals adapted to flattened leaves.

The dressing room retains finishes, a persistent preview, and multi-zone
outfits. Rendering uses model-viewer's public API and one animated model.
Free colors and the old workshop's undo history are no longer presented as controls.

## Models and rendering

The 15 `assets/accessories/*.glb` files are standalone pieces.
`scripts/mascot/build_accessories.py` creates the 12 studio pieces;
`scripts/mascot/build_lucas_accessories.py` rebuilds the three adapted Lucas
pieces. `scripts/mascot/accessories.json` describes their anchors. These working
files are not individually bundled into Flutter.

`tool/mascot/build_wardrobe.mjs` combines one copy of the optimized body and all
15 pieces into `assets/optimized/mascot_wardrobe.glb`. Headwear/face accessories
follow `CTRL_head`; neck/back pieces follow `CTRL_chest`. Global coordinates
are converted into the parent's frame to preserve rest alignment; adapted
pieces use an explicit `CTRL_head` local offset. Both skins and all 16 mascot
animations are retained.

The assembled wardrobe weighs 3,778,356 bytes and contains 81,302 triangles,
including hidden accessories. The most detailed visible outfit has 69,800 triangles.

Accessory materials are transparent in MASK mode by default. The 319
`KHR_materials_variants` restore materials for equipped pieces. Names join IDs
in zone order with `+`, for example
`beret+round_glasses+cozy_scarf+mini_backpack`. Model-viewer's public `variantName`
API selects the outfit; `null` restores the bare bear. The same scene and
animation continue during changes. See the
[official model-viewer examples](https://modelviewer.dev/examples/scenegraph/#variants).

`mascot_material_script.dart` recolors materials through the renderer's public
API. It preserves the painted atlas, nose, and eye highlights; cheeks and ears
can be recolored separately. Sparkle retains its light emission after color
customization. Linear RGB-to-sRGB conversion preserves the atlas color on read.
Three reusable canvas textures limit memory during adjustments. Finishes tune
roughness, normal strength, and clearcoat, whose extension is included in the
assembled model. The local review tool uses the same bundled model-viewer
script as native platforms. Home's dressing room retains the shared viewer's
adaptive quality.

### Presence during loading

A PNG of the actual bear replaces the loading disc/spinner. The 3D scene remains
mounted behind it and becomes visible after outfit, material, and framing
application and receipt of a rendered frame. Motion starts after the fade,
without an arbitrary stabilization delay.

The cache retains at most six images within 3 MiB. Its key includes account,
model, framing, and resolved appearance. Each image retains its pose to prepare
the next scene identically. Account deletion purges its images and invalidates
late writes. Without an image matching the look, the original bear stays visible
during preparation; this fallback does not guarantee custom colors/accessories.

`mascot_motion_script.dart` adapts only animation blending in the pinned
`flutter_3d_controller 2.3.0` renderer. It captures the composite pose before
resetting the target. Repeats and interruptions start from that pose without
resetting the global clock. Pauses between gestures remain 10–15 seconds.
Offscreen players suspend and release according to existing retention rules.

`scripts/mascot/serve_studio.py` exposes `/poster` to regenerate the PNG and
`runtime_continuity.js` to verify transitions in the shipped engine. Model or
rendering changes require regenerating the poster and changing the key revision
in `MascotPosterStore`.

## Rebuilding and verification

```sh
blender --background --python scripts/mascot/build_accessories.py
python3 scripts/mascot/build_lucas_accessories.py
cd elyrii_app/tool/mascot
npm ci
npm run build:wardrobe
# npm run build also rebuilds the optimized body.
```

To generate portraits and their contact sheet (Pillow is used for assembly):

```sh
blender --background --python scripts/mascot/build_accessories.py -- --preview
blender --background --python scripts/mascot/render_lucas_portraits.py
python3 scripts/mascot/render_accessory_contact_sheet.py
```

To inspect pieces from the front, three-quarter angle, and back using the
engine actually used in the app:

```sh
python3 scripts/mascot/serve_studio.py
# http://127.0.0.1:8766/wardrobe
```

The app demo opens the dressing room from Home. The old
`preview_mascot_studio.dart` tool was removed with the workshop. Shipped portraits
are in `elyrii_app/assets/accessory_portraits/`. Review images generated in
`scripts/mascot/previews/` stay local.

`test/dashboard_mood_system_test.dart` covers canceling, previewing, and saving
outfits/scenes. Provider tests cover offline restoration, sessions, and
synchronization ordering. Local activity tests cover the Clearing lock and
account-scoped persistence. Asset tests verify model variants.
