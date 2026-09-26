#!/usr/bin/env python3
"""Curated selection manifest for the melodic-loop library.

Each entry: (rel_path, instrument, pack_key, bpm, key_or_None, name_override_or_None)
rel_path is relative to ~/Documents (READ-ONLY source root).
key strings are as printed by the pack maker; normalize_key() in pipeline.py
converts to the canonical "Am"/"F#"/"Ebm" style.
pack_key indexes PACK_STYLE_PRIOR (base style weights, further nudged by audio
features in the pipeline).
"""

FJ1 = "Jazz Hop合集/Freddie Joachim Jazz Hop/FJ_WAV_LOOPS"
TSJ = "Jazz Hop合集/True Samples 100 Jazz"
SM1 = "Jazz Hop合集/Sample Magic Jazz Hop 1"
MHTN = "Jazz Hop合集/Manhattan Jazz Hop/_Melodic_Loops"
MHTN_DRUM = "Jazz Hop合集/Manhattan Jazz Hop/_Drum_Loops"
RVNJ = "Jazz Hop合集/RV Nu Jazz Hip Hop Rhodes/HHP_WAV_LOOPS"
JHB2 = "Jazz Hop合集/Jazzadelic DMS Hip Hop 2/JHB2_Musical_Loops"
SNS = "Jazz Hop合集/Supply Modal Jazz Hop"
VHH = "Jazz Hop合集/16 Vintage Hip Hop Kits/Vintage Hip Hop Kits/Loops"

BBL = "LofiHiphop超值合集/Bedroom Lofi Hip Hop 1/Melodic_Loops/Lofi_Piano___Keys"
PMDH_KEY = "LofiHiphop超值合集/Melancholic Lofi/Key Loops"
PMDH_DRUM = "LofiHiphop超值合集/Melancholic Lofi/Drum Loops/Full Drum Loops"

CYM_HOUSE = "cymatics/Cymatics - House Starter Pack"
CYM_COBRA = "cymatics/Cymatics - Cobra Hip Hop Sample Pack/Melodics"
CYM_ETERN = "cymatics/Cymatics - Eternity Sample Pack/Melodics"
CYM_ORACLE = "cymatics/Cymatics - Oracle Sample Pack/Melodies"

