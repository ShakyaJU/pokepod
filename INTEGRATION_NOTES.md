# PokéPod patch A: daily challenge, game rules, menu, backup, credits (Dart only)

Extract into the project root (the folder with `pubspec.yaml`) and accept overwrites. No
`pubspec.yaml`, Android or iOS files are included. Native widgets and reminders are in patch B.

**Verification status: nothing here has been compiled, formatted, analysed or run** (no Flutter SDK in my
environment). Structural checks only: bracket balance, imports resolve, no unbraced `if`, no known
deprecated APIs, and a Python mirror of the new selection algorithm used to pick the test thresholds.
Please run `dart format .`, `flutter analyze`, `flutter test` and send the first failure.

## 1. Why one generation kept appearing (root cause)

The old picker was `hash(date) % 1025 + 1`, but the hash was almost linear in the last characters of the
date, so each new day moved the answer by exactly +1 (on 318 of 364 days in a year). The answer therefore
walked through consecutive Pokédex numbers (777, 778, 779 ... all Generation VII) before jumping.
There was no Generation VII filter; the bias came from the hash.

## 2. New selection (`lib/domain/mystery_logic.dart`)

* Candidates: every national-dex species 1..1025 (all nine generations). Out-of-range ids (alternate
  forms), duplicates and malformed records are dropped by `sanitizeEligibleIds`.
* The candidate list is shuffled once per cycle with a seeded, web-safe 32-bit generator and each day
  takes the next position. Over any 1025-day cycle every Pokémon appears exactly once, in an order with no
  link to number, generation or type; the answer for a date never changes. Mystery answer and Specimen of
  the day use different salts so they differ.
* The date is the device's local calendar day (`localDateKey`), refreshed when the app resumes and at local
  midnight (`shell.dart`). Works offline (no data needed to choose).
* The answer is saved the first time a day is opened, so it cannot be re-rolled by rebuilds, restarts or an
  algorithm change. Data saved by the previous version keeps its answer (`legacyMysteryAnswerId`) and its
  guesses; finished days keep their results.
* Measured with the algorithm (not claims about the app): 1025 consecutive days from a cycle start give 1025
  distinct Pokémon covering all 9 generations; over 365 days Generation VII is about 9% (88/1025 = 8.6% expected).

## 3. Final game rules (`mystery_controller.dart`)

* States: ready, in progress, won, lost (`ChallengeStatus`). The page shows "N guesses left".
* 6 guesses. A correct guess ends the day as a win; the 6th wrong guess ends it as a loss ("Game over"),
  reveals the answer and full artwork, disables guessing and clues. Either result is saved and the day
  cannot be replayed after a restart. Duplicate and invalid guesses (not a real Pokémon number) are ignored.
* Streak: a win extends the streak only if the previous day was also won (otherwise it starts at 1); a loss
  ends it immediately; a new unplayed day does not reset it (it shows yesterday's streak) but a fully missed
  day does end it; each date counts once. Best streak, played and won totals come from the same history.
* Clock: the game never goes back to an earlier day than the latest one opened, so turning the clock back
  cannot replay or re-roll. Turning it forward cannot be prevented without a server; this is a limitation.
* Guesses are chosen from a searchable list of Pokémon (not typed), so there is no free-text normalisation.

## 4. Menu

Achievements, Research Journal, Settings, then a divider, then Help & User Guide, then About last
(support before information/legal). Same routes and keys; no duplicates.

## 5. Other features in this patch

* Backup and restore (Settings > Data): "Back up progress" copies a versioned text backup to the clipboard
  (not a file, not uploaded). "Restore from backup" validates app/version/structure, shows what it contains,
  warns, and only on confirmation replaces the matching data; nothing changes if validation fails. Cached
  API data is excluded. Files and the share sheet need a package or native code, so they are not offered.
* Trainer profile: nickname validation (1-20 characters, control characters removed; empty is rejected).
  Editing/avatar/statistics already existed. **Sharing a trainer card is not implemented** (needs a share
  package) and nothing in the app or guide claims it.
* About: sources and credits (PokéAPI, the sprites repository, the supplied logo, packages and their
  licences), an open-source licences page (`showLicensePage`) and an accurate unofficial-project disclaimer
  that states it grants no rights to the artwork.
* Help & User Guide: new "Backing up and restoring your progress" topic, rewritten Trainer profile and
  Who's That Pokémon? topics (local midnight, game over, streak rules), updated Settings topic.

## Files

Added: `lib/core/storage/backup.dart`, `lib/features/trainer_profile/backup_dialogs.dart`,
`test/backup_test.dart`, `test/daily_selection_test.dart`, `test/help_test.dart`.

Modified: `lib/app/shell.dart`, `lib/core/utils/formatters.dart`, `lib/domain/mystery_logic.dart`,
`lib/features/discover/discover_page.dart`, `lib/features/help/help_content.dart`,
`lib/features/mystery/mystery_controller.dart`, `lib/features/mystery/mystery_page.dart`,
`lib/features/trainer_profile/{about_page,edit_trainer_sheet,profile_menu,settings_page}.dart`,
`test/mystery_reveal_test.dart`, `test/mystery_test.dart`, `test/ui_components_test.dart`.

## Not in this patch

Home-screen widgets and local reminders (patch B), iOS equivalents, trainer-card sharing, file export.

## To verify

1. `dart format .`, `flutter analyze`, `flutter test`.
2. On a device: open Who's That Pokémon? on several days (change the date) and confirm different
   generations; lose a game (6 wrong) and check Game over, answer shown, no replay after restart; win and check
   the streak; Settings > Back up progress, then Restore; Profile menu order.
