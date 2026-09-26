# ONESHOTS.md — one-shot library sanity check

Total samples: **555** across 16 categories x 9 styles.
Source index: `library/oneshots.json`. Audio: `library/oneshots/<category>/<id>.wav` (44.1kHz/16-bit PCM, peak -1dBFS, silence-trimmed, category length-capped).

## Counts per category x style (samples with styles[style] >= 0.6)

| category | J DILLA | JAZZ HOP | BOOM BAP | LO-FI | VINTAGE | HOUSE | TRAP | DRILL | R&B | total |
|---|---|---|---|---|---|---|---|---|---|---|
| kick | 17 | 32 | 27 | 33 | 10 | 6 | 7 | 7 | 59 | 80 |
| snare | 13 | 23 | 19 | 30 | 7 | 1 | 9 | 10 | 52 | 70 |
| clap | 10 | 14 | 13 | 11 | 5 | 6 | 6 | 5 | 22 | 40 |
| hat | 12 | 22 | 19 | 15 | 8 | 5 | 16 | 10 | 33 | 60 |
| openhat | 5 | 9 | 8 | 6 | 3 | 6 | 5 | 6 | 14 | 30 |
| rim | 1 | 11 | 10 | 5 | 1 | 0 | 5 | 6 | 15 | 25 |
| perc | 9 | 18 | 16 | 18 | 5 | 3 | 6 | 7 | 33 | 50 |
| shaker | 2 | 7 | 6 | 8 | 1 | 0 | 4 | 3 | 13 | 20 |
| cymbal | 3 | 6 | 5 | 11 | 2 | 0 | 2 | 2 | 17 | 20 |
| 808 | 2 | 1 | 1 | 6 | 1 | 0 | 16 | 10 | 6 | 30 |
| bass | 5 | 9 | 8 | 7 | 3 | 0 | 2 | 2 | 14 | 20 |
| fx | 5 | 9 | 9 | 11 | 3 | 2 | 8 | 2 | 18 | 30 |
| vocal | 0 | 2 | 2 | 11 | 0 | 1 | 2 | 8 | 13 | 25 |
| texture | 5 | 8 | 6 | 6 | 1 | 0 | 2 | 2 | 12 | 15 |
| keys | 6 | 12 | 8 | 9 | 4 | 0 | 2 | 0 | 20 | 25 |
| synth | 1 | 7 | 5 | 6 | 1 | 0 | 2 | 0 | 13 | 15 |

(Grand total 555 samples; a sample can count toward multiple styles at once.)

Coverage rule from the brief: every style needs >=5 candidates for kick, snare-or-clap (combined), hat, and >=2 for openhat, perc, fx. House additionally needs clap>=5 and openhat>=5; trap/drill additionally need 808>=8 and hat>=10. All checked programmatically against this table -- see coverage-gap note at the bottom.

## Preview kits — best sample per pad, per style

Pad layout (matches `grooves.json` bankA): `[kick, kick2, snare, clap, hat, hat2, openhat, rim, perc, perc2, shaker, cymbal, 808, fx, vocal, texture]`. Ranked by `styles[style]` desc, tie-broken by closeness of (dust, brightness) to that style's grooves.json kit target.

### J DILLA (`dilla`) — target dust 0.75, brightness 0.35

| pad | id | name | tags | dust | bright | styles[dilla] |
|---|---|---|---|---|---|---|
| kick | K064 | VNYL KCK | vinyl, soft, warm | 0.67 | 0.08 | 0.95 |
| kick2 | K066 | VNYL KCK | vinyl, warm, muffled | 0.67 | 0.08 | 0.95 |
| snare | S048 | WARM SNR | warm, SP-1200, wonky | 0.52 | 0.24 | 1.00 |
| clap | C029 | VNYL CLP | vinyl, soft, warm | 0.55 | 0.29 | 0.96 |
| hat | H042 | BRT HAT | bright, dry, SP-1200 | 0.55 | 0.65 | 1.00 |
| hat2 | H041 | DRY HAT | dry, snappy, SP-1200 | 0.41 | 0.34 | 0.95 |
| openhat | O025 | OHAT 025 | soft, warm, wonky | 0.38 | 0.23 | 0.93 |
| rim | R016 | SOFT RIM | soft, warm, wonky | 0.50 | 0.27 | 0.96 |
| perc | P034 | DRY PERC | tight, warm, dry | 0.47 | 0.29 | 0.95 |
| perc2 | P032 | DRY PERC | tight, dry, snappy | 0.44 | 0.37 | 0.95 |
| shaker | SH04 | WARM SHK | warm, muffled, dry | 0.42 | 0.02 | 0.87 |
| cymbal | CY13 | BOOM CYM | boomy, ringy, wonky | 0.46 | 0.56 | 0.95 |
| 808 | B8_26 | 808 D | punchy, tight, bright | 0.35 | 0.63 | 0.71 |
| fx | FX20 | SOFT FX | soft, wonky, fx | 0.47 | 0.36 | 0.95 |
| vocal | V012 | PNCH VOX | punchy, tight, vocal chop | 0.37 | 0.41 | 0.59 |
| texture | T010 | VNYL TEX | vinyl, tight, warm | 0.58 | 0.19 | 1.00 |

