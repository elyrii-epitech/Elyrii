# Frontend performance — 14 October 2026

Baseline: `f8f2f174ca3a8c81fe363bfda9417c1ab224565a` on `frontend`.
SDK: Flutter 3.47.4 / Dart 3.13.3, with the repository's unchanged lockfile.

The main gap was work proportional to an entire conversation on paths that
only needed a viewport or a page. Chat opening built 946 message bubbles to
reach the tail of 1,000 loaded messages. Reopening an encrypted 10,000-message
database returned 10,052 data rows before presenting a 50-message page. These
costs were substantially larger than fetching an already-bounded older page.

## Changes retained

1. Chat uses a reversed lazy list with stable message keys. The newest message
   is at offset zero; older pages extend the opposite edge. Paging no longer
   estimates a new reading position from `maxScrollExtent`. Chronological
   display, date separators, typing, copying, keyboard behavior and retries
   remain covered by tests.
2. Chat database version 3 persists account migration completion in the same
   transaction as encryption. Existing databases upgrade without dropping
   messages. Initial migration transfers only plaintext rows; subsequent
   process opens read the marker and indexed pages. Failed migrations remain
   retryable and account deletion also removes its marker.
3. Journal page writes use one SQLite batch inside the existing transaction.
   Revision checks, encryption, durable acknowledgement and account isolation
   remain in place. The migration and replacement paths use batching too.
4. The launch reveal lasts 450 ms instead of adding three seconds before input
   is released. Reduced-motion users still bypass it and routed page state is
   preserved.
5. Session restoration and authenticated requests read owner/token concurrently.
   Credentials remain uncached and existing generation/cancellation checks
   still run after both reads complete.
6. Dashboard cache and refresh load concurrently. A valid account-owned cache
   can supply content immediately; a late cache cannot replace fresh network
   data. Cache failure does not cancel the refresh, and account changes reject
   both pending sources.
7. Garden reuses successful data for 30 seconds instead of repeating four
   requests when its initial hydration has already completed. Explicit refresh
   and successful commands force a fetch; errors and account changes invalidate
   reuse.

## Measurement method

The final paired run uses the same harness and fixtures in a temporary archive
of the baseline and the current checkout, serially. Core cases discard one warmup
and retain nine samples; widget cases discard three warmups and retain nine
samples. The launch animation uses three samples of a simulated 16 ms Flutter
frame clock after logo decode. All retained samples, including outliers, are in
`before.json` and `after.json`; `comparison.json` and `comparison.md` include
every case, including regressions.

The workload includes 100, 1,000 and 10,000 encrypted chat messages; 100 roughly
1 KB journal entries; 1,000 loaded chat messages with variable-height bubbles;
50-message paging; and layout checks for all 15 screens. Fixtures and encryption
are prepared outside timing. Database reopens use temporary disk SQLite FFI
databases with a warm content key and filesystem cache. Data-row counters cover
production query results, excluding driver setup PRAGMAs. Dashboard/Garden
responses have a declared 200 ms local delay; credential tests have a declared
20 ms delay per read. These are controlled tests, not production latency claims.

## Results

| Case | Before median | After median | Change |
| --- | ---: | ---: | ---: |
| Added launch input gate (simulated clock) | 3008.000 ms | 464.000 ms | -84.6% |
| Session restore with two 20 ms credential reads | 41.470 ms | 20.593 ms | -50.3% |
| Authenticated request with two 20 ms credential reads | 42.458 ms | 21.370 ms | -49.7% |
| Reopen 10,000-message history and return 50 messages | 52.100 ms | 9.382 ms | -82.0% |
| Encrypt/cache 100 journal entries | 35.468 ms | 19.407 ms | -45.3% |
| Dashboard cached data readiness (200 ms refresh) | 202.002 ms | 0.312 ms | -99.8% |
| Garden data reuse (200 ms responses) | 203.003 ms | 0.022 ms | >99.9% lower |
| Open 1,000 loaded messages | 2071.814 ms | 44.361 ms | -97.9% |
| Load/render 50 older messages with 1,000 loaded | 46.034 ms | 17.861 ms | -61.2% |
| 20 backward scroll gestures, host elapsed time | 135.730 ms | 213.610 ms | +57.4% |

