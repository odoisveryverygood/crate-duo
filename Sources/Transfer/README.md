# WP13: audio transfer

- Drop an audio file from Files onto a pad. The file is copied into
  `Documents/imported/` before the provider's temporary URL expires. Files up
  to two seconds load on that pad. Longer files offer **CHOP 16 into Bank D**
  or **Load on pad**.
- Press **BOUNCE** on the deck to capture four bars from AudioEngine's existing
  master-output tap. The WAV appears in `Documents/bounces/` as a draggable
  chip, with a Share button beside it.
- The AudioEngine hook is limited to a second writer fed by the existing tap.
  `PadGridView` attaches the drop target; `DeckView` displays BounceControl.

Typechecked with the iOS 27.1 Simulator SDK using the Xcode toolchain directly.
Simulator drag and drop remains to be checked on the lead's machine; this Mac's
`simctl` is blocked by the unaccepted Xcode license.
