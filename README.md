# Marvel Cursor Lab

A Windows desktop overlay made with AutoHotkey. Spider-Man hangs at the top of your screen, Iron Man and Captain America stand at the bottom corners, and your mouse buttons trigger Marvel effects.

## Install

1. Install **AutoHotkey v1.1** (this script does not run on v2). Open Command Prompt and run:

   ```
   winget install AutoHotkey.AutoHotkey --version 1.1.37.02
   ```

   Or download v1.1 from https://www.autohotkey.com
2. Download this repository (**Code -> Download ZIP**) and extract it.
3. Keep the folder together. `iron.png`, `spidy.png` and `cap.png` must stay in the **same folder** as the script, and their names must not be changed.
4. Double-click `RainbowCursorTrail.ahk` (or `Start.bat`) to start.
5. Press **Ctrl+Alt+X** to stop.

## Controls

| Action | Effect |
|---|---|
| Hold left click and drag | Spider-Man shoots a web from his free hand to the item; flick it and waves travel up the strand |
| Double left click | Iron Man fires a palm blast or twin DNA-helix missiles |
| Right click | Captain America throws his shield (one at a time) |
| Middle click | Hulk Smash |
| Side button 1 | Doctor Strange portal |
| Side button 2 | Thanos snap |
| Ctrl+Alt+X | Exit |

## Notes

- If an image is missing, a tray notification names the file.
- Character artwork belongs to its respective owners (Marvel / Disney). Replace the PNGs with your own images if you redistribute this.
