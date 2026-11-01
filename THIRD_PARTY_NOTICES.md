# Third-Party Notices

This file lists third-party material used by PokéPod, so that the repository's
provenance is explicit. It records what is known; it does **not** grant any
licence that the original rights holders have not already granted.

PokéPod is an **unofficial fan project**. It is not affiliated with, endorsed by,
or sponsored by Nintendo, The Pokémon Company, Creatures Inc., or GAME FREAK inc.
Pokémon and all related names, characters and artwork are trademarks and
copyrights of their respective owners.

## 1. Pokémon data and artwork (fetched at runtime, not stored in this repository)

| Item | Source | How it is used |
| --- | --- | --- |
| Stats, types, abilities, species text, evolution chains | [PokéAPI](https://pokeapi.co) (`pokeapi.co/api/v2/`) | Fetched on demand and cached locally on the user's device |
| Official artwork and sprites | [PokeAPI/sprites](https://github.com/PokeAPI/sprites) (`raw.githubusercontent.com`) | Loaded and cached at runtime for the Pokédex, dossiers and widgets |

**Important:** this repository contains **no** Pokémon artwork, sprites or game
data. All of it is fetched from the sources above while the app runs, so nothing
is redistributed by the repository itself. PokéPod claims no licence to this
material and makes no ownership claim over it.

## 2. Sound effects (bundled in this repository)

The five audio files under `assets/sounds/` were, per the in-app credits
(`About` → *Data sources and credits*), sourced through the
[Zedge](https://www.zedge.net) app:

| File | In-app use |
| --- | --- |
| `whos_that_pokemon.mp3` | Who's That Pokémon? game intro |
| `correct_guess.mp3` | Successful guess |
| `error.mp3` | Failed guess / error |
| `notification.mp3` | Reserved for reminder notifications |
| `splashscreen.mp3` | App splash |

⚠️ **Attribution is not redistribution permission.** These files are bundled in
the repository *and* inside the compiled APK, which means publishing this
repository distributes them. Zedge's terms vary per item (personal-use versus
redistributable). **The author must confirm that each file is licensed for
redistribution in an open-source project before publishing.** If any file's terms
are unclear, replace it with a permissively licensed alternative (for example
CC0 or CC-BY audio from a source such as freesound.org) or remove it. This note
will be updated once the author has confirmed the terms.

## 3. PokéPod branding (owned by the author)

The files under `assets/branding/` (`pokepod_icon_1024.png`, `pokepod_logo.png`,
`pokepod_mark.png`, `pokepod_splash_text.png`) are the project's own logo and
wordmark, supplied by the app's author. They are original to this project, not
third-party Pokémon material.

## 4. Fonts

No custom fonts are bundled. The app uses the **Material Icons** font that ships
with the Flutter SDK, licensed under the
[Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).

## 5. Software packages

Direct Flutter/Dart dependencies (from `pubspec.yaml`), with their upstream
licences as published by their authors:

| Package | Licence |
| --- | --- |
| Flutter / Dart SDK | BSD-3-Clause |
| `flutter_riverpod` | MIT |
| `dio` | MIT |
| `shared_preferences` | BSD-3-Clause |
| `cached_network_image` | MIT |
| `cupertino_icons` | MIT |
| `audioplayers` | MIT |
| `home_widget` | MIT |
| `flutter_local_notifications` | MIT |
| `flutter_timezone` | MIT |
| `timezone` | Apache-2.0 |
| `path_provider` | BSD-3-Clause |
| `url_launcher` | MIT |
| `flutter_lints` (dev) | BSD-3-Clause |

The full transitive dependency set, including exact resolved versions, is pinned
in `pubspec.lock`. Android build tooling (Android Gradle Plugin, Kotlin) is
provided by Google and JetBrains respectively under their own terms and is not
committed to this repository.

## 6. Repository licence

This repository currently has **no open-source licence file**. Until one is
added, the code is *not* open source in the legal sense: others may view it, but
no permission to use, modify or redistribute it is granted by the author. Adding
a licence (for example MIT, Apache-2.0, or GPL-3.0) is a decision for the
author, because it irrevocably sets the terms under which the code can be reused.
