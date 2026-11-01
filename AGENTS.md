# AGENTS.md

PokéPod — a Flutter (Dart ^3.10.0) Pokémon companion app. Package `pokepod`, app ID `com.shakyaju.pokepod`.
Single app, no workspace tooling. State management is flutter_riverpod v2 (hand-written providers —
no codegen). All persistence is SharedPreferences; the only network traffic is PokéAPI.
Not a git repo yet; no CI. (`.gitignore`, README and third-party notices have been prepared for a
first public commit — see `THIRD_PARTY_NOTICES.md`.)

## Nested `pokepod/` snapshot — superseded, gitignored, do not delete without asking

`pokepod/` is a full second copy of this project — a "recovery snapshot" (its own
`pokepod/INTEGRATION_NOTES.md` explains it). As of the current tree it is **superseded**, not
newer: root `lib/` contains every file the snapshot has **plus** all later work (rarity theming,
notifications, widgets, collapsible history). The snapshot has none of those.

- It is **ignored by `.gitignore`** (rule `pokepod/`), so it will not be committed. It stays on
  disk only as history.
- It has never been built (no `pokepod/.dart_tool`); when analyzed it resolves packages through
  the **root** package config.
- Treat everything under `pokepod/` as read-only reference. Do not delete it without explicit
  approval — but there is no pending merge; root is the single source of truth.
- Because it is still present on disk, `flutter analyze` analyses it too, and `dart format .`
  (with the dot) would reformat it — hence the `dart format lib test` rule below.

## Commands (run from repo root; verified with Flutter 3.47.4)

```bash
flutter pub get
dart format lib test     # NOT `dart format .` — that also reformats the pokepod/ snapshot
flutter analyze          # analyzes root AND the pokepod/ snapshot (snapshot is not excluded)
flutter test             # 327 tests, ~8s, fully offline
flutter test test/domain_test.dart                  # single file
flutter test --plain-name "dual types multiply"     # single test
flutter run
```

Before finishing any change: `dart format lib test` → `flutter analyze` → `flutter test`.
All three pass clean right now; keep them that way.

## Architecture (verified against code, not README)

- `lib/main.dart` loads SharedPreferences, overrides `sharedPreferencesProvider`, runs `PokePodApp`.
- Pure-Dart business logic lives in `lib/domain/` (no Flutter imports — keep it that way) and in
  Riverpod notifiers under each `lib/features/<area>/`. Widgets only render.
- Data flow: `ApiClient` abstraction (`DioApiClient`: 10s/20s/10s timeouts, 3 retries, CancelToken)
  → `PokeApiRepository` (cache-first, in-flight de-duplication; disk cache is compact JSON in
  SharedPreferences under the `cache.v1.` prefix) → providers in `lib/data/providers.dart`.
- `sharedPreferencesProvider` throws if not overridden: every `ProviderContainer` and app pump in
  tests **must** override it.
- Repository `onLiveStatus` callbacks report through `Future.microtask` — never mutate provider
  state during build.
- Navigation: `app/shell.dart` uses a swipeable `PageController`/PageView plus `NavigationBar`
  driven by `navIndexProvider`; deeper routes are plain `Navigator` pushes (`openDossier` in
  `features/shared/navigation.dart`).
- Daily/mystery date is the device **local** date via `todayKeyProvider`
  (`features/mystery/mystery_controller.dart`), refreshed on app resume and by a midnight timer in
  `shell.dart`; time is injectable via `clockProvider`.

## Testing

- Shared fakes and fixtures: `test/support/support.dart` — `FakeApiClient(routes)` maps URL → JSON
  (or an `AppException` to throw), plus `mockPrefs`, `makeContainer`, `catalogJson`, `pokemonJson`,
  `makeDetail`, `eeveeChainJson`, `charmanderChainJson`, `kTestPixel` (1×1 PNG so artwork never
  touches the network).
- Widget tests pump `PokePodApp` with four overrides — see `pumpApp` in `test/widget_test.dart`:
  `sharedPreferencesProvider`, `apiClientProvider` (fake), `imageProviderFactoryProvider`
  (MemoryImage of `kTestPixel`), and `todayKeyProvider` (fixed date string) for date-dependent UI.
- No `integration_test/`, no golden tests, no external services required.

## Conventions & constraints

- Lints: `flutter_lints` plus `prefer_single_quotes` and `avoid_print`; the `prefer_const_*`
  rules are deliberately disabled in `analysis_options.yaml` — do not re-enable them.
  Platform folders are excluded from analysis; the `pokepod/` snapshot is not.
- No code generation anywhere: no build_runner, riverpod_generator, or freezed. Models are
  hand-written and defensive against malformed PokéAPI payloads.
- Changing the app ID touches `android/app/build.gradle.kts`, `MainActivity.kt`,
  `ios/Runner.xcodeproj/project.pbxproj`, `macos/Runner/Configs/AppInfo.xcconfig`, `linux/CMakeLists.txt`.

## Documentation trust order

1. Code and config (`pubspec.yaml`, `analysis_options.yaml`).
2. `README.md` — kept accurate (verification status, local mystery date, PageView shell, pubspec.lock).
3. `INTEGRATION_NOTES.md` — historical: root = "patch A" history, `pokepod/INTEGRATION_NOTES.md` =
   older snapshot history. Both describe a merge that is already complete; treat as archaeology.

## Known caveats (do not silently "fix")

- `home_widget` 0.10.0 still applies the legacy Kotlin Gradle plugin by design, so Flutter prints
  one **informational** notice ("Future versions of Flutter will fail to build…"). Do not flip
  `android.builtInKotlin=true` in `android/gradle.properties` — that would break `home_widget`.
  Wait for a built-in-Kotlin `home_widget` release, then bump and remove the shim.
- Release builds still use the debug signing config (`android/app/build.gradle.kts`) — intentional
  until the author creates a keystore.
- `notification.mp3` is bundled (`assets/sounds/` + `android/app/src/main/res/raw/`) and reachable
  as `Sfx.notification`, but no scheduled reminder currently plays it — reminders are opt-in and
  the sound is reserved for a future streak-reminder path.
