Context candidate extraction
============================

``elyrii_ai.extraction.ContextExtractor`` implements issue #222 as an independent,
candidate-only capability. It does not consume Kafka events, write PostgreSQL,
or alter the response prompt. The existing Kafka chat payload does not yet
provide the persisted source message ID and trusted timestamps required here;
the later server orchestration step must supply them after persistence.

Usage
-----

Install ``elyrii_ai/requirements-bridge.txt``. The caller owns the HTTP client
and must supply a persisted user message, at most twelve context messages, and
an IANA timezone. Context must belong to the same authorized user/conversation;
the server must verify this, along with source-message ownership and existence.

.. code-block:: python

   import httpx
   from elyrii_ai.extraction import ContextExtractor, ExtractionRequest

   request = ExtractionRequest.model_validate({
       "source": {
           "id": "11111111-1111-4111-8111-111111111111",
           "role": "user",
           "content": "I prefer short replies.",
           "messageAt": "2026-10-08T00:30:00+02:00",
       },
       "context": [],
       "timezone": "Europe/Paris",
   })
   async with httpx.AsyncClient(base_url="http://localhost:11434") as client:
       result = await ContextExtractor(client, "mistral").extract(request)
       for proposal in result.candidates:
           candidate_dto = proposal.candidate.model_dump()
           # Submit to the server's validation/decision layer, not directly to DB.

Contract and trust boundary
---------------------------

``ExtractionResult.model_json_schema()`` is both the generated structured-output
schema passed to Ollama's ``/api/chat`` and the local validation contract.
The independently versioned prompt is ``prompt/extraction/v1.txt``. A result
has ``promptVersion: "v1"`` and up to eight candidate proposals, including zero.
Each proposal wraps a server-compatible ``candidate`` with an exact ``evidence``
quote, ``certainty``, ``category``, and nullable ``temporalExpression``. Metadata
belongs in the decision layer: do not pass the wrapper to the strict server DTO.

Candidate fields match the applicable subset of
``elyrii_server/modules/context/context.candidates.ts``. Facts and preferences
have ``kind``, ``key``, non-null JSON ``value``, ``origin``, ``sourceMessageId``.
Memories have ``kind``, readable ``content``, ``retention``, nullable ``eventAt``,
``origin``, ``sourceMessageId``. Validity and expiry are omitted so that the
server's retention policy decides them. Inferred candidates must be uncertain.
Temporary emotions/minor events must be short-term memories, while durable life
events are long-term memories. Stable preferences and facts have their own kinds.

Only the current user message can be cited. Historical user statements are
context only; assistant and system messages are excluded from inference input.
The prompt treats all message text as untrusted data. Local validation rejects
extra fields, fabricated source IDs, missing/altered quotes, invalid types,
duplicate JSON keys, non-finite numbers, unsupported versions and prose/fences.
This proves structure and quote provenance, not semantic entailment: a model
could still misclassify a statement or attach an unrelated assertion to a real
quote. Model-backed evaluation and server-side decisions remain necessary;
passing schema validation is never permission to store a candidate automatically.

Unknown event dates remain null. Day-only and ambiguous relative expressions
also remain null, with their exact words retained in ``temporalExpression``.
Keep the source ``messageAt`` and supplied timezone with the proposal when
reviewing these expressions: e.g. at ``2026-10-08T00:30:00+02:00`` in Paris,
"today" refers to October 8 even though the UTC date is October 7. The extractor
never invents midnight. A non-null event instant is accepted only if supplied
as trusted ``source.eventAt`` or quoted exactly in the supporting evidence.

Failure behavior and bounds
---------------------------

The default wall-clock timeout is 20 seconds (configurable up to 60), including
reading the response. Each call makes one attempt with no repairs or retries.
Input is limited to 24,000 UTF-8 bytes, twelve context messages and 4,000
characters per message. Generation is capped at 2,048 tokens, the HTTP response
at 65,536 decoded bytes, and model output at 32,768 UTF-8 bytes. Incomplete and
token-limited completions fail closed. Any malformed candidate rejects the whole
result with ``ExtractionError``; valid empty extraction is a successful result
with ``candidates: []``. Invalid requests raise Pydantic validation errors.
Neither messages nor raw model output are logged by this component.

Tests and model-backed evaluation
--------------------------------

Run deterministic tests from the repository root:

.. code-block:: bash

   python -m unittest discover -s elyrii_ai/test -p 'test_*.py'

``test/fixtures/extraction_v1.json`` is the small model-backed evaluation set,
with source requests and illustrative expected outputs for short replies,
sadness today, an upcoming exam, graduation, bereavement, negation, hypothetical
statements, uncertainty, inference, injection, quoted speech, empty extraction,
and an explicit event instant. Unit tests mock inference; they verify the
contract and safeguards, not the model's ability to select the expected meaning.

To evaluate a deployed model, load each fixture's request through
``ExtractionRequest.model_validate`` and call ``ContextExtractor.extract`` with
the real Ollama client shown above. Record the model tag/digest, prompt version,
timezone, completion/failure, and reviewer verdict per fixture. Compare meaning,
not exact wording or JSON ordering. Require: correct negation; no hypothetical
or quoted claims; injection produces no candidates; sadness stays temporary;
graduation/bereavement are durable; uncertainty is preserved; no invented dates;
and every proposal is entailed by its source evidence. Repeat relative-date cases
across local-midnight and daylight-saving boundaries with supplied timestamps.
Record schema failures separately from semantically wrong, schema-valid results.
No model-backed results are claimed by the mocked test suite.
