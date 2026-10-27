# Velours — motion direction and library

The mascot retains its material, geometry, and identity. Its personality comes
from gestures: anticipation, main action, a brief pause, and a soft return.
Feet stay fixed; elbows and wrists articulate, ears follow the head with a
100 ms delay, and eyelids close the eyes. No Flutter floating or squash effect
is added to dashboard or customization-preview gestures.

## The 16 intentions

| Clip | Duration | Intention and trigger |
| --- | ---: | --- |
| `idle` | 12 s | Two subtle breaths, occasional looks and blinks. Default presence. |
| `greet` | 3.2 s | Raised paw and wrist wave. First arrival on Home, once per MascotProvider instance. |
| `attentive` | 6.4 s | Lean and nod while composing a message. |
| `thinking` | 4.4 s | Sideways look. Chatbot wait after 400 ms; at most two loops. |
| `celebrate` | 3.4 s | Open paws and satisfaction. Celebration preview and challenge completion detected after synchronization. |
| `breathe` | 2 normalized seconds | Torso/paw pose driven by exercise progress. Never a repeating two-second loop during a session. |
| `curious` | 7.2 s | Looks both ways and tilts its head. Idle variation and interaction. |
| `cozy` | 8 s | Relaxes shoulders and closes its eyes for a long blink. Idle variation and first saved journal entry. |
| `acknowledge` | 2.6 s | Nod after a reply, neutral mood, or tap. |
| `reassure` | 4.8 s | Leans closer and gently opens a paw. Difficult mood or chat disconnection. |
| `delight` | 3.6 s | Two restrained joyful accents. Positive mood or tap. |
| `nuzzle` | 4 s | Tilts toward the user with closed eyes. Long press on Home. |
| `proud` | 3.8 s | Straightens up and looks at its outfit. Theme/accessory change in preview. |
| `stretch` | 5.6 s | Asymmetric stretch followed by release. Idle variation. |
| `settle` | 5.2 s | Long exhale and nod on entering meditation and completing a session. |
| `invite` | 3.4 s | Invitation with one paw. Invitation preview, started challenge, or accepted proposal. |

Gestures can also be inspected in a local studio without a backend connection
or changes to user data:

```sh
python3 scripts/mascot/serve_studio.py
# http://127.0.0.1:8766
```

The studio uses the engine installed by `flutter pub get`. It offers a timeline,
five breathing rhythms, pause, reduced motion, and automated playback checks.
It serves the app's GLB rather than a copy.

## Integration with user flows

`MascotProvider` exposes a small reaction queue (`react`) shared by persistent
tabs. The dashboard consumes the trigger counter and resumes the gesture when
returning to a tab: starting/accepting a challenge triggers `invite`, a new
completion triggers `celebrate`, and the first saved note triggers `cozy`.
The former Coach advice trigger was removed with that page. An event key can
deduplicate network streams; direct interactions remain replayable.

## Sequencing and accessibility

`MascotMotionController` owns pacing and interruption rules. Screens pass an
intention and an `animationTrigger` counter to replay the same gesture. An
identical notification does not restart anything. Every new context cancels
the previous timer, preventing an old celebration from interrupting listening.
After a short gesture, Velours returns to idle.

An idle variation occurs after 14–24 quiet seconds; consecutive variations
differ. They do not occur while listening or during prolonged network waits.
Taps have a 1.4-second cooldown without blocking Home bubble message changes.

Timers and playback pause when `TickerMode` disables the route or the app leaves
the foreground. Stale gestures do not replay on return. With
`MediaQuery.disableAnimations`, the model and placeholder stay still. Text
continues to convey status and breathing countdowns. Scroll visibility is not
measured here: a mascot scrolled outside the viewport still follows its route.

## Breathing

`ActiveBreathingView` shares its AnimationController with the viewer through
`breathProgress`. Inhaling goes from 0 to 1 and exhaling from 1 to 0; holds keep
an endpoint. Pause stops that same progression. Resume preserves the pose and
joins the next timer transition.

Playback seeks a pose in the first second of `breathe`, containing the full
breathing range. It sends at most 30 commands per second to the WebView, plus
endpoint poses. A model loaded mid-session joins the current progression.

## Rendering and maintenance

`MascotModelSurface` isolates access to the internal engine of the pinned
`flutter_3d_controller` **2.3.0**. The package's public widget does not expose
pose seeking. This adapter uses the same asset loading, WebView, and camera
commands as the package.

Clip changes wait for `updateComplete`, reset time explicitly, and cancel stale
JavaScript commands. This supports replay, crossfades, and suspension without
an old promise restarting playback. Check the adapter when upgrading the
package. After 12 seconds without successful loading, the PNG fallback takes over.

Accessories share a scene with the body and follow animated head/torso controls.
Material variants change outfits without reloading the scene. The catalog,
progression, and rebuilding are described in the
[Velours wardrobe guide](mascot-accessories.md). iOS recoloring retains the
existing renderer's limitations.

## Rebuilding and verification

The Python script has no external dependencies. It replaces curves in the
existing rigged GLB, compacts old data, and retains meshes, images, skins, and
materials. Two rebuilds produce exactly the same file.

```sh
python3 scripts/mascot/build_velours_motion.py
python3 scripts/mascot/check_velours_motion.py
# Optional: compare geometry with a Git revision
python3 scripts/mascot/check_velours_motion.py --compare-ref HEAD
cd elyrii_app
flutter analyze
flutter test
```

The library contains 2,404 poses sampled at 30 Hz and weighs 5,687,376 bytes,
an increase of 248,556 bytes (+4.6%) over the six-clip version. Checks cover
finite numbers, normalized quaternions, eyelid limits, shared endpoint poses,
and duration agreement with the Dart catalog. The Khronos validator reports
no errors or warnings. The studio button checks all 16 clips, completion of
three gestures, and a held breathing pose.
