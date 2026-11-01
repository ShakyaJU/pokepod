import 'package:flutter/material.dart';

import '../../app/design_system/expandable_section.dart';
import '../../app/design_system/widgets.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import 'help_content.dart';

/// Searchable, collapsible user guide for PokéPod.
class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  final TextEditingController _search = TextEditingController();
  final Map<String, GlobalKey> _keys = {
    for (final t in kHelpTopics) t.id: GlobalKey(),
  };
  String? _openId;
  bool _contentsOpen = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _jumpTo(String id) {
    setState(() {
      _openId = id;
      _contentsOpen = false;
      _search.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _keys[id]?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: Motion.medium,
          curve: Motion.curve,
          alignment: 0.05,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final query = _search.text.trim();
    final topics = [
      for (final t in kHelpTopics)
        if (query.isEmpty || t.matches(query)) t,
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Help & User Guide'),
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Panel(
              borderColor: scheme.primary.withValues(alpha: 0.4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.help_outline, color: scheme.primary),
                  const SizedBox(width: Space.md),
                  const Expanded(
                    child: Text(
                      'Welcome! This guide explains every part of PokéPod. Tap a topic to open '
                      'it, or search for a word such as "filter" or "streak".',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search the guide',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(_search.clear),
                      ),
                filled: true,
                fillColor: scheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.md),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
              ),
            ),
            const SizedBox(height: Space.md),
            if (query.isEmpty) ...[
              ExpandableSection(
                key: ValueKey('contents-$_contentsOpen'),
                title: 'Table of contents',
                subtitle: '${kHelpTopics.length} topics',
                leading: const Icon(Icons.list_alt_outlined),
                initiallyExpanded: _contentsOpen,
                child: Column(
                  children: [
                    for (var i = 0; i < kHelpTopics.length; i++)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: SizedBox(
                          width: 28,
                          child: Text(
                            '${i + 1}'.padLeft(2, '0'),
                            style: readoutStyle(context, color: scheme.primary),
                          ),
                        ),
                        title: Text(kHelpTopics[i].title),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => _jumpTo(kHelpTopics[i].id),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Space.md),
            ],
            if (topics.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Space.xl),
                child: EmptyState(
                  icon: Icons.search_off,
                  title: 'Nothing found',
                  message:
                      'Try a different word, or clear the search to see all topics.',
                ),
              )
            else
              for (final t in topics)
                Padding(
                  key: _keys[t.id],
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: ExpandableSection(
                    // A new key re-creates the section with its new initial state when a
                    // search starts, ends, or the table of contents jumps to it.
                    key: ValueKey(
                      '${t.id}-${query.isEmpty}-${_openId == t.id}',
                    ),
                    title: t.title,
                    leading: Icon(t.icon),
                    initiallyExpanded: query.isNotEmpty || _openId == t.id,
                    child: _TopicBody(topic: t),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _TopicBody extends StatelessWidget {
  const _TopicBody({required this.topic});

  final HelpTopic topic;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in topic.blocks)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: switch (block.kind) {
              HelpBlockKind.paragraph => Text(block.text ?? ''),
              HelpBlockKind.bullets => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in block.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 7, right: 10),
                            child: Icon(
                              Icons.circle,
                              size: 5,
                              color: scheme.primary,
                            ),
                          ),
                          Expanded(child: Text(item)),
                        ],
                      ),
                    ),
                ],
              ),
              HelpBlockKind.tip => Container(
                padding: const EdgeInsets.all(Space.sm),
                decoration: BoxDecoration(
                  color: scheme.tertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(Radii.sm),
                  border: Border.all(
                    color: scheme.tertiary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 18,
                      color: scheme.tertiary,
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        block.text ?? '',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            },
          ),
      ],
    );
  }
}
