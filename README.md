<div align="center">

<p align="center">
  <img src="assets/branding/pokepod_splash_text.png" alt="PokéPod" width="320">
</p>

<h3>Beyond the Pokédex.</h3>

<p>An unofficial Pokémon research, challenge and discovery companion built with Flutter.</p>

<p>
<img src="https://img.shields.io/badge/Flutter-3.47.4-02569B?logo=flutter&logoColor=white" alt="Flutter 3.47.4">
<img src="https://img.shields.io/badge/Dart-3.10-0175C2?logo=dart&logoColor=white" alt="Dart 3.10">
<img src="https://img.shields.io/badge/State-Riverpod-0891B2" alt="State management: Riverpod">
<img src="https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white" alt="Android">
<img src="https://img.shields.io/badge/Data-Pok%C3%A9API-EF5350" alt="PokéAPI">
<img src="https://img.shields.io/badge/Storage-Local--first-5EEAF2" alt="Local-first storage">
<img src="https://img.shields.io/badge/License-MIT-E91E63?style=flat" alt="MIT License">
<img src="https://img.shields.io/badge/Project-Unofficial%20fan%20project-FFD700" alt="Unofficial fan project">
</p>

<p><b>1,025 species · 9 generations · 20 achievements · 4 widget sizes · 373 tests</b></p>

<p>
  <a href="https://drive.google.com/file/d/1mC15HkOd97j_yW7tOFx_2wqBNsXa5Kaf/view?usp=sharing"><img src="https://img.shields.io/badge/%E2%96%B6%20%20Watch%20the%20Full%20App%20Demo-02569B?style=for-the-badge" alt="Watch the full PokéPod app demo"></a>
  <a href="#features"><img src="https://img.shields.io/badge/Explore%20the%20Features-2DD4A0?style=for-the-badge" alt="Explore the features"></a>
  <a href="#technical-architecture"><img src="https://img.shields.io/badge/Read%20the%20Architecture-455A64?style=for-the-badge" alt="Read the architecture"></a>
</p>

</div>

<p align="center">
  <img src="App%20screenshot%20compilation.png" alt="PokéPod — Complete Application Overview" width="100%">
</p>

PokéPod treats the Pokédex as a **research instrument** rather than a list. You browse the Pokédex, open research dossiers, record what you have discovered, studied and mastered, compare specimens, build teams, organise collections and play a daily "Who's That Pokémon?" challenge.

Everything you create is stored **locally on your device**. There is no account to create and no custom backend.

<br>

<div align="center">

<table>
  <tr>
    <td align="center" valign="top" width="33%">
      <h4>🔭 Research, not just a list</h4>
      Discovered, Studied and Mastered stages that only you advance.
    </td>
    <td align="center" valign="top" width="33%">
      <h4>🧬 Analysis with explanations</h4>
      Comparisons, connections and team coverage that show their reasoning.
    </td>
    <td align="center" valign="top" width="33%">
      <h4>🎯 A daily challenge</h4>
      One Pokémon a day, progressive clues, streaks and a staged reveal.
    </td>
  </tr>
  <tr>
    <td align="center" valign="top" width="33%">
      <h4>📱 Native Android widgets</h4>
      The Specimen of the Day on your home screen in four sizes.
    </td>
    <td align="center" valign="top" width="33%">
      <h4>🔒 Local-first by design</h4>
      No account, no backend, no analytics. Your progress stays on your device.
    </td>
    <td align="center" valign="top" width="33%">
      <h4>🧪 Engineered to be tested</h4>
      Rules live in pure Dart and are covered by 327 automated tests.
    </td>
  </tr>
</table>

</div>

<a id="demo"></a>

## See it in action

Every feature below has its own short animated preview. For the complete experience, watch the full walkthrough.

<p align="center">
  <a href="https://drive.google.com/file/d/1mC15HkOd97j_yW7tOFx_2wqBNsXa5Kaf/view?usp=sharing"><img src="https://img.shields.io/badge/%E2%96%B6%20%20Watch%20the%20Complete%20PokéPod%20Walkthrough-02569B?style=for-the-badge" alt="Watch the complete PokéPod walkthrough"></a>
