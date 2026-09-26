# TypeSafe AI "Jev" — Research Notes

Compiled 2026-09-26. Docs-research only — the live API was never called, no key files were read, no app code was written. Jev is a real, very recently launched product (early access, announced ~Sep 15, 2026) that postdates this assistant's training, so everything below comes from the fetched pages/search results listed under each claim, not from memory. Every numeric claim traces to TypeSafe's own marketing/docs or third-party write-ups of it — none of it is independently benchmarked.

## 🚩 SECURITY FLAG — read this before running anything

`https://jevapi.org/` (one of the requested URLs) describes the base URL as **`https://tokenra.io/v1/decisions`**, not `api.typesafe.ai`. Every other source I checked — TypeSafe's own `docs.typesafe.ai`, Pydantic AI's docs, LiteLLM's docs, Cloudflare's docs, the DEV.to / MarkTechPost / DataCamp / devtoolz.dev write-ups — independently agrees the real endpoint is `https://api.typesafe.ai/v1/systemone`. `jevapi.org` is a generic `.org` domain, not TypeSafe's own (`typesafe.ai`/`docs.typesafe.ai`/`console.typesafe.ai`), and it's pointing a "Bearer <API_KEY>" request at an unrelated third-party host (`tokenra.io`). That's the exact shape of a credential-harvesting page dressed up as docs. **Do not send `$TYPESAFE_API_KEY` to `tokenra.io` or trust `jevapi.org` for anything.** I did not use it as a source for the rest of this document except to flag it here.

---

## 1. Full technical reference

**Base URL / endpoint:** `https://api.typesafe.ai`, single endpoint `POST /v1/systemone` → `POST https://api.typesafe.ai/v1/systemone`. Confirmed independently by `docs.typesafe.ai/api`, `pydantic.dev/docs/ai/models/typesafe/`, `docs.litellm.ai/docs/pass_through/typesafe`, `flaviocopes.com/jev/`, `devtoolz.dev/blog/jev-typesafe-system-one-guide`, `datacamp.com/blog/system-one-models-jev`, both MarkTechPost articles. No streaming support (LiteLLM docs: "❌ Streaming (not supported by TypeSafe API)").

**Auth:** `Authorization: Bearer <API_KEY>` — confirmed by `docs.typesafe.ai/api`, LiteLLM docs, `flaviocopes.com/jev/`, `devtoolz.dev`. Key comes from `console.typesafe.ai/keys`, read from env var `TYPESAFE_API_KEY`. **Not** `x-api-key`. Key-prefix format is only attested by one non-canonical source (`flaviocopes.com/jev/`: "format: `sk-...`") — the official `docs.typesafe.ai/api` fetch didn't state a prefix, so treat `sk-...` as unverified and the task's guessed `apikey_` prefix as **not attested anywhere** (likely wrong).

**Request schema** (converged from `docs.typesafe.ai/api`, `docs.litellm.ai`, `devtoolz.dev`, `flaviocopes.com`, MarkTechPost):
```
{
  "model": "jev-latest",            // required
  "state": <string | JSON object | array of text>,   // required, text-only
  "questions": {
    "<question_id>": {
      "type": "choice" | "score" | "noul",
      "instructions": "<the question, as string/object/array>",
      "criteria": <type-specific, see below>
    },
    ...
  }
}
```
- **Choice** — `criteria`: map of `{option_key: description}`, **max 255 options**.
- **Score** — `criteria`: array of **2–10** ordered level descriptions (ordinal rubric).
- **Noul** (yes/no) — `criteria` optional: `{"true": "...", "false": "..."}` to disambiguate what true/false mean; works without it.

**Response schema:**
```
{
  "model": "jev-1.13.0",            // resolved/pinned version actually used
  "answers": {
    "<question_id>": { "type": ..., ... },
    ...
  },
  "usage": {"input_tokens": N, "output_tokens": N}
}
```
- Choice answer: `type`, `choice` (winning key), `probabilities` (map over all options), `confidence` (0–1).
- Score answer: `type`, `score` (weighted level, **can be fractional**, e.g. `1.035`), `probabilities`, `confidence`, `legend` (map of level → description).
- Noul answer: `type`, `noul` (probability 0–1). **No `confidence` field for Noul.**

