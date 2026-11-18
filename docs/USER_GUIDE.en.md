# TrainerDock – User guide

[Deutsch](USER_GUIDE.de.md) · **English** · [Română](USER_GUIDE.ro.md)

[Back to the README and game list](../README.en.md)

## 1. What TrainerDock does

TrainerDock manages games, installation paths and separately downloadable trainers.
The app contains the launcher and catalog metadata. A trainer’s native library loads
into the selected game only when you request a launch. Downloading a trainer does
not start a game.

App version, trainer version and game build are independent. New trainers can appear
in an existing compatible app. A new game build still needs an explicitly supported
profile; the same displayed version or game name alone does not prove compatibility.

## 2. Installing and setting up

1. Check the requirements: Apple Silicon, macOS 27 or later, and an original build
   supported in the [game list](../README.en.md). Marked Intel game profiles require Rosetta.
2. Download `TrainerDock-macOS-arm64.zip` from the
   [latest stable GitHub release](https://github.com/darkuser89/TrainerDock/releases/latest),
   extract it and place **TrainerDock.app** in Applications. Xcode is not needed to use it.
3. Open **Download & Manage Trainers**, then **Check for Trainer Updates** if needed.
   Find your game and download an offered version. This requires internet access
   and does not launch the game.
4. Open **Trainers & Game Paths** with **⌘ ,**. If discovery misses a game, choose
   its actual `.app`. Store profiles have separate paths: a Steam installation,
   for example, cannot substitute for a GOG path.
5. Select the game on the left and its store/build profile on the right.
   **All Trainers** includes games not yet set up; **Installed** shows detected installations.

TrainerDock does not download games; you need their original installations.
Packages are ad-hoc signed, not Developer ID signed or notarized. If macOS displays
an error, report its exact wording; do not alter game signatures or macOS protections.

## 3. Launching a game with its trainer

First quit an already running instance normally from the game. Then:

- **Steam:** Open Steam normally and select the Steam profile in TrainerDock.
- **Epic:** Quit the Epic Games Launcher normally first. The launch service briefly
  changes Epic’s launch mapping and restores it afterwards. A running Epic client
  can overwrite that mapping from its cache.
- **GOG / Mac App Store:** Choose the supported profile and its matching installation.

Click **Play**. If the button says **Download Trainer**, download the package first;
that download does not start the game. The game’s identity and trainer are checked
again before launch. Unsupported builds do not trigger a silent fallback launch
without the trainer. Do not open a second game instance to work around a failed launch.

## 4. Features, overlay and transparency

Features appear in collapsible groups on the right. Switches control continuous
effects; value fields specify the desired number. One-time actions require an
explicit action. Descriptions explain required game states, such as an open
inventory or a loaded character.

**⌘ ^** opens or closes the in-game trainer: Command plus the circumflex key,
not Control. Other shortcuts are shown beside their features. The game’s name
appears at the top left. If the shortcut does not work, check the keyboard layout
and game focus; the launcher can also open the overlay for a matching active session.

A requested switch is not yet a confirmed effect. **Active** is reported only after
reading back from the game. Unavailable features may wait for the required context;
disabled or WIP features are not complete. **Turn All Off** releases the trainer’s
continuous effects. It does not undo one-time changes, such as spent money or items
already added.

Liquid Glass stays enabled. The in-game slider labelled **Glas**, at the bottom
right, changes background opacity: **0% transparent, 50% native glass, 100% opaque**.
Text and controls stay visible. The value is saved per trainer; macOS accessibility
settings such as reduced transparency take precedence.

**Restore on Launch** is initially off. When enabled, it restores saved continuous
switches only in a valid game context. One-time actions never repeat at launch.
Paths, selections and glass values are kept in user preferences.

## 5. Changing the app language

Open **Trainers & Game Paths → App Language**. Choose **Deutsch**, **Română**,
**English** or **System Language**, then quit and reopen TrainerDock normally.
Your choice persists and does not change the global macOS language.

**System Language** uses the primary language: German, Romanian and English are
recognized, including regional variants. Other primary languages use English,
even if German appears later in the preferred language list. This setting affects
the launcher interface. Trainer catalogs and in-game trainers currently retain
their German feature text.

## 6. Updating, switching and deleting trainers

Open **Download & Manage Trainers** and click **Check for Trainer Updates** to
refresh the catalog. Download a newer version for an individual trainer; **Use**
selects an installed version. Version switching is available after quitting the
game normally.

**Update All Installed Trainers** first checks the online catalog, then downloads
missing latest packages for trainers you already have. The current search filter
does not limit this action. Downloads run sequentially with progress; an individual
failure does not stop the others. Trainers you have not installed are not added.
Existing releases are not downloaded again and newer versions are not downgraded.

New packages do not replace older ones. Running games keep their exact trainer
instance. After quitting a game, you can select a previous installed version again,
provided its profile matches the installed game.

Use **Delete** to remove an installed version you no longer need. Active sessions,
running games and libraries still in use are protected. TrainerDock never deletes
old versions automatically. Deleting a trainer package does not delete the game
or its saves.

## 7. Updating TrainerDock itself

Use **TrainerDock → Check for Updates…** for a manual check. Automatic checks can
be enabled or disabled in that menu. They run at startup and hourly, with at most
one successful automatic query per day.

**Download and Install** downloads a newer stable app release. The updater checks
size and GitHub’s SHA-256 digest, waits for running games and replaces only the app.
It never closes games. Trainer packages, paths and settings remain outside the
app bundle. If the updated app fails to start, the replacement is rolled back.
App updates and trainer updates are separate operations.

## 8. Storage and GitHub builds

Downloaded packages are stored by version at:

```text
~/Library/Application Support/TrainerDock/Modules/<id>/<version>/<id>.mhtmodule
```

Legacy MHT locations remain readable. Use the trainer manager to remove packages or
switch versions; do not manually replace a running game’s libraries. TrainerDock
does not edit saves to make a build compatible. Changes made by trainer features
can become part of a save when the game saves normally.

The app and modules stay in the same repository, with separate builds and releases.
GitHub compares actual product contents with the last confirmed catalog. App
changes build only the app; trainer changes build only affected modules. Changed
shared dependencies can affect several trainers. Documentation, tests or version
numbers alone do not produce feature updates. Trainers have individual build jobs,
at most three in parallel, and their own immutable releases. Only confirmed packages
enter the download catalog. Developer details: [releasing guide](RELEASING.md) (German).

## 9. Common problems

| Problem | What to do |
|---|---|
| A game is missing | Select **All Trainers**, refresh the catalog and choose the correct `.app` in path settings. Reload with **⌘ R**. |
| A game update is rejected | Check for a matching trainer update. Without a verified profile the new build remains blocked; the store or filename alone is insufficient. |
| A download is missing or fails | Check internet access and refresh the catalog. Install the required app version if yours is too old. Report the error and trainer/profile version. |
| A feature is waiting | Enter the required game context and read its description. WIP or disabled features remain limited. Prodeus is single-player only. |
| Epic launch fails | Quit Epic normally first and check the Epic profile and path. Do not start a second game instance in parallel. |
| Overlay, mouse or fullscreen transition hangs | Save if possible and quit normally. Report the game, store, build, trainer version and exact trigger; use a confirmed compatible package. |

The current game list and known limitations are in the [English README](../README.en.md).
Synthetic build tests do not demonstrate in-game FPS or compatibility with unlisted builds.