# (rel_path, instrument, pack_key, bpm, key, name_override)
SELECTION = [
    # ---------------- PIANO / KEYS (jazzhop, Nujabes/Freddie-Joachim style) ----------------
    (f"{FJ1}/FJ_KEYS_&_SYNTHS_LOOPS/FJ_92_C_Grand_Piano.wav", "piano", "freddie", 92, "C", None),
    (f"{FJ1}/FJ_KEYS_&_SYNTHS_LOOPS/FJ_95_Cm_Grand_Piano_Jazz.wav", "piano", "freddie", 95, "Cm", "NUJ JAZZ"),
    (f"{FJ1}/FJ_KEYS_&_SYNTHS_LOOPS/FJ_96_Dm_Grand_Piano_Dreamy.wav", "piano", "freddie", 96, "Dm", "DREA PNO"),
    (f"{FJ1}/FJ_KEYS_&_SYNTHS_LOOPS/FJ_93_C#m_Piano_Sombre.wav", "piano", "freddie", 93, "C#m", "SOMB PNO"),
    (f"{FJ1}/FJ_KEYS_&_SYNTHS_LOOPS/FJ_95_Cm_Piano_Beefy.wav", "piano", "freddie", 95, "Cm", None),
    (f"{FJ1}/FJ_KEYS_&_SYNTHS_LOOPS/FJ_94_D#m_Rolling_Piano_Note.wav", "piano", "freddie", 94, "D#m", None),
    (f"{FJ1}/FJ_KEYS_&_SYNTHS_LOOPS/FJ_100_C#m_Kalimba.wav", "keys", "freddie", 100, "C#m", None),
    (f"{FJ1}/FJ_KEYS_&_SYNTHS_LOOPS/FJ_95_G_Organ_Rotary.wav", "keys", "freddie", 95, "G", None),
    (f"{FJ1}/FJ_KEYS_&_SYNTHS_LOOPS/FJ_90_Dbm_Moog_Chords.wav", "keys", "freddie", 90, "Dbm", None),
    (f"{TSJ}/_PIANO_LOOPS/TSJ_115_B_Piano_Loop_5.wav", "piano", "truesamples", 115, "B", None),
    (f"{TSJ}/_PIANO_LOOPS/TSJ_115_B_Piano_Loop_23.wav", "piano", "truesamples", 115, "B", None),
    (f"{TSJ}/_PIANO_LOOPS/TSJ_115_Bb_Piano_Loop_40.wav", "piano", "truesamples", 115, "Bb", None),
    (f"{SM1}/piano_&_keys_loops/jh_keys_piano_smoke_80_Cm.wav", "piano", "samplemagic", 80, "Cm", "SMOK PNO"),
    (f"{SM1}/piano_&_keys_loops/jh_keys_piano_you_80_G#m.wav", "piano", "samplemagic", 80, "G#m", None),
    (f"{SM1}/piano_&_keys_loops/jh_keys_piano_pepper_90_Em.wav", "piano", "samplemagic", 90, "Em", None),
    (f"{SM1}/piano_&_keys_loops/jh_keys_organ_dream_90_F#m.wav", "keys", "samplemagic", 90, "F#m", None),
    (f"{MHTN}/MHTN Grand Piano Melodic Loop 100BPM.wav", "piano", "manhattan", 100, None, None),
    (f"{VHH}/Keys/Piano/KKJH_Piano_87BPM_D_LifesGood.wav", "piano", "vintagekits", 87, "D", "LIFE PNO"),
    (f"{VHH}/Keys/Piano/KKJH_Piano_85BPM_F#m_Cafe.wav", "piano", "vintagekits", 85, "F#m", None),
    (f"{JHB2}/JHB2_Keys_Loops/JHB2_95_Am_Wine_Piano_1.wav", "piano", "jazzadelic", 95, "Am", None),
    (f"{JHB2}/JHB2_Keys_Loops/JHB2_70_Am_Mystic_Piano_Solo_2.wav", "piano", "jazzadelic", 70, "Am", None),
    (f"{JHB2}/JHB2_Keys_Loops/JHB2_75_Dm_Powell_Piano_1.wav", "piano", "jazzadelic", 75, "Dm", "POWL PNO"),
    (f"{SNS}/Melodic_Loops/Piano/SNS_MH_97_piano_diner_at_dusk_Cm.wav", "piano", "supplymodal", 97, "Cm", None),
    (f"{SNS}/Melodic_Loops/Piano/SNS_MH_100_piano_breaker_grouped_Cm.wav", "piano", "supplymodal", 100, "Cm", None),
    (f"{SNS}/Melodic_Loops/Piano/SNS_MH_85_piano_moody_overhead_G#m.wav", "piano", "supplymodal", 85, "G#m", None),
    (f"{SNS}/Melodic_Loops/Piano/SNS_MH_96_piano_creaky_feet_back_Cm.wav", "piano", "supplymodal", 96, "Cm", None),

    # ---------------- RHODES / EP ----------------
    (f"{FJ1}/FJ_KEYS_&_SYNTHS_LOOPS/FJ_89_Bm_Rhodes_Dream.wav", "rhodes", "freddie", 89, "Bm", None),
    (f"{FJ1}/FJ_KEYS_&_SYNTHS_LOOPS/FJ_89_Fm_Rhodes_Lead.wav", "rhodes", "freddie", 89, "Fm", None),
    (f"{FJ1}/FJ_KEYS_&_SYNTHS_LOOPS/FJ_97_A_Ethereal_Rhodes.wav", "rhodes", "freddie", 97, "A", None),
    (f"{FJ1}/FJ_KEYS_&_SYNTHS_LOOPS/FJ_96_Db_Rhodes_Stabs.wav", "rhodes", "freddie", 96, "Db", None),
    (f"{RVNJ}/HHP_KEYS_LOOPS_95_BPM/HHP_95_F_Electric_Piano_3.wav", "rhodes", "rvnujazz", 95, "F", None),
    (f"{RVNJ}/HHP_KEYS_LOOPS_95_BPM/HHP_95_Eb_Electric_Piano_2.wav", "rhodes", "rvnujazz", 95, "Eb", None),
    (f"{RVNJ}/HHP_KEYS_LOOPS_80_BPM/HHP_80_G_Electric_Piano_2.wav", "rhodes", "rvnujazz", 80, "G", None),
    (f"{CYM_ETERN}/E-Piano/Cymatics - Eternity E Piano 4 - 85 BPM D Min.wav", "rhodes", "eternity_eppiano", 85, "D Min", None),
    (f"{CYM_ETERN}/E-Piano/Cymatics - Eternity E Piano 9 - 87 BPM F Min.wav", "rhodes", "eternity_eppiano", 87, "F Min", None),
    (f"{JHB2}/JHB2_Keys_Loops/JHB2_100_Cmaj_Bebop_Rhodes.wav", "rhodes", "jazzadelic", 100, "Cmaj", None),
    (f"{JHB2}/JHB2_Keys_Loops/JHB2_85_Am_Birdland_Rhodes_2.wav", "rhodes", "jazzadelic", 85, "Am", None),
    (f"{SNS}/Melodic_Loops/Keys/SNS_MH_90_rhodes_neo_soul_Fm.wav", "rhodes", "supplymodal", 90, "Fm", None),

    # ---------------- GUITAR ----------------
    (f"{FJ1}/FJ_GUITAR_LOOPS/FJ_92_G#m_Ac_Guitar.wav", "guitar", "freddie", 92, "G#m", None),
    (f"{FJ1}/FJ_GUITAR_LOOPS/FJ_98_Bmaj_Ac_Guitar.wav", "guitar", "freddie", 98, "Bmaj", None),
    (f"{FJ1}/FJ_GUITAR_LOOPS/FJ_100_A_Strummed_Elec_Guitar.wav", "guitar", "freddie", 100, "A", None),
    (f"{SM1}/guitar_loops/jh_guitar_acoustic_loop_cloud_90_Bm.wav", "guitar", "samplemagic", 90, "Bm", None),
    (f"{SM1}/guitar_loops/jh_guitar_electric_loop_lazy_90_F#m.wav", "guitar", "samplemagic", 90, "F#m", None),
    (f"{MHTN}/MHTN Guitar Melodic 78BPM F Major.wav", "guitar", "manhattan", 78, "F Major", None),
    (f"{SNS}/Melodic_Loops/Guitar/SNS_MH_90_guitar_breau_C#m.wav", "guitar", "supplymodal", 90, "C#m", None),
    (f"{CYM_HOUSE}/Instruments - Loops/Guitar Loops/Cymatics - Moonlight Guitar Loop 13 - 128 BPM F Maj.wav", "guitar", "housepack", 128, "F Maj", None),
    (f"{VHH}/Guitars/KKJH_Guitar_93BPM_Am_Sundays.wav", "guitar", "vintagekits", 93, "Am", None),

    # ---------------- STRINGS / PADS / VIBES / FLUTE / HORNS / SAX ----------------
    (f"{FJ1}/FJ_HORN_&_FLUTE_LOOPS/FJ_100_D_Flute.wav", "flute", "freddie", 100, "D", None),
    (f"{FJ1}/FJ_HORN_&_FLUTE_LOOPS/FJ_92_Dm_Tenor_Sax.wav", "sax", "freddie", 92, "Dm", None),
    (f"{FJ1}/FJ_STRING_&_PAD_LOOPS/FJ_85_Bm_String_Pads_High_Wire.wav", "pad", "freddie", 85, "Bm", None),
    (f"{FJ1}/FJ_STRING_&_PAD_LOOPS/FJ_94_Ab_String_Notes.wav", "strings", "freddie", 94, "Ab", None),
    (f"{TSJ}/_STRINGS_LOOPS/TSJ_115_B_String_Loop_9.wav", "strings", "truesamples", 115, "B", None),
    (f"{SM1}/saxophone_&_trumpet_loops/jh_saxophone_loop_amelie_80_C#m.wav", "sax", "samplemagic", 80, "C#m", None),
    (f"{VHH}/Brass & Woodwind/Saxophone/KKJH_Saxophone_85BPM_A_Cafe.wav", "sax", "vintagekits", 85, "A", None),

    # ---------------- LOFI KEYS ----------------
    (f"{BBL}/BBL_75_lofi_piano_lakeside_Cm.wav", "keys", "bedroomlofi", 75, "Cm", None),
    (f"{BBL}/BBL_75_lofi_keys_dougal_Dm.wav", "keys", "bedroomlofi", 75, "Dm", None),
    (f"{PMDH_KEY}/PMDH_Key_Loop_10_Cmin_80.wav", "keys", "melancholiclofi", 80, "Cmin", None),
    (f"{PMDH_KEY}/PMDH_Key_Loop_58_Emin_80.wav", "keys", "melancholiclofi", 80, "Emin", None),
    (f"{JHB2}/JHB2_Keys_Loops/JHB2_100_Am_Waves_Piano_2_LOFI.wav", "keys", "jazzadelic_lofi", 100, "Am", None),
    (f"{JHB2}/JHB2_Keys_Loops/JHB2_70_Fm_Glasper_Keys_3_LOFI.wav", "keys", "jazzadelic_lofi", 70, "Fm", None),

    # ---------------- VINTAGE DRUM BREAKS (key = null) ----------------
    (f"{VHH}/Drums/Full/KKJH_Drums_Full_93BPM_Sundays.wav", "break", "vintagekits", 93, None, "SUN BRK"),
    (f"{VHH}/Drums/Full/KKJH_Drums_Full_87BPM_D_LifesGood.wav", "break", "vintagekits", 87, None, "LIFE BRK"),
    (f"{VHH}/Drums/Full/KKJH_Drums_Full_85BPM_Cafe.wav", "break", "vintagekits", 85, None, "CAFE BRK"),
    (f"{FJ1}/FJ_LIVE_DRUM_LOOPS/FJ_88_Live_Drums_01.wav", "break", "freddie", 88, None, None),
    (f"{FJ1}/FJ_LIVE_DRUM_LOOPS/FJ_92_Live_Drums_07.wav", "break", "freddie", 92, None, None),
    (f"{FJ1}/FJ_LIVE_DRUM_LOOPS/FJ_94_Live_Drums_11.wav", "break", "freddie", 94, None, None),
    (f"{TSJ}/_DRUM_LOOPS/TSJ_115_Drum_Loop_3.wav", "break", "truesamples", 115, None, None),
    (f"{SNS}/Drum_and_Perc_Loops/Full_Loops/SNS_MH_85_drum_loop_heavy_nod.wav", "break", "supplymodal", 85, None, "HVY NOD"),
    (f"{PMDH_DRUM}/PMDH_Full_Drum_Loop_05_80.wav", "break", "melancholiclofi", 80, None, None),

    # ---------------- HOUSE CHORDS / STABS ----------------
    (f"{CYM_HOUSE}/Synths - Loops/Chord Loops/Cymatics - House Chord Loop 1 - 128 BPM C# Min.wav", "pad", "housepack", 128, "C# Min", None),
    (f"{CYM_HOUSE}/Synths - Loops/Chord Loops/Cymatics - House Chord Loop 4 - 128 BPM G Min.wav", "pad", "housepack", 128, "G Min", None),
    (f"{CYM_HOUSE}/Synths - Loops/Chord Loops/Cymatics - Soft Chord Loop 1 - 128 BPM Cmin.wav", "pad", "housepack", 128, "Cmin", None),
    (f"{CYM_HOUSE}/Instruments - Loops/Piano Loops/Cymatics - House Piano Loop 2 - 128 BPM E Min.wav", "piano", "housepack", 128, "E Min", None),

    # ---------------- TRAP / RNB MELODIC ----------------
    (f"{CYM_COBRA}/Melody Loops/Cymatics - Cobra Melody Loop 4 - 110 BPM E Min.wav", "keys", "cobra", 110, "E Min", None),
    (f"{CYM_COBRA}/Melody Loops/Cymatics - Cobra Melody Loop 7 - 128 BPM D Min.wav", "keys", "cobra", 128, "D Min", None),
    (f"{CYM_ETERN}/Loops/Classic/Cymatics - Eternity Classic Melody Loop 8 - 130 BPM D Min.wav", "keys", "eternity_classic", 130, "D Min", None),
    (f"{CYM_ETERN}/Loops/Lofi/Cymatics - Eternity Lofi Melody Loop 11 - 92 BPM A# Maj.wav", "keys", "eternity_lofi", 92, "A# Maj", None),
    (f"{CYM_ORACLE}/Cymatics - Oracle Lofi Melody Loop 2 - 82 BPM D Maj.wav", "keys", "oracle_lofi", 82, "D Maj", None),
]