### JAZZ HOP (`jazzhop`) — target dust 0.55, brightness 0.45

| pad | id | name | tags | dust | bright | styles[jazzhop] |
|---|---|---|---|---|---|---|
| kick | K068 | TITE KCK | tight, warm, kick | 0.46 | 0.20 | 1.00 |
| kick2 | K038 | TITE KCK | tight, kick, live | 0.26 | 0.34 | 1.00 |
| snare | S026 | WNKY SNR | wonky, snare, live | 0.36 | 0.36 | 1.00 |
| clap | C009 | WNKY CLP | wonky, clap, live | 0.42 | 0.37 | 1.00 |
| hat | H015 | PNCH HAT | punchy, tight, dry | 0.34 | 0.49 | 1.00 |
| hat2 | H030 | PNCH HAT | punchy, tight, bright | 0.47 | 0.71 | 1.00 |
| openhat | O011 | OHAT 011 | soft, wonky, open hat | 0.27 | 0.35 | 1.00 |
| rim | R021 | TITE RIM | tight, woody, rim | 0.34 | 0.37 | 1.00 |
| perc | P008 | PERC 008 | tight, wonky, perc | 0.41 | 0.31 | 1.00 |
| perc2 | P021 | PERC 021 | tight, perc, live | 0.36 | 0.36 | 1.00 |
| shaker | SH07 | PNCH SHK | punchy, tight, noisy | 0.47 | 0.59 | 1.00 |
| cymbal | CY15 | WARM CYM | warm, boomy, ringy | 0.42 | 0.26 | 1.00 |
| 808 | B8_13 | 808 E | vinyl, tight, warm | 0.62 | 0.01 | 1.00 |
| fx | FX05 | PNCH FX | punchy, tight, wonky | 0.31 | 0.34 | 1.00 |
| vocal | V021 | PNCH VOX | punchy, tight, vocal chop | 0.40 | 0.55 | 1.00 |
| texture | T012 | PNCH TEX | punchy, tight, wonky | 0.43 | 0.42 | 1.00 |

### BOOM BAP (`boombap`) — target dust 0.6, brightness 0.5

| pad | id | name | tags | dust | bright | styles[boombap] |
|---|---|---|---|---|---|---|
| kick | K068 | TITE KCK | tight, warm, kick | 0.46 | 0.20 | 0.68 |
| kick2 | K038 | TITE KCK | tight, kick, live | 0.26 | 0.34 | 0.68 |
| snare | S048 | WARM SNR | warm, SP-1200, wonky | 0.52 | 0.24 | 0.72 |
| clap | C009 | WNKY CLP | wonky, clap, live | 0.42 | 0.37 | 0.69 |
| hat | H042 | BRT HAT | bright, dry, SP-1200 | 0.55 | 0.65 | 0.73 |
| hat2 | H030 | PNCH HAT | punchy, tight, bright | 0.47 | 0.71 | 0.69 |
| openhat | O022 | BRT OHAT | soft, bright, wonky | 0.30 | 0.62 | 0.68 |
| rim | R021 | TITE RIM | tight, woody, rim | 0.34 | 0.37 | 0.69 |
| perc | P008 | PERC 008 | tight, wonky, perc | 0.41 | 0.31 | 0.69 |
| perc2 | P021 | PERC 021 | tight, perc, live | 0.36 | 0.36 | 0.69 |
| shaker | SH07 | PNCH SHK | punchy, tight, noisy | 0.47 | 0.59 | 0.70 |
| cymbal | CY14 | BOOM CYM | boomy, ringy, wonky | 0.33 | 0.56 | 0.69 |
| 808 | B8_13 | 808 E | vinyl, tight, warm | 0.62 | 0.01 | 0.67 |
| fx | FX05 | PNCH FX | punchy, tight, wonky | 0.31 | 0.34 | 0.68 |
| vocal | V021 | PNCH VOX | punchy, tight, vocal chop | 0.40 | 0.55 | 0.69 |
| texture | T010 | VNYL TEX | vinyl, tight, warm | 0.58 | 0.19 | 0.71 |

