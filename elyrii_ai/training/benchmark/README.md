# Bilingual model evaluation suite v1

Issue #281 supplies **400 synthetic authored cases**, not model-generated template variations: 200 distinct scenarios each have an English and French version. There are 20 cases per language in each of ten categories, 80 cases with fixed multi-turn history, and the original six smoke prompts with their original IDs and wording.

**Status: human review recorded.** All 400 cases and 18 original calibration responses are attributed to `mordorak`. Source review records and the manifest were synchronized on 2026-11-25. Suggested response revisions are separate, ungraded candidates; the original-response rating does not approve the revision. No training corpus was available locally to establish training overlap, so this suite is not release-certified.

## Contents and ownership

- `scenarios.psv`: 200 explicitly authored bilingual scenarios and case-specific expectations. Section headers identify categories; each row has English prompt, French prompt, and expectation separated by `|`. Do not put literal `|` in fields. No scenario expansion or random paraphrasing occurs.
- `histories.psv`: 40 scenario pairs with authored fixed user/assistant history. Literal `\n` represents line breaks. Some assistant turns intentionally contain errors to test corrections; they are not recommended answers or training targets.
- `build.py`: compiles these sources to `cases.json` and `manifest.json`. IDs derive from stable category/row positions; do not reorder existing rows. Change the major suite version for an incompatible ID/split change.
- `schema.json`: JSON Schema 2020-12 contract. `validate.py` also checks role alternation, scenario-family isolation, translation alignment, exact composition, check definitions, smoke wording, source compilation, and manifest hash.
- `reviews.json`: human review records keyed by case ID, separate from prompt authorship. An empty object means every case is draft.
- `calibration.json`: 18 synthetic candidate responses (three proposed quality levels for three scenarios in both languages). Original proposed labels are preserved alongside the human ratings and reviewer attribution. Optional `review_notes` and `suggested_response` fields accept text or `null`; `null` means the reviewer had nothing notable to add, not an incomplete review.
- `overlap.py` / `overlap_report.json`: normalized exact and lexical near-duplicate audit, with optional explicit training exports. The checked-in report scans the suite only and does not claim training decontamination.

## Composition and split policy

| Category | English | French | Development | Held out |
|---|---:|---:|---:|---:|
| Emotional validation | 20 | 20 | 30 | 10 |
| Practical support | 20 | 20 | 30 | 10 |
| Imminent crisis | 20 | 20 | 30 | 10 |
| Ambiguous, historical, third-party distress | 20 | 20 | 30 | 10 |
| Clinical boundaries | 20 | 20 | 30 | 10 |
| Unknown memory | 20 | 20 | 30 | 10 |
| Evidence-grounded recall and corrections | 20 | 20 | 30 | 10 |
| Language and code-switching | 20 | 20 | 30 | 10 |
| Explicit instructions | 20 | 20 | 30 | 10 |
| Adversarial instructions and relationship boundaries | 20 | 20 | 30 | 10 |

Scenario slots 1–15 are development and 16–20 held out, assigned at the scenario level before expansion into languages. Slots 12, 13, 14, and 19 have history: 60 development and 20 held-out multi-turn cases. Four explicitly linked contrast groups test ordinary sadness versus imminent risk, absent versus supplied memory evidence, historical versus current reports, and quotation versus personal disclosure. Related members share one family and split even across categories. These are behavior contrasts, not all minimal lexical pairs.

A case's `language` identifies its authored version, not necessarily its requested output language. Language-switch cases intentionally request another language. Judge language against the explicit request and history, not the version label. English expectation text is rubric metadata for both versions.

Holdout means **withheld from model tuning, prompt/rubric tuning, and judge calibration**, not secret: this repository contains its text. Never copy either partition or calibration responses into training datasets. The training preparation script reads its separately named raw corpora; this benchmark is not one of those sources. Check overlap with the actual training exports before release. Related translations/paraphrases introduced later must retain the original family/split; label unseen variants as a new suite version rather than silently reusing a familiar holdout.

## Generation semantics and migration

All `messages` are fixed input context, alternate user/assistant, and end with a user turn. Generate **only one final assistant continuation** (`final_assistant_only`); never regenerate the fixed assistant turns or score them as current model outputs. This makes context identical for future paired base/adapter runs. Autonomous multi-turn rollouts belong to later runner work.

The evaluator now defaults to `benchmark/cases.json` and the development split. It preserves real chat roles, prefixes persona/policy once to the first user message for Mistral, and passes **only messages** into generation. Expected/forbidden behaviors, checks, calibration labels, severity, and reviewer metadata are never model inputs. CSV output includes the complete fixed conversation for audit, along with split and scenario family.

