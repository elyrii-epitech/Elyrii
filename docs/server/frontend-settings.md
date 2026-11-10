# Settings integration with the new frontend

Branch: `feature/rafael-sapalo/frontend-backend-integration`, based on
`cleanup/frontend-dev-pr`.

The existing Réglages layout, appearance segments, vibration switch, data and
account actions are preserved. Appearance and haptics use authenticated
`GET /user/settings` and partial `PUT /user/settings` requests through the shared
API client. Controls wait for account preferences to load. The backend returns
`Cache-Control: no-store` and validates theme and boolean values.

## Saving and restoring preferences

Edits appear immediately, update the global theme/haptics, and save in order.
Reloads wait for already queued saves; an older read cannot overwrite a newer
edit. A failed save rolls back its own patch and exposes the existing reload
action. A lost acknowledgement can still mean the server saved the change:
reload reconciles the authoritative value. There is no offline write queue.

Confirmed preferences have an account-owned device cache for offline reading.
Cache failures do not turn a successful server save into a failed operation.
Account changes clear active preferences, reset theme/haptics, and fence late
responses. Removing the device cache still restores preferences from the API.

The API also retains existing language, notification, privacy and mascot fields.
No new controls, notification permission requests or translation behavior are
introduced by this milestone.

## Account export

The existing export action now has an authenticated `GET /user/export` endpoint.
It reads a consistent PostgreSQL snapshot without pagination truncation and
returns `{schemaVersion: 1, exportedAt, profile, settings, moods, journal,
messages, challenges, meditationSessions, coachSessions, coachJourneys,
notifications, points}`. All records are scoped to the authenticated account.

Journal contains active entries, owned tags, their relations, and attachment
metadata/URLs. Deleted entries are omitted. Coach includes archived enrollments
as well as the current one. Credentials, refresh sessions and internal AI jobs
are excluded through an explicit profile allowlist and selected tables. Binary
attachments are not embedded in the JSON.

After the existing consent, Flutter waits for pending settings/chat writes,
combines this response with account-owned local conversations, journal drafts
and current journey, and writes the existing temporary JSON export. Drafts stay
local; they are not uploaded to prepare the export. Account/session identity is
checked before the share handoff. The existing next-launch cleanup removes
temporary exports older than 24 hours.

The information sheets now describe the server-backed chat and Coach storage
accurately. Logout and password-confirmed account deletion use their existing
backend endpoints and local account cleanup. Legal publication status remains
as presented in the existing frontend.

## Validation

```sh
cd elyrii_server
bun run test:settings
# Add IOS_SIMULATOR_UDID=<owned-simulator> to run native UI verification too.
```

The runner creates disposable local PostgreSQL/API services and cleans them up.
Backend checks cover concurrent initialization/patches, validation, export
ownership, more than one journal page, archived Coach and deletion. The connected
Flutter check forwards real requests and interrupts responses to exercise
offline rollback, lost acknowledgements, stale reads and account changes.

The native test exercises theme/haptics, consent and actual export file creation,
remote restoration after clearing the fixture cache, logout and fixture account
deletion. It intercepts the platform share handoff; delivery to a native share
target is outside that test. Simulator-browser verification checks a real frame
of the unchanged settings screen. This is local validation, not a production or
physical-device audit.

No additional migration or environment variable is required beyond the current
integration branch migrations (including Coach migration `0009`).
