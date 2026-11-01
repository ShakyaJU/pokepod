import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../help/help_page.dart';
import 'about_page.dart';
import 'achievements_page.dart';
import 'journal_page.dart';
import 'profile_controller.dart';
import 'settings_page.dart';

/// Slides a full-height menu in from the right edge (the profile's hamburger
/// menu). Each entry closes the menu and opens its existing page.
Future<void> showProfileMenu(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close profile menu',
    barrierColor: Colors.black54,
    transitionDuration: Motion.medium,
    pageBuilder: (context, animation, secondaryAnimation) =>
        const _ProfileMenuPanel(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Motion.curve,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

class _ProfileMenuPanel extends ConsumerWidget {
  const _ProfileMenuPanel();

  void _open(BuildContext context, Widget page) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final nickname = ref.watch(profileProvider.select((p) => p.nickname));
    final width = math.min(340.0, MediaQuery.of(context).size.width * 0.86);

    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: width,
        height: double.infinity,
        child: Material(
          color: scheme.surfaceContainerLow,
          elevation: 8,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.md,
                    Space.md,
                    Space.sm,
                    Space.sm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Image.asset(
                              'assets/branding/pokepod_logo.png',
                              height: 34,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              semanticLabel: 'PokéPod',
                            ),
                            const SizedBox(height: Space.sm),
                            Text(
                              'TRAINER MENU',
                              style: readoutStyle(context, size: 10),
                            ),
                            Text(
                              nickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close menu',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: Space.sm),
                    children: [
                      _MenuTile(
                        key: const Key('menu-achievements'),
                        icon: Icons.emoji_events_outlined,
                        title: 'Achievements',
                        subtitle: 'Milestones you have earned',
                        onTap: () => _open(context, const AchievementsPage()),
                      ),
                      _MenuTile(
                        key: const Key('menu-journal'),
                        icon: Icons.menu_book_outlined,
                        title: 'Research Journal',
                        subtitle: 'Your field notes and research log',
                        onTap: () => _open(context, const JournalPage()),
                      ),
                      _MenuTile(
                        key: const Key('menu-settings'),
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        subtitle: 'Appearance, data and trainer',
                        onTap: () => _open(context, const SettingsPage()),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: Space.sm),
                        child: Divider(height: 1),
                      ),
                      _MenuTile(
                        key: const Key('menu-help'),
                        icon: Icons.help_outline,
                        title: 'Help & User Guide',
                        subtitle: 'How to use every part of PokéPod',
                        onTap: () => _open(context, const HelpPage()),
                      ),
                      _MenuTile(
                        key: const Key('menu-about'),
                        icon: Icons.info_outline,
                        title: 'About',
                        subtitle: 'Credits, licences and legal',
                        onTap: () => _open(context, const AboutPage()),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Text(
                    '© ShakyaJU',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.6,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      minVerticalPadding: Space.sm,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: 2,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Icon(icon, color: scheme.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
