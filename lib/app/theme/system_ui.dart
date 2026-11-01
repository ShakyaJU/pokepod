import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Status-bar and navigation-bar style for a theme: dark icons on light
/// themes, light icons on dark themes. The only place this is defined.
SystemUiOverlayStyle systemOverlayStyleFor(ThemeData theme) {
  final dark = theme.brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    // iOS describes the bar by the content behind it, the opposite of the icons.
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: theme.colorScheme.surfaceContainerLow,
    systemNavigationBarIconBrightness: dark
        ? Brightness.light
        : Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  );
}

/// Wraps the whole app once: applies the overlay style for the current theme,
/// reserves the status-bar height as part of the app's own background (no
/// separate band, no divider) and removes that height from the content's top
/// padding so screens do not add it twice.
class SystemUiScope extends StatelessWidget {
  const SystemUiScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      key: const Key('system-ui-region'),
      value: systemOverlayStyleFor(theme),
      child: ColoredBox(
        color: theme.colorScheme.surface,
        child: Column(
          children: [
            if (top > 0)
              // Reserves the status-bar height only: the colour comes from the
              // box above, so there is nothing here to draw a seam. Content
              // still starts below the icons.
              SizedBox(
                key: const Key('system-ui-status-strip'),
                width: double.infinity,
                height: top,
              ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
