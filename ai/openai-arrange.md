# OpenAI "arranger" prompt (System 2) — prompt/config data

Called in the background right after the instant Jev plan has already filled the pads and started the groove.
Result is swapped in on the next bar boundary. Also used for "change_groove" / "bass_only" requests and the FLIP button.

- API: Responses API `POST https://api.openai.com/v1/responses`, `Authorization: Bearer $OPENAI_API_KEY`
- Models (verified 2026-09-26 on the user's key): **`gpt-6-luna` + `reasoning:{effort:"none"}` = 3.8 s** for this exact prompt (default for arrange). **`gpt-6-sol` + effort none = 7.2 s** (FLIP / deeper rewrites). `gpt-6-astra` + low = 22 s (too slow for live). All returned valid strict-schema JSON with 16-char bar strings.
- `text.format = {type: "json_schema", name: "arrangement", strict: true, schema: <below>}`
- Compact output on purpose (step strings, not per-hit objects): about 300-600 output tokens, which keeps it at roughly 2-4 s.

## System prompt

```
You are the arranger inside a hardware groovebox (MPC-style sampler). You write drum patterns and basslines that sit under a chopped sample. Output only the JSON object defined by the schema.

Grid: 16 steps per bar (16th notes). Drum lanes are written per bar as 16-character strings:
  X = accent hit, x = normal hit, g = ghost (quiet), r = ratchet (two 32nd notes), . = rest
Each lane has "late": a push/pull in fractions of a 16th (+ = behind the beat, - = ahead). Dilla: snare +0.15..+0.3, hats loose; boom bap: near 0; house/trap/drill: 0.

Rules:
- Keep the groove's backbone from the provided template (kick/snare placement) unless the request asks to change it. Vary hats/percussion and the last bar of the phrase.
- Leave space for the sample: fewer hits where the sample is busy.
- Bass: MIDI 28-52. Land on the chord root (chordsPerBar, else bassPerBeat, else the key's tonic) on or near beat 1 of each bar; use fifths/octaves and approach notes into the next bar's root; rhythmically lock with the kick. Dilla/jazz hop: warm, sparse, slides of feel; house: offbeat root pulses; trap/drill: 808 follows the kick, long notes.
- chops: only when asked to FLIP the sample: re-sequence its 16 slices (0-15) into a new, musical phrase (repeat slices, stutter, reverse phrase order); otherwise null.
- title: <= 24 chars, uppercase, like a hardware display. comment: <= 48 chars, lowercase, what you did.
```

## User message template (JSON)

```json
{
  "request": "generate me a 4 bar loop with a j dilla laid back drum and a killer nujabes type piano sample",
  "style": "dilla", "sampleStyle": "jazzhop",
  "bpm": 89, "swing": 56, "bars": 4,
  "laidback": 0.85, "energy": 0.5,
  "lanesAvailable": ["kick","kick2","snare","clap","hat","hat2","openhat","rim","perc","perc2","shaker","cymbal"],
  "template": { "kick": ["X......x..X.....", "X.....x...X..x.."], "snare": ["....X.......X...", "....X.......X..g"], "hat": ["x.x.x.x.x.x.x.xg", "x.x.x.x.x.x.x.x."] },
  "sample": { "name": "NUJ KEYS", "instrument": "piano", "key": "Am", "bars": 4, "chordsPerBar": ["Am9","Dm9","G13","Cmaj9"], "bassPerBeat": [45,45,45,45,50,50,50,50,43,43,43,43,48,48,48,48] },
  "flip": false
}
```

## JSON schema (strict)

```json
{
  "type": "object",
  "additionalProperties": false,
  "required": ["title", "comment", "bpm", "swing", "drums", "bass", "chops"],
  "properties": {
    "title":   { "type": "string", "description": "<=24 chars uppercase display name" },
    "comment": { "type": "string", "description": "<=48 chars, what you did" },
    "bpm":     { "type": "integer", "description": "60-160" },
    "swing":   { "type": "integer", "description": "MPC swing percent 50-70" },
    "drums": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["lane", "bars", "late"],
        "properties": {
          "lane": { "type": "string", "enum": ["kick","kick2","snare","clap","hat","hat2","openhat","rim","perc","perc2","shaker","cymbal"] },
          "bars": { "type": "array", "items": { "type": "string", "description": "exactly 16 chars of X x g r ." } },
          "late": { "type": "number", "description": "-0.3..0.4 fractions of a 16th" }
        }
      }
    },
    "bass": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["bar", "step", "len", "midi", "vel"],
        "properties": {
          "bar":  { "type": "integer", "description": "0-based bar index" },
          "step": { "type": "integer", "description": "0-15" },
          "len":  { "type": "number",  "description": "length in steps" },
          "midi": { "type": "integer", "description": "28-52" },
          "vel":  { "type": "integer", "description": "1-127" }
        }
      }
    },
    "chops": {
      "type": ["array", "null"],
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["bar", "step", "slice", "len"],
        "properties": {
          "bar":   { "type": "integer" },
          "step":  { "type": "integer" },
          "slice": { "type": "integer", "description": "0-15" },
          "len":   { "type": "number", "description": "steps to play before choking" }
        }
      }
    }
  }
}
```

## Parsing rules for the app
- Velocity map: X=118, x=92, g=44, r=2 hits at 86 (ratchet 2).
- Reject/repair: strings not 16 chars (pad with '.' / truncate), midi clamp 28-52, bar >= requested bars dropped.
- If the call fails or takes > 6 s: keep the instant template + rule-based bassline (grooves.json bassRhythms); nothing breaks.
