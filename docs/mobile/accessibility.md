# Mobile accessibility

Validation method for the iOS/Android app and shared components. Automated
matrices live in `elyrii_app/test/frontend/`; results are regenerated in
`elyrii_app/build/a11y-evidence/` and published by CI.

## Target and evidence level

The technical target is **WCAG 2.2 Level AA**, accounting for native interfaces.
RGAA 4.1.2 guides questions about images, contrast, forms, scripts, and navigation;
it applies to the web and cannot alone qualify a native app. For contracts
requiring EN 301 549, software and assistive technology requirements must also
be assessed against the contractual version. References are
[WCAG 2.2](https://www.w3.org/TR/WCAG22/),
[WCAG2ICT](https://www.w3.org/TR/wcag2ict/), and
[RGAA](https://accessibilite.numerique.gouv.fr/methode/).

The tests below provide focused, reproducible evidence. They do not cover all
content, network states, OS settings, or native components. No TalkBack,
VoiceOver, Switch Control, or 3D WebView screen reader result is claimed without
execution on that platform.

## Automated measurements

Poppins Regular/Medium/SemiBold/Bold and icon fonts are actually loaded.
Screenshots use French fixtures and a demo session; the 3D WebView and native
plugins are replaced with test adapters.

The 15 screens are login, registration, password recovery, dashboard, challenges,
journal, chat, journeys, meditation, mascot, settings, review, profile setup,
profile editing, and avatar selection.

| Configuration | Logical-point size | Text scale | Theme |
| --- | --- | --- | --- |
| Mobile | 390 × 844 | 100% | Light |
| Small screen / very large text | 320 × 568 | 300% | Light |
| Landscape | 568 × 320 | 200% | Light |
| Very narrow | 280 × 568 | 200% | Light |
| Small screen | 320 × 568 | 200% | Light |
| Dark / large text | 390 × 844 | 200% | Dark |
| Landscape tablet | 1024 × 768 | 100% | Light |

**105 renders** are recorded; every Flutter exception fails the test. No overflow
is ignored to obtain a passing result. Linear text scaling does not replace
nonlinear OS settings; large text with the software keyboard open still needs
device testing. A successful render alone does not establish that every control
is reachable; interaction tests and manual flows complement it.

The semantics matrix covers **60 states**: 15 screens × two themes × top/bottom
after scrolling. Each state checks touch-target names, Android 48 × 48 size,
iOS 44 × 44 size, and rendered text contrast, producing **240 results**.
Shared action surfaces are at least 48 × 48 on both systems. WCAG 2.5.8's
threshold, exceptions, and native geometry still require contextual evaluation.

Flutter 3.47's size helper compares some transformed child bounds against the
scrolling parent's local rectangle. A SafeArea translation can misclassify a
partially clipped target as fully visible and undersized. The 30 top states use
standard helpers. For the 30 bottom states, only exclusion of targets clipped
at scroll boundaries is corrected into the parent's coordinate space; fully
visible target sizing remains the SDK's calculation. A negative test with a
**fully visible 44 × 44 target** under SafeArea proves that Android checks still
reject it. Name and contrast helpers remain the SDK's in every state.

Sources: [render matrix](https://github.com/elyrii-epitech/Elyrii/blob/frontend/elyrii_app/test/frontend/accessibility_matrix_test.dart),
[semantics matrix](https://github.com/elyrii-epitech/Elyrii/blob/frontend/elyrii_app/test/frontend/semantics_matrix_test.dart), and
[interactions](https://github.com/elyrii-epitech/Elyrii/blob/frontend/elyrii_app/test/frontend/accessibility_interactions_test.dart).

## Shared component changes

| Area | Expected behavior | Automated evidence |
| --- | --- | --- |
| Forms | Persistent labels, distinct hints, associated errors, email/password manager hints, announced visibility toggle, paste allowed. | Autofill, semantic name, error, and toggle properties; 300% renders. |
| Actions | Names, roles, enabled/selected/loading states exposed; Enter/Space activate; disabled actions inert; card metadata/sub-actions retained. | Keyboard and semantics tests, including a reporting sub-action. |
| Focus | Two contrasting rings expose focus on custom cards/buttons. | Style inspection and keyboard activation; contrast on all native surfaces still needs manual checks. |
| Contrast | Theme-aware status text, identifiable borders, opaque filled buttons, no reduced text opacity during press. | Raster contrast in visible states and palette ratios ≥ 4.5:1 on page/card backgrounds in both themes; non-text boundaries normally require ≥ 3:1. |
| Enlargement | Titles/text retain requested scale, columns reflow, headers scroll, dialog actions remain reachable, mascot editing stays accessible. | 105 renders; long dialog, chart alternatives, and AI reporting at 300%. |
| Navigation | Named targets and selection; native menu provides all six destinations at narrow widths or enlarged text. | Touch access to six destinations at 300%, keyboard opening/Escape dismissal, normal-size navigation tests. |
| Page titles | One semantic tab heading during large-title/bar transition; fixed chat title stays accessible. | Targeted tests at 320 points and 150% text at rest, around the transition, after scrolling, and on return; heading role and full label checked. |
| Charts | Mood data has an expandable text alternative; distribution/activity expose values and context. | Nonempty chart test, exact date/count reading, opening at 300% without errors; independent of color alone. |
| Choices | Native checkboxes, switches, radios, and segments retain semantic states. | Selection, target names/sizes; report reason selection and announced acknowledgement. |
| Dialogs | Title/route announced, focus requested, readable scrolling actions, Escape dismissal, animations removed when requested. | Long dialog at 300% with keyboard dismissal; screen reader focus restoration still needs checking. |
| Motion | Decorative animations disabled/shortened according to preferences; focus does not change screens. | Existing reduced-motion and component regression tests; native WebGL still needs verification. |

Logical points are Flutter coordinates, not PNG pixels. Raster contrast measures
actually visible fixture content; it does not automatically cover all avatars,
photos, empty/error states, or user-created colors.

Pages use bounded scrolling without bounce or pull-to-refresh. Content shorter
than the screen stays still. Loading on open/app resume retains its existing
behavior. Journeys offers explicit retry after local storage errors. Header
tests check that gestures at either end do not move content beyond its bounds
in tab and detail frames.

Sheets/dialogs use opaque v2 surfaces. Sheets touch the screen bottom, with
square lower corners and the safe area inside. On wide screens, their width
matches the content column. Home's calendar remains anchored to the top bar.
A downward drag follows the finger and closes after a quarter of the sheet's
height or a fast swipe; shorter drags return. Content can start this gesture
only at the top of its scroll range. The handle/header work independently of
scrolling. Dismissal vetoes are respected. Reduced motion retains finger
tracking and makes the return instant. Drag dismissal discards the previewed
outfit like the close button, without saving.

## Criterion traceability

Partial automated evidence demonstrates only part of a criterion; manual
validation remains outstanding. Non-applicability must be justified against
the shipped content rather than assumed.

| WCAG criterion | Evidence / change | Remaining validation |
| --- | --- | --- |
| 1.1.1 Non-text content | Named action icons, excluded decorative images, chart text alternatives. | Profile photos, 3D mascot, all resource states, native affordances. |
| 1.2.1–1.2.5 Media | Assess against the meditation catalog and actually distributed media. | Inventory audio/video, text equivalents, captions, and audio description as appropriate; widgets alone do not establish compliance. |
| 1.3.1 / 1.3.2 Relationships/order | Native fields, semantic headings, retained card values, readable charts. | Complete TalkBack/VoiceOver reading order, reflow order, lists, WebView components. |
| 1.3.5 Input purpose | Autofill hints on identity/password fields. | Actual filling with iOS/Android password managers. |
| 1.4.1 Color | State text, mood quantities/percentages, text alternatives. | No functional state conveyed by color alone, including user data. |
| 1.4.3 / 1.4.11 Contrast | Normal text ≥ 4.5:1, large text per SDK helper; stronger borders/focus. | Variable photos/backgrounds, pressed/error/focus states on devices, native glass rendering. |
| 1.4.4 / 1.4.10 Resize/reflow | Matrix up to 300%, small screens, landscape, adaptive navigation. | Nonlinear OS text, open keyboard, split screen, native modals. |
| 2.1.1 / 2.1.2 Keyboard | Enter/Space, native controls, Escape dismissal. | Full Tab/Shift-Tab flows and no traps in WebView, gallery/cropper, or meditation player. |
| 2.2.1 Timing | These changes introduce no interaction deadline. | Review existing timeouts; the 15-minute session remains unchanged at the user's request, without a compliance conclusion. |
| 2.3.1 Flashes | No new flashing added. | Review all session animations/content; confirm absence of hazardous flashes. |
| 2.4.3 / 2.4.6 Order/headings/labels | Explicit headings, native labels, named destinations. | Actual keyboard/screen reader order and arrival on new routes. |
| 2.4.7 / 2.4.11 Focus visibility/obscuration | Rings, scrolling header, safe areas. | Focus not hidden by dock, keyboard, banners, or sheets in each real flow. |
| 2.5.1 / 2.5.7 Gestures/dragging | Primary actions available through named controls. | Alternatives for 3D gestures, sliders, cropping, and native drag-and-drop where applicable. |
| 2.5.3 / 2.5.8 Names/target size | Consistent labels, shared targets ≥ 48, SDK checks across 60 states. | Voice commands using visible text, spacing, native geometry. |
| 3.1.1 Language | French alone declared in Flutter; French dates/text. | Language actually passed to screen readers/system components under phone language settings. |
| 3.2.1 / 3.2.2 Predictability | Focus without implicit activation; explicit actions. | Selection-related context changes and device back navigation. |
| 3.3.1 / 3.3.2 Errors/instructions | Associated errors, persistent labels, accurate save status. | Automatic error reading, focus on affected fields, lossless retry. |
| 3.3.8 Accessible authentication | Paste/autofill allowed, no new puzzle; recovery code can be copied. | Real managers, voice input, pasted codes. Activation/refresh are outside scope. |
| 4.1.2 / 4.1.3 Names/states/messages | Native controls, exposed loading/report acknowledgement, live-region status. | Actual announcements, priority, no unwanted repetitions in TalkBack/VoiceOver. |

Reduced motion, including WCAG 2.3.3 at Level AAA, improves the experience beyond
the AA target. It does not justify an overall AAA compliance claim.

## Evaluation flows

Use a staging account and fictitious data. Test at least one iPhone with
VoiceOver and one Android with TalkBack, in light/dark themes, at maximum text
size, in portrait then landscape. Record model, OS/app/build version,
accessibility settings, result, screenshot/recording, and issue number.
**These native accessibility checks have not run in this Linux environment.**

| Flow | Procedure | Expected result | Native status |
| --- | --- | --- | --- |
| Login/errors | Visit fields, submit empty, correct errors, toggle password, autofill/paste. | Distinct name/role, associated errors, announced visibility, no lost input, controls reachable with keyboard open. | Not run |
| Registration | Read long instructions at large text, toggle consent, navigate back. | No functional text truncation; announced checkbox state; no focus trap. Legal documents remain deferred under F01. | Not run |
| Recovery | Request code, read status, paste invalid then valid staging code. | Announced status, clear error, paste allowed; accurate unavailable state without mail service. | Not run |
| Navigation | Reach six destinations at large text, then use Tab/Shift-Tab, Enter, Space, Escape on a hardware keyboard. | Announced destination/selection, visible target, stable order, focus always locatable and unobscured. | Not run |
| Journal | Create/edit/filter, load a page, save offline then reconnect. | Accurate readable save state; announced errors without losing notes; usable pagination; local dates. | Not run |
| Chat/safety | Write, receive staging reply, report a reason, open help, simulate failure/retry. | Assistant identified as AI, separate reply/report controls, announced radios, readable acknowledgement, help without detection. | Not run |
| Review | Select 7/30/90 days; open mood chart data. | Announced period; exact dates/values accessible without color interpretation or hover. | Not run |
| Modals | Open/close a long dialog and sheet with screen reader/keyboard. | Focus inside, inactive background, actions reachable at 300%, focus returns to trigger. | Not run |
| Mascot/avatar | Customize with controls, choose/crop photo, simulate Android destruction during picker. | Understandable controls, gesture alternative where required, no photo assigned to another account. | Not run |
| Meditation/media | Choose/start/pause/resume/finish/return using assistive technology. | Named controls, announced states, appropriate accessible media equivalents, no focus trap or unjustified fixed timer. | Not run |
| Export | Read consent, cancel, export, navigate native share sheet. | Warning before sharing, accessible destinations, cancellation without errors or inconsistent focus. | Not run |

Complement with Android Accessibility Scanner, iOS Accessibility Inspector,
Switch Access/Control, voice control, bold text, increased contrast, reduced
transparency/motion, and nonlinear font scaling. A scanner does not replace
screen reader flows. Fix and rerun any issue blocking an action or error reading
before claiming compliance for that flow.

## Reproducing automated evidence

From `elyrii_app`, after locked dependency resolution:

```bash
flutter test --no-pub test/frontend/accessibility_matrix_test.dart \
  test/frontend/semantics_matrix_test.dart \
  test/frontend/accessibility_interactions_test.dart \
  --dart-define=AUDIT_OUTPUT=build/a11y-evidence
flutter test --no-pub test/core/widgets/glass_navigation_bar_test.dart
flutter test --no-pub test/core/widgets/elyrii_page_header_test.dart
```

The frontend workflow runs the full suite and retains JSON/PNG results for
30 days. Dated screenshots and validated results intended for the project
presentation must be archived beyond that retention period.