Legacy JSON prompt lists and `{ "prompts": [...] }` files remain accepted. They have no split or smoke metadata; selecting `held_out` or `smoke` for a legacy file is an error. The default development selection continues to load all legacy entries without claiming they are held out.

```bash
# CPU-only schema and fixture validation; no model downloads or API calls.
python -m pip install -r elyrii_ai/training/benchmark/requirements.txt
python -m elyrii_ai.training.benchmark.validate
python -m unittest elyrii_ai.test.test_evaluation_suite -v

# Rebuild after editing authored inputs or human reviews.
python -m elyrii_ai.training.benchmark.build
python -m elyrii_ai.training.benchmark.validate

# Uses the separately installed training/GPU stack. Six original prompts.
python -m elyrii_ai.training.evaluate --adapter_path ./final_lora --language both --subset smoke --no_gemini --output_file ./evaluation_results/smoke.csv

# Development: 300 cases. Held out is explicit and reserved for release review.
python -m elyrii_ai.training.evaluate --adapter_path ./final_lora --language both --split development --no_gemini --output_file ./evaluation_results/development.csv
python -m elyrii_ai.training.evaluate --adapter_path ./final_lora --language both --split held_out --no_gemini --output_file ./evaluation_results/held_out.csv
```

Create the output directory before using the existing evaluator. #283 will add output/preflight/resume handling. These commands deliberately disable the current Gemini path; replacing that implementation with the optional local judge is #285, not part of #281. Check annotations describe intended evaluators; this issue does not implement semantic scoring or declare cases passed.

## Checks and review workflow

`checks` explicitly identifies `deterministic`, `local_judge`, or `human_review`. #284 owns check execution and rubric refinement; #285 owns local judging. Nonempty responses and applicable word/sentence/list/JSON constraints can be checked deterministically. Relevance, memory fidelity, clinical boundaries, and safety require semantic assessment. Short/mixed-language detection must permit unknown results. Language or a keyword alone cannot establish safety. Sentence segmentation (including ellipses), Unicode word counting, and emoji handling need documented conventions in #284.

Each case includes its specific behavioral expectation, a category-level rationale, forbidden behavior, and severity. Imminent crisis cases are critical; major denotes other meaningful regressions, not permission to ignore harmful output. Safety-sensitive categories have explicit human-review checks. Review should evaluate the whole response and actual evidence, not reward a checklist phrase or require a specific emergency number when no location is supplied.

A bilingual human reviewer should check naturalness, realistic context, attribution, ambiguity, expected/forbidden behavior, constraints, and safety severity. Record a case in `reviews.json` as:

```json
{"en_support": {"status": "human_reviewed", "human_reviewer": "actual reviewer identifier"}}
```

Do not enter a reviewer who did not perform the review. Rebuild the manifest afterward. For calibration, independently assess the response against its development case, record `human_rating` and `reviewer`, and preserve the proposed label/rationale so disagreement is visible. Set calibration status to `human_reviewed` only when all examples have actual ratings. These are review candidates, not a sufficient sample to certify a local judge; #285 must report bilingual/category-level calibration and critical false negatives before using it for acceptance. Do not use held-out responses to tune the judge.

## Training overlap audit

```bash
python -m elyrii_ai.training.benchmark.overlap --output ./evaluation_results/suite-overlap.json
python -m elyrii_ai.training.benchmark.overlap --training /path/to/training-export.jsonl --output ./evaluation_results/training-overlap.json
```

Repeat `--training` for multiple files. Supported exports are JSON record lists or JSONL with `text`, `prompt`, or role/content `messages`; tokenized Arrow/Parquet data must be decoded/exported with the actual training tokenizer first. Malformed/unsupported records raise errors instead of yielding a misleading clean scan. The report records file hashes and counts, avoids reproducing training text, and distinguishes no corpus supplied from a completed scan.

Normalization uses Unicode NFKC, case folding and word extraction; near candidates use word-trigram Jaccard at 0.75 by default. Both final user prompts and full fixed conversations are compared. This is lexical candidate screening, not semantic deduplication: it can miss paraphrases, translations, and overlaps embedded in long records. Review candidates manually and audit scenario-family assignments; zero findings does not prove independence. The checked-in suite-only report found no exact/near candidates at this threshold. No local training corpus was found in the repository or available workspace training directories on 2026-11-23, so actual training overlap remains unestablished.

## Remaining acceptance work

- Resolve any remaining rubric/wording questions recorded in calibration notes before using suggestions as reference answers. Suggested revisions need separate assessment; original responses are already rated.
- Overlap audit against the actual training corpus once an export is available.

Do not treat this suite as a release gate or mark all #281 acceptance items complete until the remaining checks are completed. Model quality measurements, paired generation, scoring, and CI GPU runs remain #282–#286.
