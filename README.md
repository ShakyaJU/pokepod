<div align="center">

<!--<h1>PokéPod</h1>-->

<p align="center">
  <img src="assets/branding/pokepod_splash_text.png" alt="PokéPod" width="300">
</p>

<h3>Beyond the Pokédex.</h3>

<p>An unofficial Pokémon research challenge and discovery companion built with Flutter.</p>

<p>
<img src="https://img.shields.io/badge/Flutter-3.47.4-02569B?logo=flutter&logoColor=white" alt="Flutter 3.47.4">
<img src="https://img.shields.io/badge/Dart-3.10-0175C2?logo=dart&logoColor=white" alt="Dart 3.10">
<img src="https://img.shields.io/badge/State-Riverpod-2DD4A0" alt="State management: Riverpod">
<img src="https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white" alt="Android">
<img src="https://img.shields.io/badge/Data-Pok%C3%A9API-EF5350" alt="PokéAPI">
<img src="https://img.shields.io/badge/Storage-Local--first-5EEAF2" alt="Local-first storage">
<img src="https://img.shields.io/badge/Project-Unofficial%20fan%20project-FFD700" alt="Unofficial fan project">
</p>

<p><b>1,025 species · 9 generations · 20 achievements · 4 widget sizes · 327 tests</b></p>

</div>

<p align="center">
  <img src="App screenshot compilation.png" alt="PokéPod — Complete Application Overview" width="100%">
</p>

PokéPod treats the Pokédex as a **research instrument** rather than a list. You browse the Pokédex, open research dossiers, record what you have discovered, studied and mastered, compare specimens, build teams, organise collections and play a daily "Who's That Pokémon?" challenge.

Everything you create is stored **locally on your device**. There is no account to create and no custom backend.

---

## Contents

