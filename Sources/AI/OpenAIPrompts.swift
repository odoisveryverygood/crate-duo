import Foundation

/// System prompt + strict JSON schema from ai/openai-arrange.md (generated verbatim).
enum OpenAIPrompts {
    static let system = #"""
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
"""#

    static let schemaJSON = #"""
{
 "type": "object",
 "additionalProperties": false,
 "required": [
  "title",
  "comment",
  "bpm",
  "swing",
  "drums",
  "bass",
  "chops"
 ],
 "properties": {
  "title": {
   "type": "string",
   "description": "<=24 chars uppercase display name"
  },
  "comment": {
   "type": "string",
   "description": "<=48 chars, what you did"
  },
  "bpm": {
   "type": "integer",
   "description": "60-160"
  },
  "swing": {
   "type": "integer",
   "description": "MPC swing percent 50-70"
  },
  "drums": {
   "type": "array",
   "items": {
    "type": "object",
    "additionalProperties": false,
    "required": [
     "lane",
     "bars",
     "late"
    ],
    "properties": {
     "lane": {
      "type": "string",
      "enum": [
       "kick",
       "kick2",
       "snare",
       "clap",
       "hat",
       "hat2",
       "openhat",
       "rim",
       "perc",
       "perc2",
       "shaker",
       "cymbal"
      ]
     },
     "bars": {
      "type": "array",
      "items": {
       "type": "string",
       "description": "exactly 16 chars of X x g r ."
      }
     },
     "late": {
      "type": "number",
      "description": "-0.3..0.4 fractions of a 16th"
     }
    }
   }
  },
  "bass": {
   "type": "array",
   "items": {
    "type": "object",
    "additionalProperties": false,
    "required": [
     "bar",
     "step",
     "len",
     "midi",
     "vel"
    ],
    "properties": {
     "bar": {
      "type": "integer",
      "description": "0-based bar index"
     },
     "step": {
      "type": "integer",
      "description": "0-15"
     },
     "len": {
      "type": "number",
      "description": "length in steps"
     },
     "midi": {
      "type": "integer",
      "description": "28-52"
     },
     "vel": {
      "type": "integer",
      "description": "1-127"
     }
    }
   }
  },
  "chops": {
   "type": [
    "array",
    "null"
   ],
   "items": {
    "type": "object",
    "additionalProperties": false,
    "required": [
     "bar",
     "step",
     "slice",
     "len"
    ],
    "properties": {
     "bar": {
      "type": "integer"
     },
     "step": {
      "type": "integer"
     },
     "slice": {
      "type": "integer",
      "description": "0-15"
     },
     "len": {
      "type": "number",
      "description": "steps to play before choking"
     }
    }
   }
  }
 }
}
"""#

    static var schema: [String: Any] {
        ((try? JSONSerialization.jsonObject(with: Data(schemaJSON.utf8))) as? [String: Any]) ?? [:]
    }
}