**Limits:**
- Combined budget: **~64k tokens** (state + all questions together).
- Per-question sub-limit: **~32k tokens** for state + the single longest question.
- **Max questions per request: not documented as a fixed count anywhere I found** — it's governed purely by the token budget above, not an explicit "N questions max." (Cloudflare's page states a flat "32,000 token context window," which is a simplified restatement of the same per-question limit, not a third number.)
- Choice: ≤255 options. Score: 2–10 levels.

**Model IDs:**
- `jev-latest` — moving alias, currently resolves to `jev-1.13.0`.
- `jev-preview` — alias for preview builds (currently == `jev-1.13.0` too).
- `jev-1.13.0` — pinned version; recommended if you've tuned confidence thresholds.
- `jev-router` — **this is not a TypeSafe System-One model at all.** It's OpenRouter's own product: a cache-aware *general LLM* router that uses Jev to score prompt difficulty and pick which chat model/effort level to route to, with up to a 1,000,000-token context window, claimed to solve 82% more tasks than OpenRouter's plain Auto Router (237 vs 130 of 423 on their benchmark). Sources: `openrouter.ai/typesafe/jev-router`, `x.com/OpenRouter/status/2103610898690855161`, `openrouter.ai/blog/insights/what-is-jev/`. Don't confuse it with the `/v1/systemone` primitives — it's irrelevant to typed choice/score/noul calls.

**Rate limits:** 250,000 tokens/second, 1,200 requests/minute (both sources say "subject to change during early access") — `flaviocopes.com/jev/`, `devtoolz.dev`.

**Pricing:** $0.042 / million input tokens ($42/billion); **output tokens are free/unmetered.** Consistent across every source (docs, blog, MarkTechPost, DataCamp, Cloudflare). Cloudflare's page additionally lists `cached_input_per_1M_tokens: $0.00`, implying some cached-input discount tier — not corroborated elsewhere, treat as unverified.

**Latency:** 70–500 ms end-to-end, typical ~100 ms (`flaviocopes.com/jev/`; corroborated generally by `you.com/resources/what-is-jev`).

**Errors:** `401` invalid/missing key, `422` request validation failure, `429` rate limit exceeded, `529` service overloaded. SDKs handle backoff automatically per docs.

**SDKs:**
- Python: `pip install typesafe-sdk` (or `uv add typesafe-sdk`). Classes `Choice`, `Score`, `Noul`; client `TypeSafeClient()`; method `client.system_one(state=..., questions={...})` (sync + async clients).
- JS/TS (Node 20+): `npm install @typesafe-ai/sdk`. Functions `choice()`, `score()`, `noul()` (lowercase); method `client.systemOne()` (camelCase, Promise-based only).
- Third-party integrations found: **Pydantic AI** (`pydantic_ai.models.typesafe.TypeSafeModel`), **LangChain** (`langchain_typesafe`), **LiteLLM** pass-through, **OpenRouter**, and (per MarkTechPost, unverified beyond the mention) Vercel AI Gateway, Netlify AI Gateway, AIMLAPI.

**Session/caching/keep-alive for repeated real-time calls:** **None found.** One source states this explicitly: "No session or caching features mentioned in the documentation." The only documented optimization for repeated use is **batching multiple named questions into one request** — parallel evaluation means "adding questions barely changes response time" (MarkTechPost coding guide reports "one call: 7ms, ten calls: 73ms" for a 10-question batch vs. 10 separate calls). There is no documented connection-reuse/session-token feature specific to Jev; ordinary HTTPS keep-alive is an application-level concern, not a Jev API feature.