- [Features](#features)
- [Technical architecture](#technical-architecture)
- [Data, caching and offline behavior](#data-caching-and-offline-behavior)
- [Tech stack](#tech-stack)
- [Getting started](#getting-started)
- [Privacy and data ownership](#privacy-and-data-ownership)
- [Verification and status](#verification-and-status)
- [Known limitations](#known-limitations)
- [Credits and disclaimer](#credits-and-disclaimer)

---

## Features

### Discover

A dashboard that works for a brand-new user and for an experienced one.

- **Specimen of the Day**, shared with the home-screen widgets.
- **Who's That Pokémon?** card with today's status and a separate streak panel.
- **Research progress** ring, recently viewed Pokémon and upcoming milestones.
- **Unexpected Connections**: relationships between Pokémon, each with an explanation based on real data (shared abilities, similar stat shapes, similar totals with different strengths, shared evolution families).

### Pokédex

- The **National Pokédex, species 1–1025**, loaded incrementally (30 at a time).
- Search by **name or number**; filters for **type**, **generation** and **favourites**, which can be combined and cleared in one tap.
- A dedicated **Sort by** sheet, separate from the filters, with direction that adapts to the property: Pokédex number, name, generation, type, Legendary & Mythical, favourites, height, weight and base stats.
- Grid and compact list layouts, loading skeletons, empty states and retry on failure.
- Optional **Living Dex** silhouettes for Pokémon you have not discovered yet.

### Research dossiers

Each Pokémon opens a full dossier:

- Official and **shiny** artwork, types, height and weight.
- **Base stats** with totals, abilities (hidden abilities marked), a sample of moves and the English species description.
- An **evolution preview** that opens the Evolution Constellation.
- A **research log** (Unseen → Discovered → Studied → Mastered), **personal notes**, add to a collection, compare, and pin to your showcase.

Opening a dossier marks a Pokémon as *Discovered*. *Studied* and *Mastered* are always explicit choices, one step at a time.

### Evolution Constellation

An interactive, pannable and zoomable graph generated from PokéAPI evolution-chain data. It handles branching families (such as Eevee) and multi-stage chains, labels each link with readable evolution conditions, highlights the selected Pokémon and opens any node's dossier on tap.

### Pokémon DNA

A two-specimen comparison: stat bars with differences, totals, types, abilities and a defensive profile (weaknesses, resistances, immunities). The written analysis is generated from the data and never claims that base stats predict a battle.

### Team Architect

Teams of up to six Pokémon that you can create, rename, duplicate and delete. The analysis shows a defensive matrix (weak, resist and immune counts per attacking type), offensive coverage and explainable suggestions for gaps.

### Who's That Pokémon?

A daily guessing game with one Pokémon per local calendar day.

- **Six guesses**, a searchable guess picker and **progressive clues** (generation, type, size and stat total, a description with the name hidden, the name length and first letter).
- A **progressive visual reveal**: the artwork starts as a "?" and becomes a blurred silhouette, then a sharper one, then muted color as you guess wrongly.
- A clear **win** or **game over** state that reveals the answer, locks the day and cannot be replayed after a restart.
- **Current and best streak**, games played, win rate and a collapsible result history, all persisted.

### Collections

Custom collections, a reorderable showcase, pinned favourites, **Generation Dex Progress** (pick a generation to see how much of it you have discovered), research progress by type and recent research.

### Trainer profile

Nickname and avatar (any Pokémon), a selectable **Accent Color**, System/Dark/Light theme, research statistics, an achievements preview, a **research journal** of your notes and saved teams. A side menu leads to Achievements, Research Journal, Settings, Help & User Guide and About.

### Achievements

**20 achievements** unlocked from real research and gameplay progress, each with a progress bar and a rarity tier. There are **nine tiers**:

`Common` · `Uncommon` · `Rare` · `Epic` · `Double Rare` · `Ultra Rare` · `Illustration Rare` · `Special Illustration Rare` · `Hyper Rare`

### Android home-screen widgets

Four launcher sizes (**compact, small, medium and large**) show the same Specimen of the Day as the app. Larger sizes progressively add more: artwork, name and number, then type badges, the Pokédex description and height and weight.

### Notifications and sound

- **Opt-in local reminders**: a daily reminder and a Who's That Pokémon? streak reminder, scheduled in the device's local time zone and introduced by an in-app explanation before any system permission prompt. No push service is involved.
- Short **sound effects** for the splash screen and the daily game; they can be turned off in Settings.

### Help, backup and restore

A searchable, collapsible **Help & User Guide** covers every feature. **Back up progress** copies a versioned backup of your progress to the clipboard as text, and **Restore from backup** validates it, shows what it contains and asks for confirmation before replacing anything.

---

## Technical architecture

PokéPod is organised by feature, with the rules of the app kept in plain Dart that does not depend on Flutter widgets.

```mermaid
flowchart LR
    UI["features/<br/>screens and widgets"] --> P["Riverpod providers<br/>and notifiers"]
    P --> D["domain/<br/>pure Dart rules"]
    P --> R["PokeApiRepository<br/>cache-first"]
    R --> C["ApiClient (Dio)"]
    C --> API[("PokéAPI")]
    R --> S[("SharedPreferences<br/>JSON cache")]
    P --> S
```

```text
lib/
  main.dart                    entry point, loads SharedPreferences
  app/
    app.dart                   MaterialApp, theme wiring, launch splash
    shell.dart                 five-tab shell, back-to-Discover behaviour
    theme/                     design tokens (color, spacing, radii, motion) and ThemeData
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

### Engineering decisions

- **Riverpod for state and dependency injection.** One mechanism provides state, the repository and the HTTP client, and tests override any of them. GetIt from the original app was dropped because Riverpod already covered it.
- **A repository layer between the UI and the network.** Screens never see HTTP. `PokeApiRepository` is cache-first, de-duplicates identical in-flight requests and depends only on a small `ApiClient` interface, so tests swap in a fake client.
- **Defensive models.** PokéAPI models are hand-written and tolerate missing or malformed fields. A bad response becomes a typed error, not a crash.
- **Domain logic separate from widgets.** The type chart, team analysis, research-stage rules, filtering and sorting, evolution layout, achievements and the daily challenge are pure Dart and are tested without any UI.
- **Navigation.** A swipeable `PageView` shell is driven by a single selected-tab value shared by the bottom bar, swipes and in-app shortcuts. Deeper screens use plain `Navigator` pushes, because there are few enough of them that a router package was not justified.
- **Persistence.** All user data is stored as JSON in `shared_preferences`, loaded before the app starts so notifiers can read it synchronously.

### Testing

The suite covers model parsing (including malformed data), repository caching and error handling with a fake API client, filtering, sorting and pagination, persistence round-trips, the type chart and team analysis, evolution layout, the daily selection, streak rules, backup validation and widget tests for navigation and key screens.

---

## Data, caching and offline behavior

- **Source:** [PokéAPI](https://pokeapi.co). Artwork comes from the [PokeAPI sprites](https://github.com/PokeAPI/sprites) repository.
- **Catalogue:** one request returns every name and number. Artwork URLs are derived from the number, so the grid needs no per-tile requests.
- **On demand:** details, species text, evolution chains and type lists are fetched when needed, then cached in memory and persisted on disk in a compact format.
- **Offline:** anything you have opened before is served from the cache without a network request. The first time you open something, a connection is required. An "offline" banner appears only after a request has actually failed, and failures show a retry action. Nothing is ever fabricated.
- **Artwork** is cached by the image cache once loaded; artwork you have never loaded cannot appear offline.

### Daily challenge selection

The answer for a day is derived deterministically from the **device's local calendar date**. The full National Dex is shuffled with a date-seeded generator, and each day takes the next position in the shuffle. Over a 1,025-day cycle every species appears exactly once, with no link between consecutive days, generations or types. The day rolls over at local midnight, including while the app stays open and when it returns from the background.

The answer is saved the first time a day is opened, so it cannot change. A finished day cannot be replayed, and guesses that are duplicate or invalid are ignored. The game never reopens a day earlier than the latest one played. Because PokéPod has no server, moving the device clock *forward* cannot be prevented.

### Type chart and team analysis

`lib/domain/type_chart.dart` implements the 18-type chart used since Generation VI, with dual-type multipliers (0, ¼, ½, 1, 2, 4). Team offensive coverage is **STAB-based**: it assumes each Pokémon uses moves of its own types, because movesets are not tracked. PokéPod does not simulate battles.

---

## Tech stack

<p>
  <img src="https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/Riverpod-2DD4A0" alt="Riverpod">
  <img src="https://img.shields.io/badge/Dio-networking-5C6BC0" alt="Dio">
  <img src="https://img.shields.io/badge/shared__preferences-persistence-455A64" alt="shared_preferences">
  <img src="https://img.shields.io/badge/cached__network__image-artwork%20cache-607D8B" alt="cached_network_image">
  <img src="https://img.shields.io/badge/audioplayers-sound-8E24AA" alt="audioplayers">
  <img src="https://img.shields.io/badge/home__widget-Android%20widgets-3DDC84?logo=android&logoColor=white" alt="home_widget">
  <img src="https://img.shields.io/badge/flutter__local__notifications-reminders-F57C00" alt="flutter_local_notifications">
  <img src="https://img.shields.io/badge/flutter__timezone-local%20time%20zone-0097A7" alt="flutter_timezone">
  <img src="https://img.shields.io/badge/Pok%C3%A9API-data-EF5350" alt="PokéAPI">
</p>

| Package | Used for |
| --- | --- |
| `flutter_riverpod` | State management and dependency injection |
| `dio` | HTTP with timeouts, retries and cancellation |
| `shared_preferences` | All local persistence |
| `cached_network_image` | Artwork caching |
| `audioplayers` | Sound effects |
| `home_widget` | Android home-screen widgets |
| `flutter_local_notifications`, `flutter_timezone` | Daily reminders in the local time zone |

---

## Getting started

### Prerequisites

- **Flutter** with a Dart SDK satisfying `^3.10.0` (verified on Flutter 3.47.4)
- **Android Studio** or the Android SDK command-line tools, and an Android emulator or device
- An Android device or emulator is required for the home-screen widgets and notifications

### Run it

```bash
git clone <your-repository-url>
cd pokepod
flutter pub get
flutter run
```

Run these from the directory that contains `pubspec.yaml`. `pubspec.lock` is committed so dependency resolution is reproducible.

### Check it

```bash
dart format .
flutter analyze
flutter test
```

### Build an Android APK

```bash
flutter build apk --debug
flutter build apk --release
```

> **Signing:** release builds still use the debug signing configuration inherited from the Flutter template. Create your own keystore and signing config before publishing. Never commit keystores or `key.properties`.

### Android notes

- **Widgets:** long-press the home screen, open *Widgets*, and choose PokéPod. Four sizes are available.
- **Notifications:** reminders are opt-in. PokéPod explains the purpose in the app before asking Android for notification permission, and you can change your choice later in Settings.

---

## Privacy and data ownership

PokéPod is local-first.

- **No accounts**, no custom backend, and no analytics or advertising.
- Research progress, favourites, collections, teams, notes, profile and daily-challenge history are stored **only on your device**.
- **What leaves the device:** requests to PokéAPI for Pokémon data and requests to the GitHub-hosted sprites repository for artwork. These are standard HTTPS requests and necessarily reveal your IP address to those services.
- **Backup:** "Back up progress" copies text to your clipboard. Nothing is uploaded unless you paste it somewhere yourself.
- **Uninstalling the app or clearing its data erases your local progress.** Make a backup first if you want to keep it.

---

## Verification and status

Last recorded verification run: Flutter 3.47.4 on Windows, JDK 21, Android SDK 36.

| Check | Result |
| --- | --- |
| `flutter pub get` | Pass |
| `dart format lib test` | Pass (89 files, 0 changed) |
| `flutter analyze` | Pass: no issues found |
| `flutter test` | Pass: 327 tests |
| Android debug APK | Pass |
| Android release APK | Pass |
| iOS, web, macOS, Linux, Windows | **Not built or tested** |

The platform folders for iOS, web and desktop exist but are untested. Re-run the commands above to reproduce these results on your machine.

---

## Known limitations

- **Scope:** only National Dex species **1–1025** are catalogued. Alternate forms (Mega, regional and similar) are not.
- **Moves:** the dossier shows a sample (the first 12 alphabetically), not a complete move list.
- **Team analysis** uses types only and assumes STAB coverage. Movesets and abilities are not modelled, and there is no battle simulation.
- **Sorting** by type, size, base stats or Legendary & Mythical status needs data that is not in the catalogue. Those sorts use data already saved on the device and can load missing data on request.
- **Research by type** needs 18 small requests, loaded on demand.
- **Cached data** lives in `shared_preferences`. That suits personal use but is not designed for very large caches, and cached data is not refreshed automatically.
- **Home-screen widgets and local reminders** are Android-only.
- **Clock changes:** with no server, moving the device clock forward cannot be prevented.
- **Backups** are copied as clipboard text; there is no file export, cloud backup or cross-device sync.
- **Release signing** uses the debug configuration until you add your own keystore.

---

## Credits and disclaimer

- **Pokémon data** is provided by [PokéAPI](https://pokeapi.co).
- **Artwork** is fetched at runtime from the [PokeAPI sprites](https://github.com/PokeAPI/sprites) repository. No Pokémon artwork is stored in this repository.
- **Sound effects** bundled under `assets/sounds/` were sourced through Zedge. Their redistribution terms have not been independently confirmed.
- **The PokéPod wordmark** was supplied by the author.
- **Packages and licences:** full provenance, package licences and redistribution notes are in [`THIRD_PARTY_NOTICES.md`](./THIRD_PARTY_NOTICES.md). In the app, **About → Open-source licences** lists every package licence.

**Licence:** this repository currently has no open-source licence file, so no permission to use, modify or redistribute the code is granted until the author adds one.

> **Disclaimer:** PokéPod is an unofficial fan project. It is not affiliated with, endorsed by or sponsored by Nintendo, The Pokémon Company or Game Freak. Pokémon and related names, characters and artwork are trademarks and copyrights of their respective owners. This repository does not claim ownership of any Pokémon intellectual property.

<!-- 

## Screenshots

### Discover
<p align="center"><img src="URL_FOR_DISCOVER" alt="Discover" width="260"></p>

### Pokédex
<p align="center"><img src="URL_FOR_POKEDEX" alt="Pokédex" width="260"></p>

### Research dossier
<p align="center"><img src="URL_FOR_DOSSIER" alt="Research dossier" width="260"></p>

### Evolution Constellation
<p align="center"><img src="URL_FOR_EVOLUTION" alt="Evolution Constellation" width="260"></p>

### Pokémon DNA
<p align="center"><img src="URL_FOR_DNA" alt="Pokémon DNA" width="260"></p>

### Team Architect
<p align="center"><img src="URL_FOR_TEAM_ARCHITECT" alt="Team Architect" width="260"></p>

### Who's That Pokémon?
<p align="center"><img src="URL_FOR_GAME" alt="Who's That Pokémon?" width="260"></p>

### Collections
<p align="center"><img src="URL_FOR_COLLECTIONS" alt="Collections" width="260"></p>

### Achievements
<p align="center"><img src="URL_FOR_ACHIEVEMENTS" alt="Achievements" width="260"></p>

### Android widgets
<p align="center"><img src="URL_FOR_WIDGETS" alt="Android home-screen widgets" width="520"></p>
     ============================================================================ 
 -->

---

<div align="center">

Built with Flutter by [ShakyaJU](https://github.com/ShakyaJU)

<sub>PokéPod is an unofficial fan project and is not affiliated with Nintendo, The Pokémon Company or Game Freak.</sub>

</div>
