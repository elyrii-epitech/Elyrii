# Mobile features

Modules live in `elyrii_app/lib/features`. Private local data is account-scoped;
demo mode uses an isolated session. UI labels remain French; this guide uses
English descriptions.

## Backend readiness

The frontend PR does not implement the server contracts required for real
accounts. The following remain blocking dependencies: correlated chat replies
[#265](https://github.com/elyrii-epitech/Elyrii/issues/265), password recovery
[#266](https://github.com/elyrii-epitech/Elyrii/issues/266), account export
[#267](https://github.com/elyrii-epitech/Elyrii/issues/267), AI response reports
[#268](https://github.com/elyrii-epitech/Elyrii/issues/268), and meditation catalog
and duration support [#264](https://github.com/elyrii-epitech/Elyrii/issues/264).
Journal pagination also requires a compatible server. Demo flows and local
fixtures do not establish that these contracts work on `dev`.

| Module | Flow | Data |
| --- | --- | --- |
| Authentication | Login, registration, password recovery, demo, logout | Authentication API; credentials in Keychain/Keystore |
| Profile | Personal profile, identity, single goal, and avatar selection | User API; image copies in account-scoped private cache |
| Dashboard and review | Mood, weekly/monthly/quarterly review, shortcuts | Server journal history; local moods; completed sessions for calm minutes |
| Journal | Daily feed, writing/editing, mood per entry, reading, deletion, local search, text export | API and SQLite with 100-entry pages; encrypted account-scoped drafts; selected daily question stored locally |
| Chat | Conversations, correlated replies, retry, copy, report | Bearer WebSocket; encrypted SQLite history, 50-item pages |
| Garden | Challenges to complete, today's actions, monthly gardens, completed challenges | API challenges grouped by completion date; local actions shown read-only |
| Journeys | Explicit selection, ordered steps, pause/resume, secondary access to existing challenges | Local editorial catalog; encrypted account-scoped progress on this device, without a new API or cross-device sync |
| Meditation | 12 domain practices, 1–1,439 minute durations, pause/resume, summary | Monotonic controller; API session synchronization requires #264 |
| Mascot | Colors, finishes, 15 accessories across four zones, explicit save | Shared GLB scene; account-scoped preferences and progression |
| Settings | Dark/light/system appearance, haptics, privacy, export, diagnostics, account deletion | Preferences, installed version, API, user-initiated native sharing |

The arrival flow introduces Elyrii in the Arches scene, then offers login,
registration, and account-free discovery. Discovery asks four short questions
before opening Home. First name and the single goal use the existing profile.
The first mood uses the same save operation as Home. The scene is stored
locally per account after saving the outfit. Avatar selection remains in Profile.

Registration retains mandatory consent, password rules, and the email
verification message. Password recovery requires a real server-issued code and
a new password of 12–128 characters. Google and Apple buttons are hidden because
the client does not implement those login methods. Legal links explain that
the full texts are not published yet; publication is required before production.

Chat exposes emergency resources independently of local distress detection.
This heuristic does not replace professional assessment. Meditation sessions
use written instructions and have no recorded audio track.

Journeys replaces Coach in navigation at `/parcours`. Selecting a journey and
completing a step are explicit actions. Replacing a journey requires confirmation;
canceling preserves its position. Pausing creates no deadline or penalty.
Progress stays local, including in the isolated demo session, and is included
in data export and account purging. Active challenges, proposals to accept or
reject, and available ideas appear first in Garden and remain accessible from
the challenge list in Journeys. Catalogs expand without hiding the monthly
garden. Only completed challenges produce flowers; journey steps do not.

Garden shows challenges to complete, today's actions, then the monthly garden.
Arrows browse past months without entering the future. Each completed challenge
produces one flower according to its local completion date, without duplicates.
Challenges without dates remain identified without being assigned to an arbitrary
month. Dense gardens scroll horizontally. Tapping a flower opens its title and
date; the completed challenge list expands below the landscape. Synchronization
grows new flowers without moving existing ones. Today's local actions do not
create flowers or complete challenges.

Journal uses a plum color without halos or glass cards. Its title no longer
shows a private badge; privacy information remains in each entry's menu. Search
covers loaded entries and discloses that limit when more history pages exist.
Text export loads history and includes local drafts. The same autosaving editor
opens from Journal, Home, and journey steps. Dictation, photo, and keyword tools
are not offered without real services. Opening/closing the editor does not
automatically complete a step.

The Home avatar opens Profile with a slide from the left; reduced motion uses
a fade. Profile reuses the selected mascot scene behind the avatar, first name,
and arrival date. Top controls in Home, Profile, and Review share 48-point
bubbles aligned below the system area. The rounded body groups profile,
settings, review, and data, in that order. Statistics and outfits remain
accessible from the Home capsule. Avatar selection saves immediately.
The profile form retains its explicit save button and single wellness goal,
chosen from six account values. Clearing name, age, gender, or goal does not
clear it on the server under the current contract.

Review displays only moods known on this device. Months and quarters are
grouped into seven periods. Calm minutes come from completed sessions, without
converting session counts into durations. If the 100-session limit truncates
the period, Review marks the minutes as partial and leaves earlier periods
unknown. Points, percentages, and challenge rates are absent. The helpful
activities card stays hidden without a sufficient association in the data.

The data section explains local copies and offers export with explicit consent.
Deletion requires the password and retains account-scoped local purging.
Current terms and privacy texts remain accessible in Settings. The policy
still describes information that needs documenting; it is not a complete
legal document.

French is the only declared UI language. Push notifications are marked
unavailable. Automatic access-token renewal and email activation changes remain
out of scope; a 401 for the current session closes it locally.

See [architecture](architecture.md) for session/persistence contracts,
[meditation](meditation.md) and [customization](mascot-accessories.md) for their
specifications, and [release](release.md) for remote-service requirements.