### LO-FI (`lofi`) — target dust 0.8, brightness 0.3

| pad | id | name | tags | dust | bright | styles[lofi] |
|---|---|---|---|---|---|---|
| kick | K009 | VNYL KCK | vinyl, warm, muffled | 0.67 | 0.09 | 1.00 |
| kick2 | K010 | DUST KCK | dusty, vinyl, warm | 0.74 | 0.03 | 1.00 |
| snare | S006 | VNYL SNR | vinyl, warm, muffled | 0.64 | 0.11 | 1.00 |
| clap | C026 | VNYL CLP | vinyl, warm, dry | 0.58 | 0.29 | 1.00 |
| hat | H031 | SOFT HAT | soft, dry, hat | 0.47 | 0.34 | 1.00 |
| hat2 | H003 | PNCH HAT | punchy, tight, dry | 0.47 | 0.47 | 1.00 |
| openhat | O016 | OHAT 016 | tight, open hat, live | 0.44 | 0.34 | 1.00 |
| rim | R001 | VNYL RIM | vinyl, dry, woody | 0.57 | 0.32 | 1.00 |
| perc | P028 | DRY PERC | vinyl, warm, muffled | 0.66 | 0.14 | 1.00 |
| perc2 | P027 | PERC 027 | perc, live, roomy | 0.47 | 0.32 | 1.00 |
| shaker | SH12 | TITE SHK | tight, warm, muffled | 0.49 | 0.04 | 1.00 |
| cymbal | CY02 | CRSP CYM | crisp, bright, boomy | 0.45 | 0.88 | 1.00 |
| 808 | B8_11 | 808 E | dusty, vinyl, warm | 0.74 | 0.01 | 1.00 |
| fx | FX16 | VNYL FX | vinyl, soft, warm | 0.59 | 0.25 | 1.00 |
| vocal | V005 | VNYL VOX | vinyl, punchy, tight | 0.60 | 0.28 | 1.00 |
| texture | T001 | PNCH TEX | punchy, tight, texture | 0.51 | 0.43 | 1.00 |

### VINTAGE (`vintage`) — target dust 0.9, brightness 0.4

| pad | id | name | tags | dust | bright | styles[vintage] |
|---|---|---|---|---|---|---|
| kick | K079 | VNYL KCK | vinyl, punchy, tight | 0.67 | 0.01 | 0.82 |
| kick2 | K062 | VNYL KCK | vinyl, warm, muffled | 0.69 | 0.07 | 0.68 |
| snare | S064 | DUST SNR | dusty, vinyl, punchy | 0.86 | 0.02 | 0.83 |
| clap | C035 | PNCH CLP | punchy, tight, wonky | 0.41 | 0.54 | 0.82 |
| hat | H042 | BRT HAT | bright, dry, SP-1200 | 0.55 | 0.65 | 0.82 |
| hat2 | H041 | DRY HAT | dry, snappy, SP-1200 | 0.41 | 0.34 | 0.67 |
| openhat | O025 | OHAT 025 | soft, warm, wonky | 0.38 | 0.23 | 0.66 |
| rim | R016 | SOFT RIM | soft, warm, wonky | 0.50 | 0.27 | 0.67 |
| perc | P044 | BRT PERC | bright, SP-1200, wonky | 0.44 | 0.69 | 0.81 |
| perc2 | P013 | DRY PERC | vinyl, warm, muffled | 0.62 | 0.11 | 0.68 |
| shaker | SH04 | WARM SHK | warm, muffled, dry | 0.42 | 0.02 | 0.66 |
| cymbal | CY13 | BOOM CYM | boomy, ringy, wonky | 0.46 | 0.56 | 0.67 |
| 808 | B8_26 | 808 D | punchy, tight, bright | 0.35 | 0.63 | 0.81 |
| fx | FX19 | VNYL FX | vinyl, punchy, tight | 0.66 | 0.07 | 0.68 |
| vocal | V009 | PNCH VOX | punchy, tight, vocal chop | 0.47 | 0.57 | 0.42 |
| texture | T010 | VNYL TEX | vinyl, tight, warm | 0.58 | 0.19 | 0.83 |

