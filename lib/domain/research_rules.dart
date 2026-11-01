/// A Pokémon's personal research stage. Order matters: it is the progression.
enum ResearchState { unseen, discovered, studied, mastered }

extension ResearchStateX on ResearchState {
  String get label => switch (this) {
    ResearchState.unseen => 'Unseen',
    ResearchState.discovered => 'Discovered',
    ResearchState.studied => 'Studied',
    ResearchState.mastered => 'Mastered',
  };
}

class ResearchRules {
  const ResearchRules._();

  /// Rules:
  /// * Progress moves up exactly one stage at a time and only by an explicit
  ///   action (mastery is never granted by merely opening a page).
  /// * Users may always step back down to any lower stage to correct their log.
  static bool canTransition(ResearchState from, ResearchState to) {
    if (from == to) {
      return false;
    }
    if (to.index < from.index) {
      return true;
    }
    return to.index == from.index + 1;
  }

  /// The next stage up, or null when already mastered.
  static ResearchState? next(ResearchState from) =>
      from == ResearchState.mastered
      ? null
      : ResearchState.values[from.index + 1];
}
