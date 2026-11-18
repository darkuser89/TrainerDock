# TrainerDock · Mac Game Trainers

[Deutsch](README.md) · **English** · [Română](README.ro.md)

[Download the app](https://github.com/darkuser89/TrainerDock/releases/latest) ·
[Detailed user guide](docs/USER_GUIDE.en.md)

A native macOS launcher with independent game trainers. Installed games appear
on the left; trainer controls and the launch button appear on the right.
Choose each game’s application in **Trainers & Game Paths**.

The current source tree contains **28 independent trainers**. The table lists
released profiles under `Modules/`; these are **game versions**, separate from
trainer package versions. Published packages are available through the app’s
trainer catalog. New trainers appear without updating the app: use **Check for
Trainer Updates** in a compatible installed version of TrainerDock.

| Game | Supported store | Game/profile version | Notes |
|---|---|---|---|
| Balatro | Steam | 1.0.1o-FULL (Build 17459173) | |
| Control Ultimate Edition | Steam / Mac App Store | Steam 1.34; MAS 1.33.1 / 1.371 | |
| Crimson Desert | Steam | Bundle 1.0.35 (builds 450 and 466; Steam 26636972) | |
| Cyberpunk 2077 | Steam | 2.5.0 | |
| Dead Island 2 | Steam / Mac App Store | 0.6.4 | **Steam: Uncut version only; MAS: German Cut version only** |
| Death Stranding Director’s Cut | Mac App Store | 1.004 (Bundle 1.1.4) | |
| Dome Keeper | Steam | 5.0.8.14 | |
| DREDGE | Epic Games Store / GOG | Epic 1.5.5; GOG 1.5.3 | GOG uses Rosetta |
| Escape from Duckov | Steam | 2.3.30 | |
| Frostpunk 2 | Steam | 1.6.1 (Bundle 0.5.591, Build 24037022) | |
| House Flipper | Steam | 1.26252 (Build 25247477) | Rosetta |
| inZOI | Steam | Bundle 5.4.95 (Build 26264076) | |
| Lies of P | Steam | 1.14.0 | |
| No Man’s Sky | Steam | Bundle 4.70 (Builds 26386568, 26540391) | |
| Prodeus | Steam | 1.0.2 (Build 9679369) | **Single-player only** |
| Resident Evil 2 | Mac App Store | 1.0.2 | |
| Resident Evil 3 | Mac App Store | 1.0.0 | |
| Resident Evil 4 | Mac App Store | 1.0.7 | |
| Resident Evil 7 | Mac App Store | 1.0.4 | |
| Resident Evil Village | Mac App Store | 1.1.8 | |
| RoboCop: Rogue City | Steam | 0.0.1 | |
| Stray (WIP) | Steam | 1.5 (Build 12863654) | **Unfinished; four features disabled** |
| Terraria | Steam | 1.4.5.8 (Build 24893155) | |
| The Long Dark | Steam / Epic Games Store | Steam 2.60 (Build 26450964); Epic 2.55 | |
| Turok | Steam | 2.0 (Build 18198095) | Rosetta |
| Turok 2: Seeds of Evil | Steam | 2.0 (Build 20961743) | Rosetta |
| Vampire Crawlers | Steam | 1.6.1 (Build 25304267) | |
| Vampire Survivors | Steam / Epic Games Store | 1.16.111 | |

Control includes all twelve requested features. Native limitations and validation
scope: [Control module](Modules/control/README.md) (German).

Trainers support the specific original builds that have been verified. The
launcher runs on Apple Silicon; explicitly supported Intel game profiles use
Rosetta. Other stores and game updates are not supported automatically.

## Getting started

1. Download `TrainerDock-macOS-arm64.zip` from the latest stable release, extract
   it and place **TrainerDock.app** in Applications.
2. Open **Download & Manage Trainers** and download the trainers you need.
   Set missing game paths in **Trainers & Game Paths**.
3. Select the game and its store profile. Open Steam for Steam profiles; quit
   the Epic Games Launcher normally before using an Epic profile. Quit an already
   running instance of the game normally, then click **Play** in TrainerDock.
4. Use the launcher controls or open the in-game trainer with **⌘ ^**.
   Feature shortcuts are shown beside their controls. **Turn All Off** releases
   ongoing trainer effects; it does not undo one-time changes.

Search and the **Installed / All Trainers** filters narrow the library. Game icons
come from installed game apps. Switching games preserves your chosen window size.
**⌘ ,** opens paths and settings, **⌘ R** reloads trainers and games, and **⌘ 1**
opens the library.

The launcher supports German, Romanian and English. It follows the primary macOS
language by default, with English for other languages. Choose **App Language** in
**Trainers & Game Paths**, then restart TrainerDock. **System Language** restores
automatic selection. Trainer feature catalogs and in-game trainers retain their
own German text; choosing a launcher language does not translate these catalogs.

Liquid Glass stays enabled and respects macOS accessibility settings. The
in-game **Glas** slider adjusts only the background, from transparent to opaque,
and saves the value per trainer. Long game paths are shown in settings and the
path button’s tooltip rather than across the main view.

**Restore on Launch** is off by default. When enabled, saved continuous switches
are restored only in a valid game context. One-time actions never run automatically.

## Requirements

To use the app: **Apple Silicon, macOS 27 or later**, and a supported original
build of the game. Catalog refreshes and downloads require internet access.
Intel game profiles also require Rosetta. Xcode with the macOS 27 SDK or later
is needed only for development, not for the downloaded app.

## Independent downloads and updates

[GitHub Actions](https://github.com/darkuser89/TrainerDock/actions/workflows/build-release.yml)
compares product contents with the last successfully published catalog. It builds
only new or genuinely changed products. App and trainers have separate jobs,
with at most three trainer builds running in parallel. Documentation, build-script
or launcher-only changes do not give unchanged trainers a new release. Pull requests
run checks without publishing releases.

Stable [app releases](https://github.com/darkuser89/TrainerDock/releases/latest)
provide `TrainerDock-macOS-arm64.zip` and `SHA256SUMS`. The app contains catalog
metadata, not bundled native trainers. Each trainer has its own immutable
`trainer-<game-id>-v<version>` prerelease and is downloaded through TrainerDock.
Old trainer versions remain available. **Update All Installed Trainers** downloads
missing newer packages only for trainers you already have.

TrainerDock checks for app updates at startup and hourly, with at most one
successful automatic check per day. Use **TrainerDock → Check for Updates…** for
a manual check; automatic checks can be disabled there. Installation starts after
**Download and Install**. Package size and GitHub’s SHA-256 digest are checked.
Only the app is replaced; installed trainers, paths and settings remain separate.
Running games delay app installation and are never closed by the updater.

Downloads are ad-hoc signed, not Developer ID signed or notarized. No additional
update-signing keys, Apple certificates or Keychain prompts are required.
macOS protections remain unchanged.

## Building locally

Open `TrainerDock.xcodeproj` in Xcode. **TrainerDock** builds the full project;
**TrainerDock-Launcher** builds only the launcher; `Trainer-<game-id>` builds one
complete trainer. Synthetic checks do not launch games.

Install the archive headers first with `brew install libarchive`. The app uses
the macOS system library, not a Homebrew runtime path. Script equivalents:

```sh
./script/build_and_run.sh --build-only   # Build and run synthetic checks
./script/build_and_run.sh --verify       # Also open the launcher
python3 -B script/build.py --module <game-id> --configuration Release
```

The current app is built outside the repository at
`~/Library/Developer/TrainerDock/TrainerDock.app`. Local modules are built under
`~/Library/Developer/TrainerDock/Modules` and are not installed automatically.
`TRAINERDOCK_BUILD_DIR` may select another separate build directory; code and
audit directories are excluded. Trainer libraries load only in the selected game
process, never in the launcher.

Two C# trainers use only our own compiled components in GitHub builds. SHA-256
bindings cover their sources, original profiles and bytes; stale components are
rejected. Game assemblies are never uploaded. See [Releasing](docs/RELEASING.md)
(German) for the build and publication workflow.

TrainerDock imports previous MHT paths, selections and glass settings on first
launch. User modules live under `~/Library/Application Support/TrainerDock/Modules`;
legacy locations remain readable. SDK names and `.mhtmodule` stay compatible.

Development references (German): [AGENTS.md](AGENTS.md),
[module guide](docs/MODULES.md), [architecture](docs/ARCHITECTURE.md),
and the reusable [trainer template](Templates/Trainer/README.md) (`$trainer-template`).
New template modules are disabled development modules, without borrowed game
addresses or simulated effects.

Keep all three READMEs and user guides in sync when behavior, requirements or the
game list changes.