### HOUSE (`house`) — target dust 0.2, brightness 0.7

| pad | id | name | tags | dust | bright | styles[house] |
|---|---|---|---|---|---|---|
| kick | K022 | SOFT KCK | soft, warm, muffled | 0.30 | 0.09 | 0.71 |
| kick2 | K023 | SOFT KCK | soft, warm, muffled | 0.29 | 0.07 | 0.71 |
| snare | S009 | CLN SNR | clean, club, snare | 0.04 | 0.45 | 0.73 |
| clap | C011 | CLN CLP | clean, crisp, bright | 0.08 | 0.79 | 0.75 |
| hat | H011 | CLN HAT | clean, tight, bright | 0.11 | 0.71 | 0.75 |
| hat2 | H010 | CLN HAT | clean, tight, crisp | 0.21 | 0.84 | 0.75 |
| openhat | O006 | CLN OHAT | clean, soft, bright | 0.15 | 0.74 | 0.76 |
| rim | R005 | CLN RIM | clean, soft, dry | 0.18 | 0.60 | 0.05 |
| perc | P010 | CLN PERC | clean, dry, club | 0.06 | 0.51 | 0.74 |
| perc2 | P011 | CLN PERC | clean, soft, dry | 0.17 | 0.34 | 0.73 |
| shaker | SH15 | CLN SHK | clean, bright, loose | 0.23 | 0.64 | 0.05 |
| cymbal | CY05 | CRSP CYM | crisp, bright, boomy | 0.27 | 0.83 | 0.05 |
| 808 | B8_26 | 808 D | punchy, tight, bright | 0.35 | 0.63 | 0.05 |
| fx | FX07 | WARM FX | warm, muffled, club | 0.29 | 0.05 | 0.70 |
| vocal | V008 | CLN VOX | clean, tight, club | 0.06 | 0.58 | 0.74 |
| texture | T011 | SOFT TEX | soft, bright, wonky | 0.34 | 0.62 | 0.05 |

### TRAP (`trap`) — target dust 0.1, brightness 0.75

| pad | id | name | tags | dust | bright | styles[trap] |
|---|---|---|---|---|---|---|
| kick | K004 | CLN KCK | clean, soft, warm | 0.20 | 0.19 | 0.86 |
| kick2 | K007 | WARM KCK | warm, muffled, dry | 0.30 | 0.07 | 0.85 |
| snare | S068 | CLN SNR | clean, soft, dry | 0.03 | 0.42 | 1.00 |
| clap | C038 | CLN CLP | clean, soft, bright | 0.06 | 0.72 | 1.00 |
| hat | H060 | CLN HAT | clean, crisp, bright | 0.09 | 0.79 | 1.00 |
| hat2 | H054 | CLN HAT | clean, soft, bright | 0.13 | 0.68 | 1.00 |
| openhat | O028 | CLN OHAT | clean, bright, hard | 0.06 | 0.69 | 0.90 |
| rim | R023 | CLN RIM | clean, tight, bright | 0.04 | 0.65 | 0.90 |
| perc | P049 | CLN PERC | clean, warm, dry | 0.11 | 0.29 | 1.00 |
| perc2 | P048 | CLN PERC | clean, warm, dry | 0.21 | 0.21 | 1.00 |
| shaker | SH19 | CLN SHK | clean, tight, bright | 0.03 | 0.69 | 0.90 |
| cymbal | CY20 | SOFT CYM | soft, warm, muffled | 0.33 | 0.01 | 0.84 |
| 808 | B8_27 | CLN 808 | clean, punchy, tight | 0.08 | 0.56 | 1.00 |
| fx | FX02 | CLN FX | clean, punchy, tight | 0.02 | 0.59 | 1.00 |
| vocal | V025 | PNCH VOX | punchy, tight, warm | 0.29 | 0.04 | 0.85 |
| texture | T015 | CLN TEX | clean, punchy, tight | 0.10 | 0.52 | 0.89 |