# base style priors: dilla, jazzhop, boombap, lofi, vintage, house, trap, drill, rnb
PACK_STYLE_PRIOR = {
    "freddie":          dict(dilla=0.65, jazzhop=0.90, boombap=0.45, lofi=0.30, vintage=0.45, house=0.00, trap=0.00, drill=0.00, rnb=0.15),
    "truesamples":      dict(dilla=0.40, jazzhop=0.75, boombap=0.50, lofi=0.25, vintage=0.50, house=0.00, trap=0.00, drill=0.00, rnb=0.10),
    "samplemagic":      dict(dilla=0.50, jazzhop=0.80, boombap=0.50, lofi=0.35, vintage=0.35, house=0.00, trap=0.00, drill=0.00, rnb=0.15),
    "manhattan":        dict(dilla=0.55, jazzhop=0.75, boombap=0.50, lofi=0.30, vintage=0.40, house=0.00, trap=0.00, drill=0.00, rnb=0.20),
    "rvnujazz":         dict(dilla=0.50, jazzhop=0.80, boombap=0.40, lofi=0.25, vintage=0.35, house=0.00, trap=0.00, drill=0.00, rnb=0.25),
    "jazzadelic":       dict(dilla=0.50, jazzhop=0.85, boombap=0.45, lofi=0.40, vintage=0.35, house=0.00, trap=0.00, drill=0.00, rnb=0.20),
    "jazzadelic_lofi":  dict(dilla=0.45, jazzhop=0.70, boombap=0.40, lofi=0.75, vintage=0.35, house=0.00, trap=0.00, drill=0.00, rnb=0.20),
    "supplymodal":      dict(dilla=0.55, jazzhop=0.80, boombap=0.50, lofi=0.30, vintage=0.40, house=0.00, trap=0.00, drill=0.00, rnb=0.25),
    "vintagekits":      dict(dilla=0.60, jazzhop=0.55, boombap=0.85, lofi=0.25, vintage=0.90, house=0.00, trap=0.00, drill=0.00, rnb=0.15),
    "bedroomlofi":      dict(dilla=0.35, jazzhop=0.45, boombap=0.30, lofi=0.90, vintage=0.30, house=0.00, trap=0.00, drill=0.00, rnb=0.15),
    "melancholiclofi":  dict(dilla=0.30, jazzhop=0.35, boombap=0.30, lofi=0.90, vintage=0.25, house=0.00, trap=0.00, drill=0.00, rnb=0.10),
    "housepack":        dict(dilla=0.00, jazzhop=0.05, boombap=0.00, lofi=0.00, vintage=0.05, house=0.95, trap=0.10, drill=0.00, rnb=0.10),
    "cobra":            dict(dilla=0.10, jazzhop=0.15, boombap=0.20, lofi=0.15, vintage=0.10, house=0.00, trap=0.70, drill=0.35, rnb=0.35),
    "eternity_classic": dict(dilla=0.15, jazzhop=0.20, boombap=0.20, lofi=0.15, vintage=0.15, house=0.05, trap=0.55, drill=0.25, rnb=0.40),
    "eternity_lofi":    dict(dilla=0.30, jazzhop=0.40, boombap=0.30, lofi=0.70, vintage=0.30, house=0.00, trap=0.25, drill=0.05, rnb=0.30),
    "eternity_eppiano": dict(dilla=0.45, jazzhop=0.60, boombap=0.35, lofi=0.35, vintage=0.35, house=0.00, trap=0.15, drill=0.00, rnb=0.35),
    "oracle":           dict(dilla=0.10, jazzhop=0.15, boombap=0.15, lofi=0.20, vintage=0.10, house=0.05, trap=0.65, drill=0.40, rnb=0.30),
    "oracle_lofi":      dict(dilla=0.30, jazzhop=0.40, boombap=0.30, lofi=0.70, vintage=0.30, house=0.00, trap=0.20, drill=0.05, rnb=0.30),
}

if __name__ == "__main__":
    print("total selected:", len(SELECTION))
    from collections import Counter
    print(Counter(s[1] for s in SELECTION))
    print(Counter(s[2] for s in SELECTION))
