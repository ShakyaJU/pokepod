import 'package:flutter/material.dart';

enum HelpBlockKind { paragraph, bullets, tip }

/// One block of guide content: a paragraph, a bullet list or a highlighted tip.
class HelpBlock {
  const HelpBlock.paragraph(String this.text)
    : kind = HelpBlockKind.paragraph,
      items = const [];
  const HelpBlock.tip(String this.text)
    : kind = HelpBlockKind.tip,
      items = const [];
  const HelpBlock.bullets(this.items)
    : kind = HelpBlockKind.bullets,
      text = null;

  final HelpBlockKind kind;
  final String? text;
  final List<String> items;

  /// All searchable text of the block.
  String get searchText =>
      kind == HelpBlockKind.bullets ? items.join(' ') : (text ?? '');
}

class HelpTopic {
  const HelpTopic(this.id, this.icon, this.title, this.blocks);

  final String id;
  final IconData icon;
  final String title;
  final List<HelpBlock> blocks;

  bool matches(String query) {
    final q = query.toLowerCase();
    if (title.toLowerCase().contains(q)) {
      return true;
    }
    return blocks.any((b) => b.searchText.toLowerCase().contains(q));
  }
}

/// The guide describes only controls and behaviour that exist in the app.
const List<HelpTopic> kHelpTopics = [
  HelpTopic('welcome', Icons.waving_hand_outlined, 'Welcome to PokéPod', [
    HelpBlock.paragraph(
      'PokéPod is a Pokémon research and discovery companion. You explore Pokémon, log what '
      'you have discovered and learned, compare them, plan teams and keep your own notes.',
    ),
    HelpBlock.paragraph(
      'PokéPod opens with a brief launch screen showing the PokéPod logo, then goes straight to Discover.',
    ),
    HelpBlock.paragraph('The bar at the bottom has five destinations:'),
    HelpBlock.bullets([
      'Discover: your daily dashboard and the Who\'s That Pokémon? challenge.',
      'Pokédex: the full catalogue with search, filters and sorting.',
      'Lab: Team Architect, Pokémon DNA and the Evolution Constellation.',
      'Collections: showcase, favourites, your collections and Generation Dex Progress.',
      'Profile: your trainer overview. A menu in its top-right corner opens Achievements, '
          'Research Journal, Settings, About and this guide.',
    ]),
    HelpBlock.tip(
      'Swipe left or right to move between the five destinations, or tap the bottom bar; both stay in '
      'sync. Swiping on a horizontal list (such as the filter row or a carousel) scrolls that list instead. '
      'Pressing the system back button on any tab other than Discover takes you back to Discover first.',
    ),
  ]),
  HelpTopic('discover', Icons.explore_outlined, 'Discover', [
    HelpBlock.paragraph(
      'Discover is the first tab. From top to bottom it shows (use the bottom bar or swipe to reach the Pokédex and Lab):',
    ),
    HelpBlock.bullets([
      'Specimen of the day: a Pokémon that changes every day at midnight (your local time). Tap it to open its dossier.',
      'Daily challenge: the Who\'s That Pokémon? card with today\'s status on the left and, in a separate panel on the right, your current streak (with a 🔥) and your best streak.',
      'Research progress: how many Pokémon you have discovered, studied and mastered.',
      'Recently viewed: the dossiers you opened last.',
      'Unexpected connections: up to three Pokémon related to the specimen of the day. Each '
          'card states the data it is based on, such as a shared ability or a similar stat total.',
      'Milestones: the achievements you are closest to earning.',
    ]),
    HelpBlock.tip(
      'New here? Open the Pokédex tab, tap any Pokémon, and your first discovery is logged.',
    ),
  ]),
  HelpTopic('widgets', Icons.widgets_outlined, 'Home-screen widgets', [
    HelpBlock.paragraph(
      'PokéPod has three Android home-screen widgets, in small, medium and large sizes. They are one '
      'family showing today\'s Specimen of the Day, with more detail the bigger the widget: the small '
      'size has the artwork, name, Pokédex number, types and generation; the medium size adds the '
      'Pokédex field description; the large size adds height and weight.',
    ),
    HelpBlock.bullets([
      'Adding one: press and hold an empty part of your home screen, choose Widgets, find PokéPod '
          'and drag the size you want onto the screen.',
      'Tapping the widget opens PokéPod directly on that Pokémon\'s dossier.',
      'The widget always shows the same specimen as Discover, because both come from the same daily selection.',
      'It refreshes whenever you use the app, and shortly after midnight it refreshes on its own, so '
          'a new day appears even if you keep PokéPod closed.',
      'The three sizes share the same artwork, type badges, colours and typography, so they always '
          'look like members of one family; the extra space of the larger sizes simply carries more '
          'of the same entry.',
      'Until the app has saved today\'s specimen (or when artwork has never been downloaded), the '
          'widget shows a Pokéball placeholder rather than guessing.',
    ]),
    HelpBlock.tip(
      'If a widget still shows yesterday\'s specimen, open the app once: the widget is written by the '
      'app itself and then updates in place.',
    ),
  ]),
  HelpTopic('pokedex', Icons.grid_view_rounded, 'Using the Pokédex', [
    HelpBlock.bullets([
      'Search: type a name or a number in "Search name or number". Numbers match the start of '
          'the Pokédex number, so 25, #25 and 0025 all find Pikachu (and numbers beginning 25).',
      'Browsing: Pokémon load 30 at a time and more appear as you scroll down.',
      'Grid and list: the button in the top-right of the header switches between a grid and a compact list.',
      'Living Dex view: the half-filled circle button in the header shows undiscovered Pokémon as silhouettes. Names stay visible.',
      'Filters: the Type, Generation and Favourites buttons in the FILTER row under the search box. Filters combine, so you can ask for Fire types from Generation I that are favourites.',
      'Result count: "N matching" shows how many Pokémon fit your search and filters.',
      'Clear filters: appears whenever a search or filter is active and resets them (your sort order stays).',
    ]),
    HelpBlock.paragraph(
      'Sorting is separate from filtering. The SORT BY button under the filters always shows '
      'the current property and direction, for example "Height · Tallest first". Tap it to open the Sort by sheet:',
    ),
    HelpBlock.bullets([
      'Identity: Pokédex number and Name.',
      'Classification: Generation, Type (alphabetical by first type, then second type), Legendary & Mythical, and Favourites.',
      'Measurements: Height and Weight, compared as real numbers rather than text.',
      'Base stats: the base stat total and each of HP, Attack, Defense, Sp. Atk, Sp. Def and Speed.',
      'Direction: the two-way switch at the top of the sheet changes with the property you pick, for example A → Z / Z → A or Shortest first / Tallest first.',
      'Changes apply straight away. Reset (in the sheet, or the circular arrow beside SORT BY) returns to Pokédex number, lowest first. Searching and filters are never cleared by sorting.',
    ]),
    HelpBlock.tip(
      'The catalogue only lists names and numbers. Type, size, stats and Legendary & Mythical '
      'status come from each Pokémon\'s details, so those sorts can only place Pokémon whose data is '
      'saved on your device; the rest are listed last. A banner says how many are included and, when '
      'the results are 150 or fewer, offers "Load N missing" to fetch them.',
    ),
  ]),
  HelpTopic('details', Icons.badge_outlined, 'Understanding Pokémon details', [
    HelpBlock.paragraph(
      'Tap a Pokémon to open its research dossier. It contains:',
    ),
    HelpBlock.bullets([
      'Artwork, Pokédex number and a Shiny switch for the alternate coloring.',
      'Name, species label and badges for its types, generation and, where relevant, Legendary or Mythical.',
      'Field description: the English species text from PokéAPI.',
      'Measurements: height in metres, weight in kilograms and base experience.',
      'Base stats: HP, Attack, Defense, Sp. Atk, Sp. Def and Speed, with their total.',
      'Abilities, with hidden abilities marked.',
      'Moves: a sample of the first 12 learnable moves alphabetically, plus how many it can learn in total.',
      'Evolution: a preview of its evolution family that opens the Evolution Constellation.',
      'Research log and Research notes for your own progress and observations.',
      'Actions: the heart in the top bar (favourite), Add to collection, Compare and Pin to showcase.',
    ]),
    HelpBlock.tip(
      'Base stats describe a Pokémon\'s raw potential only. They do not decide battles: moves, '
      'items, levels, abilities and strategy matter just as much.',
    ),
  ]),
  HelpTopic('types', Icons.local_fire_department_outlined, 'Understanding Pokémon types', [
    HelpBlock.paragraph(
      'Each type badge shows a colored dot and the type name. Types decide how much damage '
      'attacks of one type do to another: super effective (×2), not very effective (×½) or no effect (×0).',
    ),
    HelpBlock.bullets([
      'A weakness takes more damage, a resistance takes less and an immunity takes none.',
      'Pokémon with two types combine both. The multipliers multiply, so a Fire/Flying Pokémon takes ×4 from Rock (×2 and ×2).',
      'An immunity wins over a weakness: Ground attacks do nothing (×0) to anything that is part Flying.',
    ]),
    HelpBlock.paragraph(
      'PokéPod shows weaknesses, resistances and immunities in Pokémon DNA ("Defensive profile") '
      'and, for whole teams, in the Team Architect. The dossier itself shows types but not the matchup chart. '
      'The chart used is the current 18-type chart (with the Fairy type).',
    ),
  ]),
  HelpTopic(
    'type-progress',
    Icons.donut_small_outlined,
    'Type effectiveness and type progress',
    [
      HelpBlock.paragraph('Two separate features involve types:'),
      HelpBlock.bullets([
        'Type effectiveness: the multipliers in Pokémon DNA and the Team Architect (see the previous topic).',
        'Type progress: the "Research by type" section on the Collections tab.',
      ]),
      HelpBlock.paragraph('How "Research by type" works:'),
      HelpBlock.bullets([
        'Tap its header to open it. The arrow points down when it can be opened and up when it can be closed.',
        'Tap the header again to close it. Reopening is quick because the numbers are kept.',
        'The first time you open it, PokéPod loads the member list for each of the 18 types, so it needs a connection once.',
        'Each row shows a type, a bar and "discovered/total". A Pokémon with two types counts toward both.',
        'If a row shows "retry", that type could not be loaded. Tap it to try again.',
      ]),
    ],
  ),
  HelpTopic('constellation', Icons.hub_outlined, 'Evolution Constellation', [
    HelpBlock.paragraph(
      'The constellation draws a Pokémon\'s whole evolution family as a graph. Open it from the '
      'Evolution section of a dossier, or from Lab > Evolution Constellation, which lets you pick any Pokémon.',
    ),
    HelpBlock.bullets([
      'Drag to pan and pinch to zoom.',
      'Branches fan out to the right. The label on each line gives the evolution condition when PokéAPI provides one, such as "Level 16" or "Use Water Stone".',
      'Your starting Pokémon is highlighted and marked SELECTED.',
      'Tap any other Pokémon to open its dossier.',
      'The target icon in the top bar resets the view.',
    ]),
    HelpBlock.paragraph(
      'Pokémon that do not evolve show a single card and a short message.',
    ),
  ]),
  HelpTopic('dna', Icons.biotech_outlined, 'Pokémon DNA and comparison', [
    HelpBlock.paragraph(
      'Open it from Lab > Pokémon DNA, the Compare shortcut on Discover or the Compare button in a dossier.',
    ),
    HelpBlock.bullets([
      'Tap each slot to search for a Pokémon. The swap arrows in the top bar exchange them.',
      'Base stats: bars for each stat with both values. A + or − number shows the difference, and the total is shown last.',
      'Types and abilities for both Pokémon.',
      'Defensive profile: what each Pokémon is weak to, resists and is immune to.',
      'Analysis: plain-language notes generated from the real numbers, such as the larger stat total or how their own types match up.',
    ]),
    HelpBlock.tip(
      'The comparison uses base stats and types only. It does not predict the winner of a battle.',
    ),
  ]),
  HelpTopic('lab', Icons.groups_outlined, 'Battle Lab and team builder', [
    HelpBlock.paragraph(
      'The Team Architect (Lab > Team Architect) manages teams of up to six different Pokémon.',
    ),
    HelpBlock.bullets([
      'New team creates a team. Tap + to add members and × on a card to remove one.',
      'On the team list, the ⋮ menu renames, duplicates or deletes a team. Teams are saved on your device.',
      'Defensive matrix: for every attacking type, W is how many members are weak, R how many resist and I how many are immune. A red outline marks a major shared weakness, where weak members outnumber resisting or immune ones by two or more.',
      'Offensive coverage: types that at least one member\'s own type hits super effectively.',
      'Suggestions: plain explanations of gaps, such as a weakness shared by several members.',
    ]),
    HelpBlock.tip(
      'PokéPod does not simulate battles and does not know your Pokémon\'s moves. Coverage is '
      'based on each member\'s own types only, so treat it as a guide.',
    ),
  ]),
  HelpTopic('mystery', Icons.psychology_alt_outlined, 'Who\'s That Pokémon?', [
    HelpBlock.paragraph('Open it from the Daily challenge card on Discover.'),
    HelpBlock.bullets([
      'There is one mystery Pokémon per day. It is picked from every Pokémon in the Pokédex, from all generations, and changes at midnight (your local time). It stays the same all day, even if you close and reopen the app.',
      'You have six guesses. Tap "Make a guess" and search for a Pokémon. The screen shows how many guesses are left.',
      'The picture starts as a "?". Each wrong guess makes the real artwork clearer: first a heavily blurred silhouette, then sharper ones, and on your last attempt the artwork in muted color.',
      'Clues unlock one at a time as well: generation, type, size and stat total, a description with the name hidden, the name length and first letter, and a final note about the picture.',
      'A correct guess ends the day as a win. Using all six guesses ends it as a loss ("Game over"): the Pokémon and its full artwork are shown. Either way the day is finished and cannot be replayed; you can come back tomorrow.',
      'Finishing a day is saved, so reopening the app shows your result, not a new game.',
    ]),
    HelpBlock.paragraph('How the streak works:'),
    HelpBlock.bullets([
      'Winning today adds to your streak if you also won yesterday; otherwise a win starts a new streak of 1.',
      'Losing ends your streak straight away.',
      'Starting a new day does not reset your streak; it only ends if you lose or skip a whole day.',
      'A day counts once, however many times you open it. Your best streak, games played and win rate are shown below the clues.',
    ]),
    HelpBlock.tip(
      'The picture and clues need the day\'s Pokémon data. If you are offline and it has never been loaded, the page asks you to retry when you are connected. PokéPod has no server, so changing your device clock cannot be fully prevented; it will not let you replay a finished day or go back to an earlier one.',
    ),
  ]),
  HelpTopic(
    'notifications',
    Icons.notifications_active_outlined,
    'Streak reminders and notifications',
    [
      HelpBlock.paragraph(
        'PokéPod can send one optional, local reminder in the evening when your Who\'s That Pokémon? '
        'streak is at risk. It never leaves your device: there is no account, no server and nothing is uploaded.',
      ),
      HelpBlock.bullets([
        'Turning it on: Settings > Notifications holds the master switch and a separate switch for the '
            'Who\'s That Pokémon? streak reminder. On a brand-new install PokéPod also explains the '
            'reminder once on Discover before you have made any progress.',
        'The system permission is asked for only when you tap "Enable notifications". Choosing "Not '
            'now" (or dismissing the sheet) records your choice and PokéPod does not ask again.',
        'When it arrives: around 8pm local time, and only while you have an active streak and today\'s '
            'challenge is still unplayed.',
        'It is withdrawn automatically once you play today, when your streak ends, or when you switch '
            'notifications off, so a reminder can never outlive the situation it describes.',
        'Tapping the notification opens Who\'s That Pokémon?.',
        'If Android is blocking notifications, Settings > Notifications says so and offers an "Open '
            'settings" shortcut to the system permission screen.',
        'Reminders are inexact by design: Android may deliver one slightly after 8pm to save battery, '
            'and no exact-alarm permission is used.',
      ]),
      HelpBlock.tip(
        'Reminders and widgets are the only things PokéPod runs outside a screen you opened, and both '
        'stay on your device.',
      ),
    ],
  ),
  HelpTopic(
    'living-dex',
    Icons.visibility_outlined,
    'Living Dex and research progress',
    [
      HelpBlock.paragraph('Every Pokémon has one of four research stages:'),
      HelpBlock.bullets([
        'Unseen: you have not logged it.',
        'Discovered: set automatically the first time you open its dossier.',
        'Studied: set by you with "Mark Studied" in the dossier\'s Research log.',
        'Mastered: set by you with "Mark Mastered", only after Studied.',
      ]),
      HelpBlock.paragraph(
        'Progress moves up one step at a time and never by itself beyond Discovered. You can '
        'always use "Step back" or "Reset to unseen" to correct your log.',
      ),
      HelpBlock.paragraph(
        'Progress appears on the Discover progress card, on the Collections tab (Generation Dex Progress and Research by type) and on your Profile.',
      ),
    ],
  ),
  HelpTopic(
    'collections',
    Icons.collections_bookmark_outlined,
    'Collections and favourites',
    [
      HelpBlock.bullets([
        'Favourites: tap the heart on a tile, a list row or in a dossier. The Favourites filter in the Pokédex shows only them.',
        'Showcase: up to six featured Pokémon. Add them with Add on the Collections tab or Pin to showcase in a dossier, and drag to reorder.',
        'My collections: New creates one, and tapping it opens it. Use + to add Pokémon, or "Add to collection" in a dossier. The ⋮ menu renames or deletes it.',
        'Collection completion is "discovered of total": how many of its Pokémon you have discovered.',
        'Generation Dex Progress: pick a generation from the dropdown to see how many of its Pokémon you have discovered, studied and mastered, plus a scrolling list of them. Progress is discovered Pokémon divided by all Pokémon in that generation (for example 151 in Generation I). Undiscovered Pokémon show as silhouettes. Changing the generation only changes what you are looking at, never your progress.',
        'Recent research: the dossiers you opened most recently.',
      ]),
    ],
  ),
  HelpTopic('profile', Icons.person_outline, 'Trainer profile', [
    HelpBlock.paragraph(
      'The Profile tab is a short overview of you as a researcher. The menu icon (three lines) in the top-right corner opens Achievements, Research Journal and Settings, and below them Help & User Guide and About.',
    ),
    HelpBlock.paragraph('To change your name or avatar:'),
    HelpBlock.bullets([
      'Tap the pencil icon on the trainer card (or Settings > Trainer).',
      'Type a name of 1 to 20 characters. An empty name is not accepted.',
      'Tap "Choose avatar" to use any Pokémon\'s artwork, or "Remove" to go back to your initial.',
      'Tap Save to keep the changes, or Cancel to discard them.',
    ]),
    HelpBlock.paragraph('What the profile shows:'),
    HelpBlock.bullets([
      'Showcase: the Pokémon you pinned. Tap one to open it.',
      'Collection progress: your discovery percentage and a bar for each generation.',
      'Key statistics: studied, mastered, favourites and best streak.',
      'Favourite types: the types most common among your favourites (based on up to 20 of them).',
      'Recent activity, plus short previews of your achievements and journal.',
    ]),
    HelpBlock.tip(
      'Everything on your profile is stored only on this device. There is no account and nothing is uploaded. If you uninstall PokéPod or clear its data, your profile and progress are erased, so back them up first (see "Backing up and restoring your progress").',
    ),
  ]),
  HelpTopic('backup', Icons.save_alt_outlined, 'Backing up and restoring your progress', [
    HelpBlock.paragraph(
      'PokéPod keeps your progress on your device only, and it does not sync to the cloud. A backup is a block of text that you copy and keep yourself.',
    ),
    HelpBlock.paragraph('To back up:'),
    HelpBlock.bullets([
      'Open the menu on the Profile tab, then Settings.',
      'Under Data, tap "Backup progress".',
      'The backup is copied to your clipboard and a window lists what it contains.',
      'Paste it into a note, a message to yourself or an email and keep it somewhere safe. It is not saved as a file.',
    ]),
    HelpBlock.paragraph(
      'A backup contains: discovered, studied and mastered Pokémon, favourites, recent history, notes, collections, teams, your trainer profile and settings, and your Who\'s That Pokémon? history and streaks. It does not contain downloaded Pokémon data, which is fetched again when needed.',
    ),
    HelpBlock.paragraph('To restore:'),
    HelpBlock.bullets([
      'Go to Settings > Data > "Restore from backup".',
      'Paste your backup (or tap "Paste from clipboard") and tap "Check backup".',
      'PokéPod checks the backup and shows what it contains. If it is damaged, from a newer version or not a PokéPod backup, nothing is changed and you see why.',
      'Tap "Replace my progress" to confirm. This replaces the progress on this device for everything in the backup, and it cannot be undone. Anything not in the backup is kept.',
    ]),
    HelpBlock.tip(
      'Uninstalling the app or clearing its storage permanently erases local progress. Make a backup first if you want to keep it, and make a new one after big changes.',
    ),
  ]),
  HelpTopic('achievements', Icons.emoji_events_outlined, 'Achievements', [
    HelpBlock.paragraph(
      'There are 20 achievements. They unlock automatically from what you actually do, so nothing has '
      'to be claimed, and progress you already have counts towards them. Locked ones show a progress '
      'bar, and tapping any achievement shows its details.',
    ),
    HelpBlock.paragraph('Research, collections and teams:'),
    HelpBlock.bullets([
      'First Contact: discover your first Pokémon. Field Researcher: discover 25. Cataloguer: discover 100.',
      'Kanto Complete: discover all 151 Generation I Pokémon. World Tour: discover at least one '
          'Pokémon from every generation.',
      'Scholar: mark 10 Pokémon as Studied or Mastered. Mastery: master one.',
      'Field Notes: write notes for 3 Pokémon. Favourites: favourite 5.',
      'Curator: build a collection of 5 Pokémon. Team Architect: build a team of 6.',
    ]),
    HelpBlock.paragraph('Who\'s That Pokémon?:'),
    HelpBlock.bullets([
      'Mystery Solved: win once. Dedicated Challenger: win 50 challenges.',
      'Streak milestones, each read from your best streak: On a Roll (3), Blaze Keeper (10), Month of '
          'Mysteries (30), Seasoned Sleuth (60), Hundred-Day Hero (100), Shadow Master (150) and A '
          'Year Unbroken (365).',
    ]),
    HelpBlock.paragraph(
      'Every achievement carries a rarity tier with its own colour, chosen from nine tiers: Common, '
      'Uncommon, Rare, Epic, Double Rare, Ultra Rare, Illustration Rare, Special Illustration Rare '
      'and Hyper Rare. The tier says how demanding the achievement is, not how useful it is: Rare is '
      'gold, Epic is purple, and a 365-day streak is Hyper Rare. The tier and colour never change '
      'with your progress.',
    ),
  ]),
  HelpTopic('journal', Icons.menu_book_outlined, 'Research Journal', [
    HelpBlock.bullets([
      'The journal lists every Pokémon you have opened or written about.',
      'Entries are ordered by most recently opened, then by Pokédex number. PokéPod does not record dates for entries.',
      'Write or edit a note with the pencil on an entry, or in the "Research notes" box of the dossier. In the editor, Save keeps your note, Cancel discards changes and Delete removes it.',
      'Search by name, number or note text, and filter by All, With notes or Without notes.',
      'Tap an entry to open that Pokémon\'s dossier.',
    ]),
  ]),
  HelpTopic('settings', Icons.settings_outlined, 'Settings', [
    HelpBlock.bullets([
      'Theme: System follows your device, or choose Dark or Light.',
      'Accent Color: changes the highlight color used across the app.',
      'Trainer: edit your nickname and avatar.',
      'Notifications: the master switch for local reminders, the Who\'s That Pokémon? streak reminder, '
          'and a live reading of the Android permission with an "Open settings" shortcut when it is '
          'blocked. See "Streak reminders and notifications".',
      'Backup progress and Restore from backup: copy your progress as text and bring it back later. See "Backing up and restoring your progress".',
      'Connection to PokéAPI: shows whether the last request succeeded. It is information, not a switch.',
    ]),
    HelpBlock.paragraph(
      'PokéPod has no other settings, and none of them requires an account.',
    ),
  ]),
  HelpTopic('offline', Icons.cloud_off_outlined, 'Offline behaviour and data freshness', [
    HelpBlock.bullets([
      'Pokémon data is static, so PokéPod saves what it loads on your device and reuses it without asking PokéAPI again.',
      'Anything you have opened before (details, species text, evolution families, type lists) works offline.',
      'The catalogue is saved after its first load, so the Pokédex list works offline from then on.',
      'Artwork you have already seen is cached by the app; artwork you have never loaded cannot appear offline and shows a placeholder.',
      'The first time you open a Pokémon you need a connection.',
      'An Offline banner appears only after a request has actually failed. It does not mean your saved data is gone.',
      'Your own progress, notes, collections and teams never need a connection.',
    ]),
    HelpBlock.paragraph(
      'Saved data is not refreshed automatically. PokéPod always shows the data it saved the first time.',
    ),
  ]),
  HelpTopic('troubleshooting', Icons.build_outlined, 'Troubleshooting and FAQ', [
    HelpBlock.bullets([
      'Artwork does not load: check your connection and reopen the screen. A placeholder icon appears when the image cannot be fetched.',
      'Search shows nothing: check the spelling, or clear filters. Filters also apply to search.',
      'A filter returns no results: the combination may be empty (for example a type that does not exist in that generation). Use Clear filters.',
      'Data does not load: use the Retry button on the error message. You need a connection the first time you open something.',
      'The type progress shows "retry": reopen it or tap the row to try again.',
      'A screen shows no entries: it is empty because nothing has been added yet. Favourites, collections, teams and notes all start empty.',
      'Sorting by type, size, stats or Legendary & Mythical status seems incomplete: only Pokémon whose data is saved on your device can be placed. Narrow the filters and tap "Load N missing".',
      'Who\'s That Pokémon? cannot start: it needs the day\'s Pokémon data once. Reconnect and tap Retry.',
      'A home-screen widget is blank, shows a Pokéball or keeps an old specimen: open the app once so '
          'it can write today\'s specimen, then the widget updates in place.',
      'No streak reminder arrives: check Settings > Notifications. Both the PokéPod switch and the '
          'Android permission have to be on, and only an unplayed day with an active streak is worth reminding about.',
    ]),
  ]),
  HelpTopic('sources', Icons.info_outline, 'About and data sources', [
    HelpBlock.paragraph(
      'Pokémon information comes from PokéAPI (pokeapi.co) and artwork from the PokeAPI sprites '
      'repository. PokéPod is an unofficial fan project, not affiliated with or endorsed by '
      'Nintendo, The Pokémon Company or Game Freak. See About in the profile menu for details.',
    ),
  ]),
];
