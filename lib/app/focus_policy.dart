/// PokéPod's global keyboard and focus lifecycle.
///
/// Text inputs live in several different kinds of host: tab pages that the
/// shell's `PageView` keeps alive, pushed routes, modal bottom sheets and
/// dialogs. Flutter only moves primary focus when the *focus scope* changes,
/// and switching tabs does not — every tab lives inside the same route scope.
/// A search field focused on one tab therefore used to keep the soft keyboard
/// open while another tab was already on screen, and returning to a route
/// could restore focus to a field the user had left behind.
///
/// The policy is to release text focus at the navigation boundaries where it
/// can legitimately change:
///
///  * [releaseTextFocus] whenever the selected tab changes (`HomeShell`), and
///  * [releaseTextFocus] on every route push, pop, removal and replacement
///    (the [FocusReleaseObserver] registered on the app's navigator).
///
/// Focus is only released in response to those events — never on widget
/// rebuilds — so tapping a text field still opens the keyboard normally and
/// no timers or arbitrary delays are involved.
library;

import 'package:flutter/widgets.dart';

/// Releases primary focus so any open soft keyboard is dismissed.
///
/// Returns `true` when a real focus node held primary focus and was
/// unfocused, and `false` when nothing (or only the root scope) was focused,
/// which is the common case and a harmless no-op.
bool releaseTextFocus() {
  final manager = FocusManager.instance;
  final primary = manager.primaryFocus;
  // With nothing focused, `primaryFocus` reports the root scope itself.
  if (primary == null || identical(primary, manager.rootScope)) {
    return false;
  }
  primary.unfocus();
  return true;
}

/// Releases text focus whenever a route is pushed, popped, removed or
/// replaced.
///
/// Pushing a route must not carry an unrelated focused field into the new
/// route, and popping one must leave the route underneath in a clean focus
/// state instead of restoring a keyboard the user has finished with.
class FocusReleaseObserver extends NavigatorObserver {
  FocusReleaseObserver();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      releaseTextFocus();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      releaseTextFocus();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      releaseTextFocus();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      releaseTextFocus();
}
