import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/design_system/widgets.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';

/// About PokéPod. Only information that is true of this project is shown;
/// there is deliberately no version number, website or contact details.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _features = <(IconData, String, String)>[
    (
      Icons.explore_outlined,
      'Discover',
      'A daily dashboard with a specimen of the day and your progress.',
    ),
    (
      Icons.grid_view_rounded,
      'Pokédex',
      'Search, filter and sort all 1025 Pokémon of the national dex.',
    ),
    (
      Icons.hub_outlined,
      'Evolution Constellation',
      'Explore evolution families as a zoomable graph.',
    ),
    (
      Icons.biotech_outlined,
      'Pokémon DNA',
      'Compare the base stats, types and defences of two Pokémon.',
    ),
    (
      Icons.groups_outlined,
      'Team Architect',
      'Build teams of up to six and review type coverage.',
    ),
    (
      Icons.psychology_alt_outlined,
      'Who\'s That Pokémon?',
      'A daily guessing game with progressive clues and streaks.',
    ),
    (
      Icons.collections_bookmark_outlined,
      'Collections',
      'Favourites, custom collections and Living Dex progress.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('About'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.xl),
        children: [
          Center(
            child: Column(
              children: [
                Image.asset(
                  'assets/branding/pokepod_logo.png',
                  width: math.min(
                    MediaQuery.of(context).size.width * 0.72,
                    320.0,
                  ),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  semanticLabel: 'PokéPod',
                ),
                const SizedBox(height: Space.md),
                Text(
                  'Beyond the Pokédex',
                  style: readoutStyle(context, color: scheme.primary, size: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),
          Text(
            'PokéPod is a Pokémon research and discovery companion. It turns the Pokédex into '
            'a personal research device: you browse specimens, log what you have discovered, '
            'studied and mastered, compare Pokémon, plan teams and keep your own field notes.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: Space.lg),
          const SectionLabel('What you can do'),
          for (final (icon, title, text) in _features)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Panel(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: scheme.primary),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            text,
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: Space.md),
          const SectionLabel('Data sources and credits'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Credit(
                  title: 'Pokémon data',
                  text:
                      'Stats, types, abilities, species text and evolution data come from PokéAPI '
                      '(pokeapi.co), a free community-run service.',
                ),
                const _Credit(
                  title: 'Pokémon artwork',
                  text:
                      'Artwork is loaded from the PokeAPI sprites repository on GitHub '
                      '(github.com/PokeAPI/sprites). The artwork, names and characters are the '
                      'property of Nintendo, Creatures Inc., GAME FREAK inc. and The Pokémon Company. '
                      'PokéPod does not own them and does not claim any licence to them.',
                ),
                const _Credit(
                  title: 'PokéPod logo',
                  text:
                      'The PokéPod wordmark was supplied by the app\'s author for this project.',
                ),
                const _Credit(
                  title: 'Sound effects',
                  text:
                      'The sound effects used in PokéPod were sourced through Zedge App. '
                      'Browse and download more at zedge.net.',
                  link: 'https://www.zedge.net',
                ),
                const _Credit(
                  title: 'Software',
                  text:
                      'Built with Flutter (BSD-3-Clause), Riverpod (MIT), Dio (MIT), '
                      'shared_preferences (BSD-3-Clause), cached_network_image (MIT), '
                      'audioplayers (MIT), home_widget (MIT), flutter_local_notifications (MIT), '
                      'flutter_timezone (MIT), timezone (Apache-2.0), path_provider (BSD-3-Clause) '
                      'and url_launcher (MIT).',
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          const SectionLabel('Privacy'),
          const Panel(
            child: Text(
              'Everything you create in PokéPod stays on your device. There are no accounts and '
              'no analytics. The app only contacts PokéAPI and the artwork host to load Pokémon '
              'information.',
            ),
          ),
          const SizedBox(height: Space.md),
          const SectionLabel('Disclaimer'),
          Panel(
            borderColor: scheme.tertiary.withValues(alpha: 0.5),
            child: const Text(
              'PokéPod is an unofficial fan project. It is not affiliated with, endorsed by or '
              'sponsored by Nintendo, GAME FREAK or The Pokémon Company. Pokémon and related '
              'names, characters and artwork are trademarks and copyrights of their respective '
              'owners. This notice does not grant any rights to that material.',
            ),
          ),
        ],
      ),
    );
  }
}

class _Credit extends StatelessWidget {
  const _Credit({required this.title, required this.text, this.link});

  final String title;
  final String text;

  /// Optional external page, opened in the system browser. Shown as a real
  /// link so the credit can be followed, not just read.
  final String? link;

  Future<void> _openLink() async {
    final uri = Uri.parse(link!);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // A device without a usable browser must not break the About page.
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(
            text,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          if (link != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: TextButton.icon(
                onPressed: _openLink,
                icon: const Icon(Icons.open_in_new, size: 15),
                label: Text(
                  link!.replaceFirst(RegExp(r'^https?://'), ''),
                  style: const TextStyle(fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
