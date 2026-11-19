# Azimuth for Mac

Experimental, not linked to official studios.

A Mac app that sets up and launches the Windows build of **Azimuth** (by Almost There Games)
on Apple Silicon. Azimuth itself is not modified: this app installs it into a private Windows
environment and runs it through Apple's **Game Porting Toolkit** (Wine plus D3DMetal, which turns
Direct3D 12 into Metal).

> **Not a native port.** Azimuth is closed-source and runs Windows-format game code, so a true
> macOS binary needs Almost There Games' source. This app is the practical route until then.

## What you need

| Requirement | Notes |
|---|---|
| Apple Silicon Mac, macOS 14 or later | 16 GB of memory is the practical minimum |
| [Homebrew](https://brew.sh) | Used once, to install the toolkit |
| Apple's Game Porting Toolkit disk image | Free download with an Apple ID from [developer.apple.com/games](https://developer.apple.com/games/game-porting-toolkit/). D3DMetal is only distributed by Apple. |
| Your own copy of the game | The folder that contains `Mount` |
| Xcode command line tools | To build the app (`xcode-select --install`) |

## Build and run

```sh
cd mac
scripts/build-app.sh                  # builds "build/Azimuth for Mac.app" with azimuth-windows.zip inside
open "build/Azimuth for Mac.app"
```

The app opens on a **Setup** checklist. Each row turns green when done:

1. **Rosetta 2**: runs the Intel-only toolkit.
2. **Game Porting Toolkit**: installs `gcenx/wine/game-porting-toolkit` with Homebrew (or *Locate…* an existing copy).
3. **D3DMetal**: *Download from Apple*, then *Add from disk image…* and pick the `.dmg` you downloaded.
4. **Wine prefix**: a private Windows environment under `~/Library/Application Support/Azimuth for Mac`.
5. **Shader compiler**: downloads Microsoft's `d3dcompiler_47.dll`, which Azimuth needs.
6. **Azimuth**: unpacks the bundled `azimuth-windows.zip` into the prefix.
7. **Game folder**: pick the folder that holds `Mount`.

When every row is green the app switches to **Play**.

## Under the hood

Settings the app applies, taken from messages inside `azimuth.exe`:

- `WINEDLLOVERRIDES=msvcr110,msvcp110,d3dcompiler_47=n`. Azimuth hash-checks its private Visual C++ runtime and asks for exactly this under Proton.
- The game folder is shown to Windows as `G:\` (Azimuth warns about long paths) and written to `game_folder` under `[launcher]` in `azimuth.ini`. Other lines in that file are left untouched.
- `ROSETTA_ADVERTISE_AVX=1`, because Azimuth checks CPU features.
- `WINEMSYNC=1` and `WINEESYNC=1` for faster synchronisation.

Logs go to `~/Library/Application Support/Azimuth for Mac/logs/`. When Azimuth exits, the app reads
them and explains known failures in plain English.

## Known limits

Azimuth needs Direct3D 12 features that Apple's translation layer may not provide:

- feature level 11_0 with `ID3D12Device3`
- heaps opened over existing memory (`OpenExistingHeapFromAddress`)
- resource binding tier 3

If one is missing, Azimuth stops with "Your graphics card or driver is not supported", and this app
names the missing feature. **This has not yet been run on a real Mac**, so that is the main open question.
If you hit it, please open an issue with the session log.

## Troubleshooting

| Symptom | What to do |
|---|---|
| "Wine could not load Direct3D 12" | D3DMetal is missing. Redo setup step 3. |
| "…cannot open heaps over existing memory" or "…binding tier 3 is not available" | A limit of the installed toolkit. Install the newest Game Porting Toolkit and D3DMetal, and tell Almost There Games. |
| "Azimuth's private Visual C++ runtime did not load" | Menu *File → Reset Wine Prefix*, then repeat steps 4 to 6. |
| "Azimuth rejected the processor" | Turn on *Report AVX support to the game*. |
| "Azimuth could not find the game" | Choose the folder that contains `Mount`. |
| App is blocked on first open | Right-click the app and choose *Open*. It is ad-hoc signed, not notarised. |

## Development

```sh
cd mac
swift test          # logic tests; the AzimuthCore library uses only Foundation
```

- `mac/Sources/AzimuthCore`: setup and launch logic.
- `mac/Sources/AzimuthMac`: the SwiftUI app.
- `.github/workflows/macos.yml`: builds, tests and bundles the app on a macOS runner.

## Licences and credits

- Azimuth: © 2026 Almost There Games, all rights reserved. `azimuth-windows.zip` is theirs and is unchanged.
  Its bundled `licenses.txt` covers FFmpeg (LGPL 2.1), libdeflate and the mingw-w64 runtime.
- Game Porting Toolkit and D3DMetal: © Apple, under Apple's own licence. This repository does not contain them.
- The prebuilt Wine used by the toolkit: [Gcenx/homebrew-wine](https://github.com/Gcenx/homebrew-wine).
- Microsoft's `d3dcompiler_47.dll` is downloaded on your Mac at setup, never stored here.
