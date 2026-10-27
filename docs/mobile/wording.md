# UI wording

The French interface addresses young adults using familiar mobile vocabulary.
The mascot can react warmly, while controls and system messages describe the
actual action, state, failure, or next step. Avoid psychological interpretations,
guaranteed emotional outcomes, and repeated permission or congratulation copy.
Keep practical safety information where it is relevant.

## Vocabulary

| Object or action | French label | Rule |
| --- | --- | --- |
| Authentication | Compte, Se connecter, Créer un compte, Essayer la démo | Keep account operations explicit. |
| Mood scale | Très mal, Mal, Bof, Bien, Très bien | Keep the same five values across Home, onboarding, Journal, and session summaries. |
| Daily actions | Activités du jour | Do not hide available actions because of a low mood. |
| Challenge navigation | Défis | The monthly garden still represents completed challenges. |
| Guided multi-step content | Programmes | Internal routes, types, and persistence keys still use journey/parcours identifiers. |
| Journal item | Note | Use Enregistrer, Rechercher, Supprimer, Annuler, and Exporter consistently. |
| Mascot customization | Apparence d’Elyrii | Includes colors, accessories, finishes, and scenery. |
| Session durations in Review | Méditation | Minutes describe completed sessions, not a measured calm state. |
| Device feedback | Vibrations | The appearance preference Système follows the device theme. |

Journal questions allow ordinary, positive, and difficult experiences. General
writing prompts do not demand gratitude or improvement. A specific activity can
still explicitly ask the user to recall a good moment. Meditation instructions
keep established practice names and explain unfamiliar terms where needed.
Errors identify what failed without claiming that the problem is harmless or
asking the user to diagnose storage internals.

## Data and compatibility

Mood enum/API identifiers are unchanged. `parseJournalMood` accepts previous
French labels as well as current labels and enum names, preserving the meaning
of existing notes. Existing text written by users is never rewritten.

Built-in program text has content version 2. The repository can refresh a v1
snapshot only when its identity, ordered steps, durations, and action targets
still match. Progress, status, ownership, revision, and timestamps remain intact.
An unknown or structurally different snapshot is retained. No backend contract
or persistence schema is added for this editorial update.

`AccountInformation` supplies the same factual service/data explanation before
registration and in Settings. These explanations identify unpublished legal
documents and do not claim to replace them. The strict-privacy switch is hidden
until an actual enforcement behavior exists; existing stored values and API
fields remain compatible. Export, deletion, account access, emergency contacts,
and the existing clinical boundaries retain their behavior. Backend blockers
listed in [Features](features.md#backend-readiness) remain unresolved.

## Reproduce review captures

With the pinned SDK and locked dependencies installed, run from `elyrii_app`:

```bash
flutter test tool/wording_review_test.dart --dart-define=WORDING_OUTPUT=build/wording-review
```

This explicit review utility renders 27 real widget states at a logical size
of 390 × 844 and exports PNGs at twice that resolution. It uses the existing
test adapters for native plugins and the 3D mascot poster. The screenshots cover
arrival, registration, recovery, four onboarding steps, Home and its overlays,
Challenges, Journal and its editor/data sheet, Meditation, Programs and a step,
Chat, Profile, avatars, Settings, account data, Review, a running session, and
its summary. Each page is hosted independently, without the global navigation
dock. They are review evidence, not device screenshots or validation of native
plugins, screen readers, backend responses, or complete legal documents.

Run the same utility against the parent revision for an equivalent before/after
comparison. The normal quality checks remain `scripts/flutter_ci_check.sh`.
