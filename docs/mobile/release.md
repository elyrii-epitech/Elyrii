# Mobile app release

This guide complements the [CI/CD checks](ci-cd.md) and
[accessibility protocol](accessibility.md). Local tests do not replace service
configuration and native checks before distribution.

## Backend readiness

The frontend PR does not deliver the server changes below. Password recovery
[#266](https://github.com/elyrii-epitech/Elyrii/issues/266), account export
[#267](https://github.com/elyrii-epitech/Elyrii/issues/267), response reports
[#268](https://github.com/elyrii-epitech/Elyrii/issues/268), journal pagination,
chat correlation [#265](https://github.com/elyrii-epitech/Elyrii/issues/265), and
meditation catalog/duration support
[#264](https://github.com/elyrii-epitech/Elyrii/issues/264) require a compatible
backend. Verify these contracts on the target gateway before distributing the app.

The backend configuration, limits, and migration behavior described below are
**requirements for that separate implementation**, not capabilities delivered
or verified by this frontend PR. Confirm their final names and behavior against
the backend change before rollout.

## Migration and release order

1. Back up the database and test restoration in staging. Measure index creation
   time on representative data; standard index creation can lock writes.
2. Obtain and review the backend implementation's additive migration, then
   apply it through the deployment migration mechanism before enabling the
   new backend. The previously documented
   `20261010_frontend_reliability.sql` is absent from this PR and must not be
   treated as a shipped migration. Never use the test CI's
   `drizzle-kit push --force` as a production migration procedure.
3. Deliver the backend and check existing/new routes with staging accounts.
   Without pagination parameters, the journal must preserve its legacy array
   format; new clients request pages of 100 with sorting and cursors.
4. Configure mail, moderator access, and gateway limits below, then deliver the
   tested native app signed for each platform.
5. Verify idempotent creation, challenge effects, paginated reads, owner-scoped
   exports, reporting, recovery, and meditation saving from the app.

Creation UUIDs must be unique per account; older rows may retain a null request
ID. Journal cursors must use millisecond-truncated dates and UUIDs, with a
matching index, to avoid PostgreSQL/JavaScript precision-related omissions.

An app/backend rollback can retain additive columns, tables, and indexes.
Do not delete notes, reports, or recovery tokens through an improvised rollback.
Operations must cover access, backups, and retention for new reports; their
legal description remains deferred at the user's request.

## Password recovery requirements

Configure on the server:

| Variable | Required contract |
| --- | --- |
| `PASSWORD_RESET_MAIL_WEBHOOK` | HTTPS URL without username, password, query, or fragment; redirects rejected. |
| `PASSWORD_RESET_MAIL_SECRET` | Server secret passed to the webhook through `Authorization: Bearer …`, never to the app. |
| `PASSWORD_RESET_TRUSTED_PROXY_IPS` | Optional comma-separated list of exact IPs of proxies actually connected to the server. |

The webhook should receive a JSON POST:

```json
{
  "template": "password-reset",
  "to": "test-account@example.invalid",
  "code": "random-single-use-base64url-code",
  "expiresInMinutes": 15
}
```

The template must display a copyable code and its lifetime, without logging it
or embedding it in a tracking URL. The webhook should acknowledge acceptance
with 2xx within a 10-second timeout. Delivery failures must invalidate the issued
hash and expose only a generic technical category. Missing configuration should
return 503 with an accurate message. Once configured, valid requests should
return 202 uniformly for known and unknown addresses; acceptance does not prove
email delivery.

Codes should use 256 random bits, be stored only as SHA-256 hashes, expire after
15 minutes, and be consumed atomically once. New passwords must be 12–128
characters and hashed with Argon2id. Confirmation should remove the account's
refresh sessions; existing access tokens may remain valid until expiry.
Automatic renewal and email activation changes remain outside this scope.

Test in staging: unknown address, successful delivery, unavailable webhook,
expired code, two concurrent confirmations, repeated requests, and login after
confirmation. Automated fixtures have not sent real messages.

Proposed public-route limits are 1 KiB for requests and 4 KiB for confirmations,
with per-process quotas of 10 / 30 requests per 15-minute window. The identity
map should be capped at 10,000 and reject additional identities when full.
A one-minute SQL cooldown per account should protect issuance across instances.
An in-memory IP quota is not distributed; add shared gateway/mail-provider limits.

Use Bun's actual peer address. Accept `X-Real-IP` only if that peer is explicitly
trusted and the value is one valid IP. The proxy must overwrite client-supplied
headers. Verify that arbitrary headers cannot bypass limits and that proxy
configuration does not group all visitors under a single quota.

## AI reporting and moderation requirements

`POST /user/ai-reports` requires a session, selected response, and reason. Derive
the owner from the session; client-supplied owner, status, or history must never
be authoritative. Proposed limits are 16,000 content characters, a 96 KiB body,
and an atomic quota of 20 reports per rolling 24-hour period per account.
Reports should remain in Elyrii's database without automatic third-party forwarding.

Configure `MODERATION_ADMIN_USER_IDS` with exact authorized account UUIDs,
comma-separated. An empty list must deny all access. The proposed processing
API is `GET /user/moderation/reports` (at most 50 open reports) and
`PUT /user/moderation/reports/:reportId` with `{"status":"REVIEWED"}` or
`{"status":"ACTIONED"}`. The role must not come from a client-editable field.
This is a processing API, not a new administration console in the mobile app.

Assign an owner, review frequency, response deadlines, escalation for dangerous
content, and an AI correction procedure. In staging, verify denial for ordinary
users, moderator access, closure, and prevention of unauthorized closure.
An available route does not establish that reports are actually processed.

## Data and diagnostics

Verify export with two accounts, deleted records, tags/media, conversations,
and local drafts. The server export must use a consistent snapshot, exclude
passwords/tokens, and join relations by owner. Native sharing checks the session
again after preparing the file. Private temporary exports expire after 24 hours,
with cleanup on the next startup/export; account deletion also purges them.
Already shared copies are governed by the chosen destination.

Local diagnostics contain only technical categories, events, and UTC timestamps,
up to 100 events over seven days. Sharing is voluntary, without automatic upload.
Operations still needs a process for receiving/tracking diagnostics, measuring
error/outage rates, alerting, and correlating incidents without collecting
private text. Do not add chat/journal payloads or secrets to logs.

## Dependencies and builds

The frontend workflow enforces the lockfile, analysis, tests, and technical
builds. Server contracts require separate verification before release. Actions
are pinned by SHA and Dependabot opens compatible updates. Major upgrades,
especially to the 3D renderer whose internals are used, require contract review
and native tests.

API documentation uses pinned Dartdoc **9.0.11**. The SDK's bundled 9.0.6
generator crashed on dependency documentation imports with CRLF line endings;
the fixed version runs explicitly locally and in the documentation job.

The CycloneDX inventory generated by `elyrii_app/tool/frontend_sbom.py` contains
the Dart graph, Pub archive hashes, bundled model-viewer JavaScript, and GLBs.
The bundled JavaScript's upstream version is undetermined; it is identified by
its hash and license header. The inventory is neither a vulnerability scan nor
an exhaustive license review. Add the Gradle/CocoaPods dependency closure after
building, review Pub/GitHub/vendor advisories, assign owners and remediation
deadlines, and record an advisory-handling exercise. CRA obligations, if
applicable, need separate assessment; this guide makes no legal determination.

The manual `frontend-release-validation.yml` workflow publishes nothing. It
takes an HTTPS API origin and uses the `frontend-release-validation` GitHub
environment with `ANDROID_KEYSTORE_BASE64`, `ANDROID_STORE_PASSWORD`,
`ANDROID_KEY_PASSWORD`, and `ANDROID_KEY_ALIAS`. It builds signed release AAB/APK,
checks every native ELF segment for 16 KiB pages, checks the ZIP with
`zipalign -c -P 16 -v 4`, then removes temporary signing files. The iOS job
produces an unsigned technical release artifact; iOS distribution still requires
the organization's certificates, profiles, capabilities, and Xcode validation.

The committed iOS identity remains `dev`'s `com.eip.elyrii`. Personal test
identities must stay in local configuration.

Browser validation and host Flutter tests do not verify native binaries or
signing. Release validation must run separately with the required tools/secrets.
ELF fixtures prove the check's behavior, not the final APK's compatibility.

## Device checks

Before release, also run TalkBack/VoiceOver flows from the
[accessibility protocol](accessibility.md), gallery permissions, Android
recovery after picker destruction, native sharing, deletion/purge recovery,
and session expiry. Record results, models, versions, traces, and issues;
none of these physical-device checks is marked successful by default.