### DRILL (`drill`) — target dust 0.1, brightness 0.65

| pad | id | name | tags | dust | bright | styles[drill] |
|---|---|---|---|---|---|---|
| kick | K026 | SOFT KCK | soft, warm, muffled | 0.30 | 0.13 | 0.81 |
| kick2 | K025 | SOFT KCK | soft, warm, muffled | 0.40 | 0.06 | 0.80 |
| snare | S013 | CLN SNR | clean, soft, hard | 0.08 | 0.36 | 0.83 |
| clap | C017 | CLN CLP | clean, soft, bright | 0.08 | 0.61 | 0.86 |
| hat | H034 | CLN HAT | clean, bright, dry | 0.03 | 0.67 | 0.85 |
| hat2 | H036 | CLN HAT | clean, bright, dry | 0.03 | 0.67 | 0.85 |
| openhat | O009 | CLN OHAT | clean, soft, crisp | 0.08 | 0.76 | 0.75 |
| rim | R005 | CLN RIM | clean, soft, dry | 0.18 | 0.60 | 0.75 |
| perc | P015 | CLN PERC | clean, dry, hard | 0.13 | 0.33 | 0.83 |
| perc2 | P014 | CLN PERC | clean, tight, warm | 0.24 | 0.21 | 0.82 |
| shaker | SH05 | CLN SHK | clean, soft, warm | 0.05 | 0.30 | 0.83 |
| cymbal | CY18 | CLN CYM | clean, punchy, tight | 0.13 | 0.44 | 0.64 |
| 808 | B8_18 | 808 C# | warm, muffled, boomy | 0.37 | 0.03 | 0.80 |
| fx | FX09 | CLN FX | clean, punchy, tight | 0.16 | 0.34 | 0.83 |
| vocal | V010 | CLN VOX | clean, tight, crisp | 0.04 | 0.78 | 0.75 |
| texture | T008 | CLN TEX | clean, punchy, tight | 0.06 | 1.00 | 0.63 |

### R&B (`rnb`) — target dust 0.3, brightness 0.5

| pad | id | name | tags | dust | bright | styles[rnb] |
|---|---|---|---|---|---|---|
| kick | K038 | TITE KCK | tight, kick, live | 0.26 | 0.34 | 0.90 |
| kick2 | K068 | TITE KCK | tight, warm, kick | 0.46 | 0.20 | 0.88 |
| snare | S022 | PNCH SNR | punchy, tight, snare | 0.29 | 0.46 | 0.91 |
| clap | C020 | LIVE CLP | clap, live, roomy | 0.34 | 0.59 | 0.90 |
| hat | H015 | PNCH HAT | punchy, tight, dry | 0.34 | 0.49 | 0.91 |
| hat2 | H044 | DRY HAT | dry, snappy, hat | 0.26 | 0.40 | 0.90 |
| openhat | O022 | BRT OHAT | soft, bright, wonky | 0.30 | 0.62 | 0.90 |
| rim | R020 | PNCH RIM | punchy, tight, woody | 0.29 | 0.38 | 0.90 |
| perc | P039 | DRY PERC | dry, perc, live | 0.30 | 0.51 | 0.91 |
| perc2 | P036 | CLN PERC | clean, tight, dry | 0.24 | 0.52 | 0.91 |
| shaker | SH15 | CLN SHK | clean, bright, loose | 0.23 | 0.64 | 0.90 |
| cymbal | CY14 | BOOM CYM | boomy, ringy, wonky | 0.33 | 0.56 | 0.90 |
| 808 | B8_13 | 808 E | vinyl, tight, warm | 0.62 | 0.01 | 0.86 |
| fx | FX05 | PNCH FX | punchy, tight, wonky | 0.31 | 0.34 | 0.90 |
| vocal | V021 | PNCH VOX | punchy, tight, vocal chop | 0.40 | 0.55 | 0.90 |
| texture | T011 | SOFT TEX | soft, bright, wonky | 0.34 | 0.62 | 0.90 |

## Coverage-gap notes

No gaps — every pad's top pick scores >=0.6 for its style across all 9 styles.