</p>

<p align="center"><sub>The walkthrough opens on Google Drive in a new page. It is a link, not an inline player.</sub></p>

---

<a id="contents"></a>

## Contents

- [Features](#features)
  - [Explore](#explore): [Discover](#discover) · [Pokédex](#pokedex) · [Research dossiers](#dossiers) · [Evolution Constellation](#evolution)
  - [Analyse and build](#analyse): [Pokémon DNA](#dna) · [Team Architect](#teams) · [Collections](#collections)
  - [Play and progress](#play): [Who's That Pokémon?](#game) · [Trainer profile](#profile) · [Achievements and journal](#achievements)
  - [On your home screen](#home-screen): [Widgets](#widgets) · [Notifications and sound](#notifications)
  - [Your data, your control](#your-data): [Settings and backup](#settings) · [Help and About](#help)
- [Technical architecture](#technical-architecture)
- [Data, caching and offline behavior](#data-caching-and-offline-behavior)
- [Tech stack](#tech-stack)
- [Getting started](#getting-started)
- [Privacy and data ownership](#privacy-and-data-ownership)
- [Verification and status](#verification-and-status)
- [Known limitations](#known-limitations)
- [Credits and disclaimer](#credits-and-disclaimer)
- [License](#license)

---

<a id="features"></a>

# Features

<a id="explore"></a>

## 🔭 Explore

<a id="discover"></a>

<table>
  <tr>
    <td width="44%" align="center" valign="middle">
      <img src="pokepod-gifs/specimen%20of%20the%20day.gif" alt="Specimen of the Day on the Discover screen" width="260"><br>
      <sub><b>Discover</b> · the Specimen of the Day and today's challenge</sub>
    </td>
    <td width="56%" valign="middle">

### Discover

**A daily dashboard that feels alive, for a brand-new user and an experienced one.**

- **Specimen of the Day**, shared with the home-screen widgets
- **Who's That Pokémon?** card with today's status and a separate streak panel
- **Research progress** ring, recently viewed Pokémon and upcoming milestones
- **Unexpected Connections**: relationships between Pokémon, each with an explanation based on real data

</td>
  </tr>
</table>

<details>
<summary><b>Under the hood</b></summary>

<br>

Connections come from shared abilities, similar stat shapes, similar totals with different strengths and shared evolution families. Each one states the data it was derived from; nothing is guessed or random.

</details>

<a id="pokedex"></a>

<table>
  <tr>
    <td width="56%" valign="middle">

### Pokédex

**All 1,025 species of the National Pokédex, searchable, filterable and sortable.**

- Search by **name or number**
- Filters for **type**, **generation** and **favourites**, combined and cleared in one tap
- A dedicated **Sort by** sheet with direction that adapts to the property: number, name, generation, type, Legendary &amp; Mythical, favourites, height, weight and base stats
- Grid and compact list layouts, loading skeletons, empty states and retry
- Optional **Living Dex** silhouettes for Pokémon you have not discovered yet

</td>
    <td width="44%" align="center" valign="middle">
      <img src="pokepod-gifs/pokedex.gif" alt="Pokédex browsing, searching, filtering and sorting" width="260"><br>
      <sub><b>Pokédex</b> · search, filters and sorting</sub>
    </td>
  </tr>
</table>

<details>
<summary><b>Under the hood</b></summary>

<br>

One request provides every name and number, and artwork URLs are derived from the number, so the grid needs no per-tile requests. Pokémon load 30 at a time. Sorting by type, size, base stats or Legendary &amp; Mythical status uses data already saved on the device and can load missing data on request.

</details>

<a id="dossiers"></a>

### Research dossiers

**Every Pokémon opens a full research file. There is no animated preview for this one yet, so here is what it holds.**

<table>
  <tr>
    <td width="33%" valign="top">

**📊 The data**

- Official and **shiny** artwork
- Types, height and weight
- **Base stats** with totals
- Abilities, hidden ones marked
- A sample of moves and the English species description

</td>
    <td width="33%" valign="top">

**🧪 Your research**

- A **research log**: Unseen → Discovered → Studied → Mastered
- Opening a dossier marks it *Discovered*
- *Studied* and *Mastered* are explicit choices, one step at a time

</td>
    <td width="33%" valign="top">

**🗂️ Your notes and shelves**

- **Personal notes**
- Add to a collection
- Compare in Pokémon DNA
- Pin to your showcase
- An **evolution preview** that opens the Constellation

</td>
  </tr>
</table>

<a id="evolution"></a>

<table>
  <tr>
    <td width="44%" align="center" valign="middle">
      <img src="pokepod-gifs/evolution%20constellation.gif" alt="Evolution Constellation graph being explored" width="260"><br>
      <sub><b>Evolution Constellation</b> · pan, zoom and tap</sub>
    </td>
    <td width="56%" valign="middle">

### Evolution Constellation

**An evolution family as an interactive graph.**

- Pannable and zoomable, generated from PokéAPI evolution-chain data
- Handles branching families (such as Eevee) and multi-stage chains
- Each link is labelled with a readable evolution condition
- The selected Pokémon is highlighted; tap any node to open its dossier

</td>
  </tr>
</table>

---

<a id="analyse"></a>

## 🧬 Analyse and build

<a id="dna"></a>

<table>
  <tr>
    <td width="56%" valign="middle">

### Pokémon DNA

**Put two specimens side by side.**

- Stat bars with differences and totals
- Types and abilities
- A defensive profile: weaknesses, resistances and immunities
- A written analysis generated from the data

</td>
    <td width="44%" align="center" valign="middle">
      <img src="pokepod-gifs/pokemon%20dna.gif" alt="Pokémon DNA comparison of two specimens" width="260"><br>
      <sub><b>Pokémon DNA</b> · comparing two specimens</sub>
    </td>
  </tr>
</table>

<details>
<summary><b>Under the hood</b></summary>

<br>

The analysis is deterministic text derived from real numbers and the type chart. It never claims that base stats predict the outcome of a battle.

</details>

<a id="teams"></a>

<table>
  <tr>
    <td width="44%" align="center" valign="middle">
      <img src="pokepod-gifs/team%20architect.gif" alt="Team Architect building and analysing a team" width="260"><br>
      <sub><b>Team Architect</b> · build a team, read its analysis</sub>
    </td>
    <td width="56%" valign="middle">

### Team Architect

**Build teams of up to six and see where they are strong or exposed.**

- Create, rename, duplicate and delete teams
- A **defensive matrix**: weak, resist and immune counts per attacking type
- **Offensive coverage** and explainable suggestions for gaps

</td>
  </tr>
</table>

<details>
<summary><b>Under the hood</b></summary>

<br>

Offensive coverage is STAB-based: it assumes each Pokémon uses moves of its own types, because movesets are not tracked. PokéPod does not simulate battles. See [Type chart and team analysis](#type-chart).

</details>

<a id="collections"></a>

<table>
  <tr>
    <td width="56%" valign="middle">

### Collections

**Organise what you have found.**

- Custom collections and a reorderable **showcase**
- Pinned favourites and recent research
- **Generation Dex Progress**: pick a generation to see how much of it you have discovered
- Research progress by type

</td>
    <td width="44%" align="center" valign="middle">
      <img src="pokepod-gifs/collections.gif" alt="Collections, showcase and Generation Dex Progress" width="260"><br>
      <sub><b>Collections</b> · showcase and generation progress</sub>
    </td>
  </tr>
</table>

<details>
<summary><b>Under the hood</b></summary>

<br>

Choosing a generation only changes what you are looking at; it never writes to your progress. Research by type needs 18 small requests, loaded on demand.

</details>

---

<a id="play"></a>

## 🎯 Play and progress

<a id="game"></a>

<table>
  <tr>
    <td width="44%" align="center" valign="middle">
      <img src="pokepod-gifs/whos%20that%20pokemon%20challenge.gif" alt="Who's That Pokémon? daily challenge being played" width="260"><br>
      <sub><b>Who's That Pokémon?</b> · guesses, clues and the reveal</sub>
    </td>
    <td width="56%" valign="middle">

### Who's That Pokémon?

**One Pokémon per local calendar day. Six guesses. A picture that sharpens as you struggle.**

- A searchable guess picker and **progressive clues**: generation, type, size and stat total, a description with the name hidden, the name length and first letter
- A **progressive visual reveal**: a "?", then a blurred silhouette, a sharper one, and finally muted color
- A clear **win** or **game over** state that reveals the answer and cannot be replayed after a restart
- **Current and best streak**, games played, win rate and a collapsible result history, all persisted

</td>
  </tr>
</table>

<details>
<summary><b>Under the hood</b></summary>

<br>

The answer is chosen from the full National Dex with a date-seeded shuffle and saved the first time a day is opened. See [Daily challenge selection](#daily-challenge-selection).

</details>

<a id="profile"></a>

<table>
  <tr>
    <td width="56%" valign="middle">

### Trainer profile

**Your identity as a researcher.**

- Nickname and avatar (any Pokémon)
- A selectable **Accent Color** and System, Dark or Light theme
- Research statistics, an achievements preview and saved teams
- A side menu to Achievements, Research Journal, Settings, Help &amp; User Guide and About

</td>
    <td width="44%" align="center" valign="middle">
      <img src="pokepod-gifs/trainer%20profile.gif" alt="Trainer profile with avatar, statistics and side menu" width="260"><br>
      <sub><b>Trainer profile</b> · avatar, statistics and menu</sub>
    </td>
  </tr>
</table>

<a id="achievements"></a>

### Achievements and the research journal

**20 achievements unlock from real research and gameplay progress**, each with a progress bar and a rarity tier. There are **nine tiers**:

`Common` · `Uncommon` · `Rare` · `Epic` · `Double Rare` · `Ultra Rare` · `Illustration Rare` · `Special Illustration Rare` · `Hyper Rare`

The **research journal** collects the notes you write in dossiers, in one place.

<table align="center">
  <tr>
    <td align="center" valign="top" width="50%">
      <img src="pokepod-gifs/achievements.gif" alt="Achievements with progress bars and rarity tiers" width="260"><br>
      <sub><b>Achievements</b> · progress and rarity</sub>
    </td>
    <td align="center" valign="top" width="50%">
      <img src="pokepod-gifs/research%20journal.gif" alt="Research journal of notes" width="260"><br>
      <sub><b>Research journal</b> · your notes, collected</sub>
    </td>
  </tr>
</table>

---

<a id="home-screen"></a>

## 📱 On your home screen

<a id="widgets"></a>

<table>
  <tr>
    <td width="44%" align="center" valign="middle">
      <img src="pokepod-gifs/app%20widgets.gif" alt="PokéPod home-screen widgets in four sizes" width="260"><br>
      <sub><b>Home-screen widgets</b> · compact, small, medium and large</sub>
    </td>
    <td width="56%" valign="middle">

### Android home-screen widgets

**The Specimen of the Day, one glance away.**

Four launcher sizes (**compact, small, medium and large**) show the same Specimen of the Day as the app. Larger sizes progressively add more: artwork, name and number, then type badges, the Pokédex description and height and weight.

To add one, long-press the home screen, open *Widgets*, and choose PokéPod.

</td>
  </tr>
</table>

<a id="notifications"></a>

### Notifications and sound

There is no animated preview for these yet.

<table>
  <tr>
    <td width="50%" valign="top">

**🔔 Opt-in local reminders**

- A daily reminder and a Who's That Pokémon? streak reminder
- Scheduled in the device's local time zone
- Introduced by an in-app explanation before any system permission prompt
- No push service involved

</td>
    <td width="50%" valign="top">

**🔊 Sound effects**

- Short effects for the splash screen and the daily game
- Can be turned off in Settings

</td>
  </tr>
</table>

---

<a id="your-data"></a>

## 🔒 Your data, your control

<a id="settings"></a>

**Settings** holds your preferences, including theme and sound, and the **Data** options. **Back up progress** copies a versioned backup to the clipboard as text. **Restore from backup** validates it, shows what it contains and asks for confirmation before replacing anything. Nothing is uploaded unless you paste it somewhere yourself.

<table align="center">
  <tr>
    <td align="center" valign="top" width="50%">
      <img src="pokepod-gifs/settings.gif" alt="Settings screen" width="260"><br>
      <sub><b>Settings</b> · theme, accent, notifications and data</sub>
    </td>
    <td align="center" valign="top" width="50%">
      <img src="pokepod-gifs/backup%20and%20restore.gif" alt="Backing up and restoring progress" width="260"><br>
      <sub><b>Backup and restore</b> · validated and confirmed</sub>
    </td>
  </tr>
</table>

<a id="help"></a>

A searchable, collapsible **Help &amp; User Guide** covers every feature, and **About** lists the sources and credits, an open-source licences page and the unofficial-project disclaimer.

<table align="center">
  <tr>
    <td align="center" valign="top" width="50%">
      <img src="pokepod-gifs/help%20and%20user%20guide.gif" alt="Searchable Help and User Guide" width="260"><br>
      <sub><b>Help &amp; User Guide</b> · searchable and collapsible</sub>
    </td>
    <td align="center" valign="top" width="50%">
      <img src="pokepod-gifs/about.gif" alt="About screen with credits and licences" width="260"><br>
      <sub><b>About</b> · credits, licences and disclaimer</sub>
    </td>
  </tr>
</table>

---

<a id="technical-architecture"></a>

# Technical architecture

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

## Engineering decisions

- **Riverpod for state and dependency injection.** One mechanism provides state, the repository and the HTTP client, and tests override any of them. GetIt from the original app was dropped because Riverpod already covered it.
- **A repository layer between the UI and the network.** Screens never see HTTP. `PokeApiRepository` is cache-first, de-duplicates identical in-flight requests and depends only on a small `ApiClient` interface, so tests swap in a fake client.
- **Defensive models.** PokéAPI models are hand-written and tolerate missing or malformed fields. A bad response becomes a typed error, not a crash.
- **Domain logic separate from widgets.** The type chart, team analysis, research-stage rules, filtering and sorting, evolution layout, achievements and the daily challenge are pure Dart and are tested without any UI.
- **Navigation.** A swipeable `PageView` shell is driven by a single selected-tab value shared by the bottom bar, swipes and in-app shortcuts. Deeper screens use plain `Navigator` pushes, because there are few enough of them that a router package was not justified.
- **Persistence.** All user data is stored as JSON in `shared_preferences`, loaded before the app starts so notifiers can read it synchronously.

## Testing

The suite covers model parsing (including malformed data), repository caching and error handling with a fake API client, filtering, sorting and pagination, persistence round-trips, the type chart and team analysis, evolution layout, the daily selection, streak rules, backup validation and widget tests for navigation and key screens.

---

<a id="data-caching-and-offline-behavior"></a>

# Data, caching and offline behavior

- **Source:** [PokéAPI](https://pokeapi.co). Artwork comes from the [PokeAPI sprites](https://github.com/PokeAPI/sprites) repository.
- **Catalogue:** one request returns every name and number. Artwork URLs are derived from the number, so the grid needs no per-tile requests.
- **On demand:** details, species text, evolution chains and type lists are fetched when needed, then cached in memory and persisted on disk in a compact format.
- **Offline:** anything you have opened before is served from the cache without a network request. The first time you open something, a connection is required. An "offline" banner appears only after a request has actually failed, and failures show a retry action. Nothing is ever fabricated.
- **Artwork** is cached by the image cache once loaded; artwork you have never loaded cannot appear offline.

<a id="daily-challenge-selection"></a>

## Daily challenge selection

The answer for a day is derived deterministically from the **device's local calendar date**. The full National Dex is shuffled with a date-seeded generator, and each day takes the next position in the shuffle. Over a 1,025-day cycle every species appears exactly once, with no link between consecutive days, generations or types. The day rolls over at local midnight, including while the app stays open and when it returns from the background.

The answer is saved the first time a day is opened, so it cannot change. A finished day cannot be replayed, and guesses that are duplicate or invalid are ignored. The game never reopens a day earlier than the latest one played. Because PokéPod has no server, moving the device clock *forward* cannot be prevented.

<a id="type-chart"></a>

## Type chart and team analysis

`lib/domain/type_chart.dart` implements the 18-type chart used since Generation VI, with dual-type multipliers (0, ¼, ½, 1, 2, 4). Team offensive coverage is **STAB-based**: it assumes each Pokémon uses moves of its own types, because movesets are not tracked. PokéPod does not simulate battles.

---

<a id="tech-stack"></a>

# Tech stack

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

<a id="getting-started"></a>

# Getting started

## Prerequisites

- **Flutter** with a Dart SDK satisfying `^3.10.0` (verified on Flutter 3.47.4)
- **Android Studio** or the Android SDK command-line tools, and an Android emulator or device
- An Android device or emulator is required for the home-screen widgets and notifications

## Run it

```bash
git clone <your-repository-url>
cd pokepod
flutter pub get
flutter run
```

Run these from the directory that contains `pubspec.yaml`. `pubspec.lock` is committed so dependency resolution is reproducible.

## Check it

```bash
dart format .
flutter analyze
flutter test
```

## Build an Android APK

```bash
flutter build apk --debug
flutter build apk --release
```

> **Signing:** release builds still use the debug signing configuration inherited from the Flutter template. Create your own keystore and signing config before publishing. Never commit keystores or `key.properties`.

## Android notes

- **Widgets:** long-press the home screen, open *Widgets*, and choose PokéPod. Four sizes are available.
- **Notifications:** reminders are opt-in. PokéPod explains the purpose in the app before asking Android for notification permission, and you can change your choice later in Settings.

---

<a id="privacy-and-data-ownership"></a>

# Privacy and data ownership

PokéPod is local-first.

- **No accounts**, no custom backend, and no analytics or advertising.
- Research progress, favourites, collections, teams, notes, profile and daily-challenge history are stored **only on your device**.
- **What leaves the device:** requests to PokéAPI for Pokémon data and requests to the GitHub-hosted sprites repository for artwork. These are standard HTTPS requests and necessarily reveal your IP address to those services.
- **Backup:** "Back up progress" copies text to your clipboard. Nothing is uploaded unless you paste it somewhere yourself.
- **Uninstalling the app or clearing its data erases your local progress.** Make a backup first if you want to keep it.

---

<a id="verification-and-status"></a>

# Verification and status

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

<a id="known-limitations"></a>

# Known limitations

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

<a id="credits-and-disclaimer"></a>

# Credits and disclaimer

- **Pokémon data** is provided by [PokéAPI](https://pokeapi.co).
- **Artwork** is fetched at runtime from the [PokeAPI sprites](https://github.com/PokeAPI/sprites) repository. No Pokémon artwork is stored in this repository.
- **Sound effects** bundled under `assets/sounds/` were sourced through Zedge. Their redistribution terms have not been independently confirmed.
- **The PokéPod wordmark** was supplied by the author.
- **Packages and licences:** full provenance, package licences and redistribution notes are in [`THIRD_PARTY_NOTICES.md`](./THIRD_PARTY_NOTICES.md). In the app, **About → Open-source licences** lists every package licence.

<a id="license"></a>

# License

PokéPod's original source code is released under the [MIT License](./LICENSE).

This license applies to the original code authored for this project. Pokémon-related names, characters, artwork, trademarks, and other third-party materials remain the property of their respective owners and are not covered by this license. Third-party dependencies and assets remain subject to their respective licenses and usage terms.

> **Disclaimer:** PokéPod is an unofficial fan project. It is not affiliated with, endorsed by or sponsored by Nintendo, The Pokémon Company or Game Freak. Pokémon and related names, characters and artwork are trademarks and copyrights of their respective owners. This repository does not claim ownership of any Pokémon intellectual property.

---

<div align="center">

Built with Flutter by [ShakyaJU](https://github.com/ShakyaJU)

<sub>PokéPod is an unofficial fan project and is not affiliated with Nintendo, The Pokémon Company or Game Freak.</sub>

</div>
