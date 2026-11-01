import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A value over a label, used for rows of statistics.
///
/// Every readout has exactly the same structure (one value line, one label
/// line) and both lines scale down instead of wrapping, so a longer label such
/// as "Best streak" can never push its neighbours out of line.
class StatReadout extends StatelessWidget {
  const StatReadout({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(height: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                textAlign: TextAlign.center,
                style: readoutStyle(context, size: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