Chat data rows returned: **10,052 → 52**.
Chat opening bubble builds: **946 → 5**.
Older-page bubble builds: **29 → 8**.
Reading position preserved: **0/9 → 9/9**.

The scroll-gesture median regressed in this run. Warm screen layout medians also
increased in several cases, including unchanged form screens; **no uniform
screen-layout or FPS improvement is claimed**. These results are retained in the
evidence. The reliable improvements are the bounded chat work, older-page
rendering and position, cache readiness, and eliminated waits/duplicate requests.

[Complete 32-case comparison, with p95](comparison.md). [Raw baseline](before.json). [Raw final samples](after.json).
Launch measurements are the added input gate, not total OS cold startup.
Dashboard and Garden measurements describe provider data readiness/reuse;
painting an actual frame adds rendering time.

## Trials rejected

The individual trial samples are in `trials/`. They were diagnostic runs with
the sample counts recorded in each file; the final paired run is the comparison
used for the retained implementation.

- A shared selection surface with plain text replaced per-message selectable
  text. Isolated runs looked promising, but repeated scrolling comparisons did
  not confirm a consistent benefit. The existing text-selection implementation
  was restored.
- Building a message-index map for every list delegate also showed no reliable
  improvement and was reverted.

No gain is claimed for unchanged older-message SQL reads, all individual screen
layouts, or every gesture median. Those paths were measured rather than assigned
an assumed improvement. The retained chat change primarily eliminates the large
opening/layout cost and the reflow/jump when adding older messages.

## Validation and limits

Baseline regression suite: **403 tests passed**. Final suite: **411 tests passed**;
static analysis reported **no issues**, formatting and diff checks passed, and
both paired benchmark runs passed all nine tests. See [checks.json](checks.json). New regressions cover bounded
chat reads and rendering, stable reading position, selection/copy, cache races,
account changes, and Garden expiry/forced refresh/commands. Final check results
are saved with the evidence.

These are Flutter VM/JIT and headless widget measurements on Linux. Native
plugins, secure storage and native views are mocked. Small-sample p95 values are
descriptive, and host scheduling/JIT/GC affect timings. They do not establish
native FPS, GPU/WebView cost, peak memory, energy, or OS cold-launch performance.
`devices.json` records that the available Linux target has no hardware rendering;
there is no attached Android/iOS device for a physical profile measurement.

The extended native profile test records Flutter build/raster p95 for all nine
main routes, route mount time, and an older chat page, using synthetic demo data.
It rejects missing frame samples and removes only its synthetic conversation
afterward. It still excludes native WebView/WebGL GPU work. Run it on the same
physical device and app/backend configuration for both revisions:

```bash
cd elyrii_app
flutter drive --profile -d DEVICE_ID \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/performance_test.dart
```

## Reproduce the local comparison

Use the pinned Flutter version with dependencies already available in the pub
cache. The script archives the baseline, copies the same harness into it, uses
the locked dependencies offline, runs both revisions serially, and deletes its
temporary source archive. It produces the complete raw samples and comparison.

```bash
cd elyrii_app
flutter pub get --enforce-lockfile
bash benchmark/run_comparison.sh build/performance
```

For one diagnostic case:

```bash
flutter test --no-pub benchmark/app_performance_benchmark_test.dart \
  --plain-name 'older chat page viewport' --reporter expanded \
  --dart-define=PERF_OUTPUT=build/performance/older-page.json
```

The benchmarks live outside `test/` so the default regression suite does not run
heavy performance fixtures. `product-changes.patch` records the measured product
diff; the working tree also contains the harness, regression tests and native
profile extension.
