import 'package:flutter/material.dart';

import '../../app/design_system/expandable_section.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../domain/mystery_logic.dart';
import '../shared/navigation.dart';

/// How many results the expanded history lists before it asks for more.
const int kMysteryHistoryPageSize = 5;

/// The daily game's results, collapsed to a single summary row by default.
///
/// Every finished day is kept forever, but printing all of them inline made
/// the game screen grow a little longer every day, which buried the challenge
/// above them. The header therefore summarises the whole record (how many
/// days were played, how many were solved, what the latest result was) and
/// the list itself appears on demand: newest first,
/// [kMysteryHistoryPageSize] entries at a time, with a control to page further
/// back. Nothing here writes to the records — the section only reads the map
/// it is handed.
class MysteryHistory extends StatefulWidget {
  const MysteryHistory({super.key, required this.history});

  /// The finished days, keyed by their `YYYY-MM-DD` local date. Read-only.
  final Map<String, MysteryRecord> history;

  @override
  State<MysteryHistory> createState() => _MysteryHistoryState();
}

class _MysteryHistoryState extends State<MysteryHistory> {
  /// How many of the newest entries are currently listed. It is deliberately
  /// kept across collapse/expand cycles, so closing the section and reopening
  /// it never throws away paging the user asked for.
  int _visible = kMysteryHistoryPageSize;

  /// Newest first. ISO date keys compare in calendar order.
  List<String> get _newestFirst =>
      widget.history.keys.toList()..sort((a, b) => b.compareTo(a));

  /// One line over the whole record, derived straight from the same map the
  /// list shows — never a separate tally that could disagree with it.
  String _summary(int total, int solved, MysteryRecord latest) {
    final last = latest.won
        ? 'last: solved in ${latest.guesses}'
        : 'last: not solved';
    return '$total ${total == 1 ? 'day' : 'days'} · $solved solved · $last';
  }

  @override
  Widget build(BuildContext context) {
    final days = _newestFirst;
    final total = days.length;
    final solved = days.where((d) => widget.history[d]!.won).length;
    final shown = _visible.clamp(0, total);

    return ExpandableSection(
      title: 'History',
      subtitle: total == 0
          ? 'No days recorded yet.'
          : _summary(total, solved, widget.history[days.first]!),
      leading: const Icon(Icons.history_outlined),
      child: total == 0
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final day in days.take(shown))
                  _HistoryRow(day: day, record: widget.history[day]!),
                if (shown < total)
                  Center(
                    child: TextButton.icon(
                      onPressed: () => setState(
                        () => _visible = shown + kMysteryHistoryPageSize,
                      ),
                      icon: const Icon(Icons.expand_more, size: 18),
                      label: Text(
                        'Show ${total - shown} older '
                        '${total - shown == 1 ? 'day' : 'days'}',
                      ),
                    ),
                  )
                else if (total > kMysteryHistoryPageSize)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.xs),
                    child: Center(
                      child: Text(
                        'All $total days shown',
                        style: readoutStyle(
                          context,
                          size: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// One compact result row: outcome icon, the day it belonged to, and how many
/// of the six guesses it took. Tapping opens that day's answer, but only when
/// the record actually stores one (records saved by older versions do not).
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.day, required this.record});

  final String day;
  final MysteryRecord record;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        record.won ? Icons.check_circle_outline : Icons.cancel_outlined,
        color: record.won ? scheme.primary : scheme.error,
        semanticLabel: record.won ? 'Solved' : 'Not solved',
      ),
      title: Text(day),
      trailing: Text('${record.guesses}/$kMysteryMaxGuesses'),
      // A legacy record without its answer is still listed, just not tappable.
      onTap: record.target == null
          ? null
          : () => openDossier(context, record.target!),
    );
  }
}
