# Meditation

The library shows a lake beneath a purple sky, four durations, and three editorial
shelves. Its title shares the alignment of Garden, Journal, and Journeys, without
a subtitle. The **3, 5, 10, or 15 min** capsule starts the content below the title
and stays pinned beneath the compact title on scroll. It filters the featured
practice and shelves. The all-practices section is no longer shown. Tapping an
exercise expands its card toward the center of the screen. This preview shows
its name, actual rhythm, and advice. Starting uses the capsule's duration without
asking again and without audio.

The preview is an opaque card with four rounded corners. Tapping outside it,
using its close button, or swiping down closes it without starting a session.
Other presentations retain their bottom-screen anchor.

The library displays nine practices. Sound awareness, loving-kindness, and
self-compassion remain in the domain catalog and required API contract, but are
not shown here. There is no resume row because interrupted session positions
are not stored.

The session opens outside the dock. The lake keeps a uniform scale without
stretching the moon. The circle and Elyrii's pose follow practice phases and
freeze on pause. Elyrii retains the user's outfit without added locked
accessories. Reduced motion fixes the circle and pose without stopping the timer.

Closing an active session requires confirmation. Finishing records the end and
opens a summary with actual elapsed time, complete cycles, and five feeling
choices. Closing the summary does not restart a recorded session; the summary
can be reopened. It does not display a daily streak because no fresh confirmation
is available after saving.

The library offers only the capsule's four durations, without custom input.
Home and journey-step durations remain supported by the controller within its
**1–1,439 minute** range. A journey step opens the practice preview with one of
its suggested durations. All sheets share `AppSheetRoute`.

## Practices and sessions

| Practice | Guidance |
| --- | --- |
| Discovery | 3–3 breathing, without holds |
| Cardiac coherence | 5–5 breathing, six breaths per minute |
| Long exhale | Extended exhale, 4–6 reference rhythm |
| Diaphragmatic | Belly awareness, 4–6 reference rhythm without holds |
| Focus | 4–4–4–4 box breathing, with a pause after exhaling |
| 4-7-8 relaxation | Up to four cycles, then natural breathing for the remaining time |
| Ujjayi | Yoga-inspired, 6–6 reference rhythm |
| Mindful breathing | Written instructions, natural breathing |
| Body scan | Written instructions, moving attention through the body |
| Sound awareness | Written instructions, present-moment attention |
| Loving-kindness | Written instructions, kind wishes |
| Self-compassion | Written instructions, self-support |

The five written practices have weighted steps. The controller distributes each
step across a proportion of the total duration, including settling in and the
final return. It does not impose a breathing cadence. Pause freezes time and
the current step; resume continues from that point. There is no recorded audio.

Session titles remain between stop and pause controls. Long instructions scroll.
The summary shows zero breathing cycles for written guidance practices.

## References and review status

The French practice scripts are Elyrii originals. Numeric rhythms and step
distribution are app adaptations rather than clinical protocols attributed to
the organizations below.

| Proposed reference | Role |
| --- | --- |
| [NHS: breathing exercises](https://www.nhs.uk/mental-health/self-help/guides-tools-and-activities/breathing-exercises-for-stress/) | Gentle, comfortable breathing; 3–3/5–5 rhythms are adaptations |
| [VA Whole Health: diaphragmatic breathing](https://www.va.gov/WHOLEHEALTHLIBRARY/tools/diaphragmatic-breathing.asp) | Belly awareness and diaphragmatic breathing; 4–6 is an app reference rhythm |
| [Cleveland Clinic: box breathing](https://health.clevelandclinic.org/box-breathing-benefits) | Proposed specific box-breathing reference |
| [Dr Andrew Weil: breathing exercises](https://www.drweil.com/health-wellness/body-mind-spirit/stress-anxiety/breathing-three-exercises/) | 4–7–8 method; four-cycle limit before returning to natural breathing |
| [UC Berkeley: mindful breathing](https://ggia.berkeley.edu/practice/mindful_breathing) | Attention to natural breathing |
| [UC Berkeley: body scan](https://ggia.berkeley.edu/practice/body_scan_meditation) | Moving attention through the body |
| [UC Berkeley: loving-kindness](https://ggia.berkeley.edu/practice/loving_kindness_meditation) | Kind wishes |
| [UC Berkeley: self-compassion break](https://ggia.berkeley.edu/practice/self_compassion_break) | Acknowledging difficulty, common humanity, and self-support |
| [NHS: mindfulness](https://www.nhs.uk/mental-health/self-help/tips-and-support/mindfulness/) | General reference for present-moment and sensory awareness |
| [NCCIH: meditation and mindfulness](https://www.nccih.nih.gov/health/meditation-and-mindfulness-effectiveness-and-safety) | General context; descriptions make no treatment promises |
| [NCCIH: yoga](https://www.nccih.nih.gov/health/yoga-what-you-need-to-know) | General yoga context; does not validate the 6–6 rhythm or specific Ujjayi instructions |

**Practice reference review is incomplete.** The previous October 3, 2026 review
reported HTTP 403 responses when accessing professional sources. This redesign
does not revalidate them. Screenshots do not establish editorial approval by
these organizations or a professional.

## Required API contract and current incompatibility

The client sends an exercise ID and the selected integer duration to
`POST /meditation/sessions/start`. It requires all 12 native catalog IDs and
durations of **1–1,439 minutes** for every exercise. A compatible catalog should
publish these bounds as `minDurationMinutes` and `maxDurationMinutes`, while
retaining legacy IDs `breathing-5m`, `body-scan-10m`, and `grounding-15m`.
Library curation remains local.

**This contract is not implemented by the backend in `dev` or this frontend PR.**
The current server accepts only those three legacy IDs, enforces each program's
fixed duration, and caps requests at 180 minutes. All native frontend exercise
IDs therefore return HTTP 400. The timer continues locally, but the session is
not recorded. Backend alignment is tracked in
[#264](https://github.com/elyrii-epitech/Elyrii/issues/264), assigned to Rafael.
Deploy and verify that change before treating real-account session saving as
available.

The client attempts completion even without a feeling selection; a later
selection updates that feeling. A creation response arriving after interruption
is canceled; one arriving after the session ends is completed. Synchronization
failures are shown in the summary.

The payload still uses `durationMinutes`; the database retains the integer
`duration_minutes` column. The frontend adds no database migration. Server
validation/catalog changes must be delivered separately.

## Verification

Flutter tests cover duration filters, the pinned capsule, opening/canceling the
centered preview, starting with the selected duration, written steps, pause,
and exit confirmation. They also check the four 4-7-8 cycles, the pause label,
actual summary figures, and feeling selection. Controller tests cover late
responses and synchronization failures.

The server catalog must be compared with all 12 Flutter IDs and duration bounds
as part of #264. Frontend fixtures do not prove server compatibility. This PR
changes neither the server nor its data.

Widget tests replace the 3D model with its test surface. Browser checks cover
the 3D rendering, lake, and sheets separately.