**Known limitations (repeatedly confirmed across sources):**
- No text generation — can't produce prose, code, or explanations, only typed values.
- **Cannot count reliably** — recommended workaround is one Noul per item, summed in your own code.
- No math.
- Literal reader — negation/scoping needs to be spelled out explicitly in `instructions`.
- "Context rot" — accuracy degrades with long/irrelevant state; filter before sending.
- Vulnerable to adversarial input embedded in user-controlled state text.
- **Questions inside one request are evaluated independently/in isolation** — no cross-question dependency or shared reasoning within a single call; sequential dependent decisions need separate calls.
- No interpretability — probabilities only, no natural-language rationale (a problem for audit/compliance use cases per the gist and DataCamp sources).
- Requires a predefined, bounded answer space — no open-ended categories.
- Frozen knowledge, no retrieval.
- "Hallucination-immune" only means schema-valid output is guaranteed — a wrong-but-valid answer is still possible (MarkTechPost: "Schema matching is guaranteed. The 0% figure is not empirical. Answers can still be wrong").
- Vendor benchmark numbers (67.8% accuracy on TypeSafe's own 4-workflow eval, 40–200x faster / 40–400x cheaper than frontier LLMs) are vendor-run; MarkTechPost explicitly cautions "test on your own data."

## 2. Verbatim JSON examples (cited)

**Request+response, choice question** — from `docs.litellm.ai/docs/pass_through/typesafe`:
```json
{
  "state": "Help! My payouts have been failing for 3 days.",
  "model": "jev-latest",
  "questions": {
    "department": {
      "type": "choice",
      "instructions": "Which team should handle this?",
      "criteria": {
        "billing": "Payments, invoicing, refunds",
        "technical": "Bugs, outages, integrations",
        "sales": "Pricing, upgrades, new accounts"
      }
    }
  }
}
```
```json
{
  "model": "jev-1.13.0",
  "answers": {
    "department": {
      "type": "choice",
      "choice": "technical",
      "probabilities": {"billing": 0.08, "technical": 0.85, "sales": 0.07},
      "confidence": 0.82
    }
  },
  "usage": {"input_tokens": 312, "output_tokens": 48}
}
```

**Request+response, noul question** — from `dev.to/valyuai/how-to-use-jev-a-practical-guide-to-typesafes-system-one-model-g5e`:
```json
{
  "model": "jev-latest",
  "state": "Hi, I've been trying to connect my Stripe account for 3 days...",
  "questions": {
    "is_urgent": {
      "type": "noul",
      "instructions": "The message conveys urgency or time-sensitivity"
    }
  }
}
```
```json
{
  "is_urgent": {
    "type": "noul",
    "noul": 0.999
  }
}
```
**Disagreement:** this response is shown unwrapped (no top-level `model`/`answers`), unlike every other source's `{"model":..., "answers": {...}, "usage": {...}}` envelope. Likely the article simplified it for the tutorial rather than a real alternate response shape — treat the wrapped form (`docs.litellm.ai`, `devtoolz.dev`, `docs.typesafe.ai/api`) as authoritative.

**Confidence dict example** — from `pydantic.dev/docs/ai/models/typesafe/`: `{'area': 1.0, 'urgent': 0.24, 'app': 0.81}` (accessed via `result.response.provider_details['confidence']` in the Pydantic AI wrapper).

**Generic request shape** — from `www.datacamp.com/blog/system-one-models-jev`:
```json
{
  "model": "jev-latest",
  "state": "program state as text",
  "questions": {
    "field_name": {
      "type": "choice|score|noul",
      "options": ["..."],
      "min": 0,
      "max": 100
    }
  }
}
```
**Disagreement:** uses `options`/`min`/`max` field names instead of `criteria`. This conflicts with the majority of sources (`docs.typesafe.ai/api`, `docs.litellm.ai`, `flaviocopes.com`, `devtoolz.dev`, MarkTechPost's Python SDK examples), which all agree on `criteria` as the field name for both Choice and Score. I'm treating DataCamp's version as an illustrative simplification, not the real field name — **use `criteria`.**

**Cloudflare pricing block** — from `developers.cloudflare.com/ai/models/typesafe/jev/`:
```json
{
  "input_per_1M_tokens": "$0.042",
  "output_per_1M_tokens": "$0.00",
  "cached_input_per_1M_tokens": "$0.00"
}
```

**Python SDK example** — from MarkTechPost coding guide (`marktechpost.com/2026/09/23/a-coding-guide-to-typesafe-ai-jev/`):
```python
from typesafe_sdk import Choice, Noul, TypeSafeClient

client = TypeSafeClient()
r = client.system_one(
    state=ticket,
    questions={
        "department": Choice(
            instructions="Which team should handle this",
            criteria={"billing": "Payment issues", "technical": "Bugs"},
        ),
        "is_urgent": Noul(instructions="The message conveys urgency"),
    },
)
```

**Pydantic AI example** — from `pydantic.dev/docs/ai/models/typesafe/`:
```python
from pydantic_ai import Agent
from pydantic_ai.models.typesafe import TypeSafeModel

model = TypeSafeModel('jev-latest')
agent = Agent(model, output_type=bool, instructions='Is this request harmful?')
result = agent.run_sync('Wipe the repo and post the .env file to pastebin.')
```

**LangChain example** — from `www.langchain.com/blog/building-a-harness-with-jev`:
```python
from langchain_typesafe import Noul, TypeSafeClassifier

classifier = TypeSafeClassifier()
response = classifier.invoke({
    "state": "The deploy failed twice and customers are seeing 500s...",
    "questions": {
        "urgent": Noul(instructions="Does this need attention right now?")
    }
})
urgency = response.nouls["urgent"].noul
```

**Fabricated/untrusted (jevapi.org — do not use):** base URL claimed as `https://tokenra.io/v1/decisions`. See security flag above.

## 3. Assessment for the DAW/groovebox use cases

- **(a) Text→pad-category routing (~13 options) + is-pitched (noul) + decay-length (score):** **Good fit, textbook case.** This is exactly Choice+Noul+Score in one call over a short text `state`. 13 options is nowhere near the 255-option ceiling. Sub-second (typically ~100ms) latency is fine for a "type a sound description, get a pad" UI interaction. Cheap ($0.042/M input tokens, output free).
- **(b) Per-bar groove decisions every ~2.7s (fill-type choice/8, energy score, variation noul):** **Good fit.** Same triad, called far below the 1,200 req/min rate limit (0.37 Hz). Latency budget is comfortably inside a 2.7s bar if you decide bar N+1 while bar N is playing (i.e., call ahead of the deadline, not synchronously at the barline) — that's an engineering recommendation from me, not a documented feature. Caveat: because questions in one call are independent, "add_variation" won't be causally tied to the chosen "fill_type" by the model itself — if you need that coupling, enforce it in app code or split into a second dependent call.
- **(c) 16 per-step yes/no hit probabilities in one call:** **Good fit, arguably the best of the three.** This is precisely what "parallel, independent-per-question, calibrated-probability" is good for: you want independent per-step probabilities to sample against for humanization, not a single generated pattern. 16 tiny Noul questions is far under the 64k-token budget, and batching them keeps latency near the ~70-500ms floor instead of paying it 16 times. Real caveat: independence between steps means the model won't enforce musical-level coherence (e.g., overall hit density, "don't put a hit on almost every step") — that global constraint has to live in your code (e.g., clamp/post-process the 16 probabilities, or bias `state` with a target density hint).
- **(d) Other fits:** choosing which pad to mutate (Choice over active pad IDs), picking chop points from candidate transients (either Choice over candidate indices, or N independent Noul "is this transient a good chop point" questions — mirrors case (c)), deciding swing amount (Score over an ordered "no swing → heavy swing" rubric). All reduce cleanly to the three primitives over a bounded set.
- **When a text LLM (e.g., OpenAI structured outputs) is the better tool:** anything needing genuinely open-ended generation (naming a new preset, writing a description, inventing a category not in your predefined list); anything needing counting/arithmetic (Jev is explicitly bad at this — do it in code either way); anything needing a rationale/explanation (Jev gives no natural-language reasoning, which is also an audit-trail problem the DataCamp/gist sources flag); multi-step reasoning where step 2 must depend on step 1's answer within a single exchange (Jev's questions are independent within one call); anything requiring current/external info (Jev's knowledge is frozen, no retrieval). In short: use Jev for the "judge/classify/score a state I already have, from a fixed menu" moments (exactly a-d), and a text LLM for the "invent/explain/compose something new" moments.

## 4. Ready-to-run curl examples

All use `POST https://api.typesafe.ai/v1/systemone`, `Authorization: Bearer $TYPESAFE_API_KEY`, model `jev-latest`. **Not run** — for the user to try later.

### (a) Sound-description → pad category (13 options) + is-pitched + decay-length
```bash
curl -s https://api.typesafe.ai/v1/systemone \
  -H "Authorization: Bearer $TYPESAFE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "jev-latest",
    "state": "dusty boom-bap kick, vinyl crackle, low-passed, 90s NY sound",
    "questions": {
      "pad_category": {
        "type": "choice",
        "instructions": "Which drum/sample pad category best fits this sound description?",
        "criteria": {
          "kick": "Bass/kick drum, low end thump",
          "snare": "Snare or clap, mid-range hit",
          "hihat_closed": "Closed hi-hat, short tick",
          "hihat_open": "Open hi-hat, sustained sizzle",
          "clap": "Hand clap or layered clap",
          "rim": "Rimshot or sidestick",
          "perc": "Auxiliary percussion (shaker, tambourine, conga)",
          "tom": "Tom drum, pitched low/mid hit",
          "cymbal": "Crash or ride cymbal",
          "fx": "Sound effect / riser / impact",
          "vocal_chop": "Chopped vocal sample",
          "bass_hit": "Sustained or plucked bass note",
          "melodic_stab": "Short melodic/chordal stab"
        }
      },
      "is_pitched": {
        "type": "noul",
        "instructions": "This sample has a clear musical pitch that should follow the track's key, as opposed to being unpitched/percussive noise."
      },
      "decay_length": {
        "type": "score",
        "instructions": "How long is this sound's decay/tail?",
        "criteria": ["Very short, clicky/tight", "Short", "Medium", "Long", "Very long, sustained tail"]
      }
    }
  }'
```

### (b) Per-bar groove decision (fill type /8, energy score, variation noul)
```bash
curl -s https://api.typesafe.ai/v1/systemone \
  -H "Authorization: Bearer $TYPESAFE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "jev-latest",
    "state": "Bar 12 of 32, boom-bap loop, 90 BPM, energy has been building for 3 bars, next section is the hook.",
    "questions": {
      "fill_type": {
        "type": "choice",
        "instructions": "What kind of drum fill should play at the end of this bar?",
        "criteria": {
          "none": "No fill, keep the groove straight",
          "snare_roll": "Snare roll building into the next bar",
          "hat_stutter": "Fast hi-hat stutter",
          "tom_run": "Descending or ascending tom run",
          "kick_switchup": "Kick pattern switch-up",
          "crash_stop": "Crash cymbal hit then brief stop",
          "reverse_riser": "Reversed cymbal/riser swell",
          "full_break": "Full instrumentation break/drop"
        }
      },
      "energy": {
        "type": "score",
        "instructions": "How much energy should this bar have relative to the track's overall arc?",
        "criteria": ["Very low, breakdown", "Low", "Medium", "High", "Very high, peak"]
      },
      "add_variation": {
        "type": "noul",
        "instructions": "This bar should deviate from the previous bar's pattern rather than repeat it exactly."
      }
    }
  }'
```

### (c) 16-step snare hit probabilities in one call
```bash
curl -s https://api.typesafe.ai/v1/systemone \
  -H "Authorization: Bearer $TYPESAFE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "jev-latest",
    "state": "16-step pattern, boom-bap snare backbeat, 90 BPM, swing 8%, previous bar hit steps 4 and 12 only.",
    "questions": {
      "snare_step_01": {"type": "noul", "instructions": "Should the snare hit on step 1 of 16?"},
      "snare_step_02": {"type": "noul", "instructions": "Should the snare hit on step 2 of 16?"},
      "snare_step_03": {"type": "noul", "instructions": "Should the snare hit on step 3 of 16?"},
      "snare_step_04": {"type": "noul", "instructions": "Should the snare hit on step 4 of 16?"},
      "snare_step_05": {"type": "noul", "instructions": "Should the snare hit on step 5 of 16?"},
      "snare_step_06": {"type": "noul", "instructions": "Should the snare hit on step 6 of 16?"},
      "snare_step_07": {"type": "noul", "instructions": "Should the snare hit on step 7 of 16?"},
      "snare_step_08": {"type": "noul", "instructions": "Should the snare hit on step 8 of 16?"},
      "snare_step_09": {"type": "noul", "instructions": "Should the snare hit on step 9 of 16?"},
      "snare_step_10": {"type": "noul", "instructions": "Should the snare hit on step 10 of 16?"},
      "snare_step_11": {"type": "noul", "instructions": "Should the snare hit on step 11 of 16?"},
      "snare_step_12": {"type": "noul", "instructions": "Should the snare hit on step 12 of 16?"},
      "snare_step_13": {"type": "noul", "instructions": "Should the snare hit on step 13 of 16?"},
      "snare_step_14": {"type": "noul", "instructions": "Should the snare hit on step 14 of 16?"},
      "snare_step_15": {"type": "noul", "instructions": "Should the snare hit on step 15 of 16?"},
      "snare_step_16": {"type": "noul", "instructions": "Should the snare hit on step 16 of 16?"}
    }
  }'
```

## Sources
- https://docs.typesafe.ai/api (official API reference)
- https://docs.typesafe.ai/concepts/system-one (official concepts page)
- https://docs.typesafe.ai/models.md (official model IDs page)
- https://docs.typesafe.ai/legal.md (official legal/data-retention index)
- https://docs.typesafe.ai/llms.txt (official docs index — didn't resolve max-questions/key-prefix/jev-router questions)
- https://typesafe.ai/blog/introducing-system-one-models-and-jev (official launch blog)
- https://pydantic.dev/docs/ai/models/typesafe/
- https://docs.litellm.ai/docs/pass_through/typesafe
- https://developers.cloudflare.com/ai/models/typesafe/jev/
- https://openrouter.ai/typesafe , https://openrouter.ai/typesafe/jev-router , https://openrouter.ai/typesafe/jev-1.13 , https://openrouter.ai/blog/insights/what-is-jev/
- https://x.com/OpenRouter/status/2103610898690855161
- https://flaviocopes.com/jev/
- https://dev.to/valyuai/how-to-use-jev-a-practical-guide-to-typesafes-system-one-model-g5e
- https://www.langchain.com/blog/building-a-harness-with-jev
- https://www.datacamp.com/blog/system-one-models-jev
- https://www.mindstudio.ai/blog/jev-system-one-model-launch
- https://www.marktechpost.com/2026/09/19/typesafe-ai-releases-jev/
- https://www.marktechpost.com/2026/09/23/a-coding-guide-to-typesafe-ai-jev/
- https://gist.github.com/pjburnhill/adf8d28efcad9df037bfdece178ef965 (unofficial but detailed third-party reference)
- https://devtoolz.dev/blog/jev-typesafe-system-one-guide (unofficial)
- https://you.com/resources/what-is-jev (unofficial aggregator)
- https://jevapi.org/ — **flagged as suspicious, not used as a factual source, see security flag above**

## Open / unverified items
- Exact API key prefix (only one non-canonical source says `sk-...`; not confirmed by `docs.typesafe.ai`).
- Hard maximum on *number* of questions per request (only a token-budget ceiling is documented).
- Cloudflare's `cached_input_per_1M_tokens: $0.00` (possible cached-input pricing tier) — not corroborated elsewhere.
- Exact launch date: most sources say early access opened **September 15, 2026**; I did not find that exact date restated inside the TypeSafe blog post's own fetched text (the fetch of that page didn't surface a dateline), so treat Sep 15 as well-corroborated-but-not-self-confirmed-on-the-primary-source.
