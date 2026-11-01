<div align="center">

<img src="assets/branding/pokepod_icon_1024.png" width="120" alt="PokéPod icon" />

# PokéPod

**An unofficial Pokémon research and discovery companion built with Flutter.**

</div>

PokéPod treats the Pokédex as a research instrument rather than a list. You browse the
national dex (species 1–1025), open research dossiers, log what you have discovered, studied
and mastered, compare specimens, build teams, and solve a daily mystery, all stored locally on
your device with no account.

> **Status:** verified on Flutter 3.47.4 — `flutter analyze` is clean, all 327 tests pass, and
> both the debug and release Android APKs build successfully. iOS, web, macOS, Linux and Windows
> targets have not been built. See [Verification status](#verification-status).

## Features

| Area | What it does |
| --- | --- |
| **Discover** | Greeting, specimen of the day, Mystery Specimen card with streak, research progress ring, recently viewed, explainable "Unexpected connections", next milestones. Works for a brand-new user with no data. |
| **Pokédex** | Search by name or number, grid and compact list, sort, type filter, generation filter, favourites filter, combined filters, result counts, clear-filters, incremental loading (30 at a time), loading skeletons, empty and error states with retry, optional Living Dex silhouettes for undiscovered entries. |
| **Dossier** | Official artwork (and shiny artwork), types, measurements, base stats with total, abilities (hidden marked), a sample of moves, English species description, evolution preview, research stage controls, personal notes, add to collection, compare, pin to showcase. |
| **Evolution Constellation** | Pannable, zoomable graph generated from PokéAPI evolution-chain data: branches, multi-stage chains, readable evolution conditions, selected-node highlight, tap to open. |
| **Pokémon DNA** | Two-specimen comparison: stat bars and differences, totals, types, abilities, defensive weaknesses/resistances/immunities, and deterministic text derived from the data. It does not claim base stats predict battles. |
| **Team Architect** | Teams of up to six (create, rename, duplicate, delete, persist), defensive matrix (weak/resist/immune counts), STAB-based offensive coverage, and explainable suggestions. |
| **Mystery Specimen** | One deterministic Pokémon per local calendar day, six progressive clues, searchable guess picker, six-guess limit, reveal animation, collapsible paginated history, current and best streak, all persisted. |
| **Collections** | Custom collections, showcase (reorderable), pinned favourites, Living Dex progress by generation, optional progress by type, recent research. |
| **Profile** | Nickname, avatar (any Pokémon), accent colour, theme mode, research/mystery stats, saved teams, rule-based achievements, journal of notes, import of old favourites. |
| **Achievements** | 20 achievements across 9 rarity tiers (Common through Hyper Rare), unlocked from real research and gameplay progress, shown with tier badges and progress bars. |
| **Notifications** | Opt-in daily reminder notifications, scheduled in the device's local timezone, with an in-app permission onboarding flow. |
| **Home-screen widgets** | Android widgets in four launcher sizes (compact, small, medium, large) showing the same Specimen of the Day as the app, with progressive detail (art, types, Pokédex text, height/weight) and type-coloured badges. |
| **Sound** | Optional sound effects for the daily game and splash, mutable from Settings. |

## Tech stack

* Flutter / Dart (SDK constraint `^3.10.0`)
* [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) for state management and dependency injection
* [dio](https://pub.dev/packages/dio) for networking (timeouts, retries, cancellation)
* [shared_preferences](https://pub.dev/packages/shared_preferences) for all local persistence
* [cached_network_image](https://pub.dev/packages/cached_network_image) for artwork caching
* [audioplayers](https://pub.dev/packages/audioplayers) for the optional sound effects
* [home_widget](https://pub.dev/packages/home_widget) for the Android home-screen widgets
* [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) and
  [flutter_timezone](https://pub.dev/packages/flutter_timezone) for daily reminder notifications

GetIt from the old app was dropped on purpose: Riverpod already covers dependency injection, and
having both added no value. Navigation uses a swipeable `PageView` shell driven by a bottom
`NavigationBar`; deeper routes are plain `Navigator` pushes, and the app has few enough of them
that a router package was not justified.

## Architecture

```
lib/
  main.dart                    entry point, loads SharedPreferences
  app/
    app.dart                   MaterialApp, theme wiring, launch splash
    shell.dart                 five-tab shell, back-to-Discover behaviour
    theme/                     design tokens (colour, spacing, radii, motion) and ThemeData
    design_system/widgets.dart Panel, TypeChip, StatBar, PokemonArtwork, skeletons, states
  core/
    errors/ networking/ storage/ utils/
  data/
    models/                    hand-written, defensive PokéAPI models + compact cache formats
    repositories/              PokeApiRepository: cache-first, in-flight de-duplication
    providers.dart             repository, catalogue, detail, species, evolution providers
  domain/                      pure Dart, unit-tested: type chart, team analysis, research rules,
                               mystery logic, filters, connections, evolution layout, achievements
  features/                    discover, pokedex, pokemon_detail, evolution, analysis,
                               team_builder, mystery, collections, trainer_profile, research,
                               notifications, widgets, help, shared
test/                          unit and widget tests (no network; PokéAPI is faked)
```

Business logic lives in `domain/` and in notifiers; widgets only render state.

### Data and offline behaviour

* **Source:** [PokéAPI](https://pokeapi.co). Artwork comes from the
  [PokeAPI sprites](https://github.com/PokeAPI/sprites) repository.
* **Catalogue:** one request (`/pokemon?limit=1025`) provides every name and id; artwork URLs are
  derived from the id, so the grid needs no per-tile requests.
* **Details, species, evolution chains and type lists** are fetched on demand, cached in memory
  and persisted on disk in a compact format. Cached entries are served without a network request,
  so anything you have opened before works offline.
* **Never fabricated:** if a request fails and nothing is cached, the UI shows an error with a
  retry action. An "offline" banner appears only after a request has actually failed.
* PokéAPI is a free community service; please be considerate. This app makes small, cached requests.

### Type chart and ruleset

`lib/domain/type_chart.dart` implements the 18-type chart used since Generation VI (Fairy
included). Dual-type multipliers multiply (0, ¼, ½, 1, 2, 4). Team offensive coverage assumes each
member uses moves of its own types (STAB) because movesets are not tracked. There is **no battle
simulation**.

### Mystery Specimen determinism

The answer for a day is `mysteryAnswerId(dateKey)`, a deterministic rolling hash of the day's
date key that is exact on every platform including web, so the same date gives the same Pokémon
on every device and after every restart. The date key is the device's **local** calendar day: the
mystery rolls over at local midnight (re-read on app resume and by a timer while the app stays
open), not at UTC midnight. A day that is already completed ignores further guesses, and repeated
guesses are ignored, so streaks cannot be corrupted by duplicate submissions. Older records
saved by a previous selection method are migrated rather than re-rolled. Clues need the answer's
data; if it has never been cached and you are offline, the game shows an unavailable state with
retry.

## Getting started

### Prerequisites

* [Flutter](https://docs.flutter.dev/get-started/install) with a Dart SDK satisfying `^3.10.0`
  (PokéPod was verified on Flutter 3.47.4)
* Android: Android Studio or the Android SDK command-line tools, and an emulator or device
* iOS builds additionally require macOS and Xcode

### Run it

Run these from the directory that contains `pubspec.yaml`:

```bash
flutter pub get
dart format .
flutter analyze
flutter test
flutter run
```

`pubspec.lock` is committed so that dependency resolution is reproducible. Run
`flutter pub upgrade` deliberately when you want newer versions, not as part of a fresh clone.

### Build

```bash
flutter build apk --debug      # Android debug APK
flutter build apk --release    # Android release APK (see signing note)
flutter build appbundle        # Play Store bundle
flutter build ios              # macOS only
flutter build web
```

**Signing:** release builds in `android/app/build.gradle.kts` still use the debug signing config
inherited from the Flutter template. Create your own keystore and signing config before
publishing. Never commit keystores or `key.properties` (they are in `.gitignore`).

### Application identifiers

| Platform | Identifier |
| --- | --- |
| Android `applicationId` and `namespace` | `com.shakyaju.pokepod` |
| iOS / macOS bundle identifier | `com.shakyaju.pokepod` |
| Linux application id | `com.shakyaju.pokepod` |
| Dart package | `pokepod` |

This is a proposed unique ID, **not** a claim that it is registered or reserved anywhere. To change
it: update `android/app/build.gradle.kts` (`namespace`, `applicationId`), move and edit
`android/app/src/main/kotlin/com/shakyaju/pokepod/MainActivity.kt`, and update the bundle
identifiers in `ios/Runner.xcodeproj/project.pbxproj`, `macos/Runner/Configs/AppInfo.xcconfig`
and `linux/CMakeLists.txt`.

## Supported platforms

Android is the primary target. iOS, web, macOS, Linux and Windows folders are present (migrated
from the original project with identifiers updated) but have not been built or tested.

## Privacy

Everything (research progress, favourites, collections, teams, notes, profile, mystery history,
cached API data) is stored only on your device with SharedPreferences. There are no accounts,
analytics, ads or custom backend. The only network traffic is to PokéAPI and to the GitHub-hosted
artwork. Uninstalling the app removes the data.

Because the application ID changed from the old app, a fresh install cannot read the old app's
private data. The old app stored favourites as PokéAPI URLs; PokéPod does not migrate them, so
re-add favourites from the Pokédex. Nothing else from the old app was persisted.

## Known limitations

* Progress by type needs 18 small requests and is loaded on demand.
* Moves are a sample (first 12 alphabetically), not a full move list. Alternate forms (Mega,
  regional) are not catalogued; only national-dex species 1–1025 are.
* Type progress, coverage and suggestions use types only; abilities and moves are not modelled.
* No screenshots are included.
* Cached API data lives in SharedPreferences, which is fine for personal use but not designed for
  very large caches.
* Home-screen widgets are Android-only, because they are implemented with the Android
  `home_widget` platform views.

## Verification status

Run on Flutter 3.47.4 (Windows, JDK 21, Android SDK 36):

| Check | Status |
| --- | --- |
| `flutter pub get` | **Pass** |
| `dart format lib test` | **Pass** — 89 files, 0 changed |
| `flutter analyze` | **Pass** — no issues found |
| `flutter test` | **Pass** — 327 tests |
| Android debug build | **Pass** — `flutter build apk --debug` |
| Android release build | **Pass** — `flutter build apk --release` |
| iOS / web / desktop build | **Not run** (no toolchain set up on the verification machine) |

## Third-party credits and licences

Pokémon data and artwork are fetched at runtime from [PokéAPI](https://pokeapi.co) and the
[PokeAPI/sprites](https://github.com/PokeAPI/sprites) repository; **no Pokémon material is stored
in this repository**. Sound effects bundled under `assets/sounds/` were sourced through
[Zedge](https://www.zedge.net). Full provenance, package licences and redistribution notes are in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

This repository has no open-source licence file yet. Until the author adds one, no permission to
use, modify or redistribute the code is granted.

## Publishing to a new GitHub repository

> Review [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) first — in particular, confirm the
> redistribution terms of the bundled sound effects before the repository goes public.

From the project directory (`.gitignore` is already configured for Flutter/Android/IDE/secret
artefacts, and keeps `pubspec.lock` tracked):

```bash
git init
git add .
git status          # review what will be committed — no build output, keystores or .env files
git commit -m "Initial release of PokéPod"
git branch -M main
```

Create a new, empty repository on GitHub named `pokepod`, then add its URL and push:

```bash
git remote add origin YOUR_NEW_GITHUB_REPOSITORY_URL
git push -u origin main
```

For a last check before the first commit, install [Gitleaks](https://github.com/gitleaks/gitleaks)
(`winget install Gitleaks.GitLeaks` on Windows) and scan the staged tree:

```bash
gitleaks detect --source . --redact --verbose
```

## Disclaimer

PokéPod is an **unofficial fan project**. It is not affiliated with, endorsed by, or sponsored by
Nintendo, The Pokémon Company, or Game Freak. Pokémon and related names, characters and artwork
are trademarks and copyrights of their respective owners. Data is provided by
[PokéAPI](https://pokeapi.co).
