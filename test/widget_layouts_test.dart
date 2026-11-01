import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Android side is not unit-testable here (no emulator on this host), so
/// this test pins the *contract* between the three layers that make the
/// widget work: the XML layouts, the Kotlin render path and the Dart
/// `WidgetKeys`. If any of them drifts — a renamed id, a missing id in one
/// size, a key the Kotlin side reads but Dart never writes — one of the
/// expectations below fails instead of the widget silently rendering blank
/// rows on someone's home screen.
void main() {
  final res = Directory('android/app/src/main/res');
  final layouts = {
    'compact': File('${res.path}/layout/widget_specimen_compact.xml'),
    'small': File('${res.path}/layout/widget_specimen_small.xml'),
    'medium': File('${res.path}/layout/widget_specimen_medium.xml'),
    'large': File('${res.path}/layout/widget_specimen_large.xml'),
  };
  final kotlin = File(
    'android/app/src/main/kotlin/com/shakyaju/pokepod/SpecimenWidgetProvider.kt',
  );
  final dart = File('lib/features/widgets/specimen_widget_sync.dart');

  /// Every id the Kotlin render path addresses. All four layouts must carry
  /// all of them so one render path can drive every size.
  const contractIds = [
    'widget_root',
    'widget_art',
    'widget_name',
    'widget_dex',
    'widget_gen',
    'widget_type_1',
    'widget_type_1_text',
    'widget_type_2',
    'widget_type_2_text',
    'widget_desc',
    'widget_measures',
    'widget_height_block',
    'widget_height',
    'widget_weight_block',
    'widget_weight',
  ];

  group('widget layouts', () {
    for (final entry in layouts.entries) {
      test('${entry.key} declares every id the provider binds', () {
        final xml = entry.value.readAsStringSync();
        for (final id in contractIds) {
          final occurrences = '@+id/$id"'.allMatches(xml).length;
          expect(
            occurrences,
            1,
            reason:
                'layout ${entry.key} must declare @+id/$id exactly once '
                '(found $occurrences)',
          );
        }
      });

      test('${entry.key} only ever clips or hides, never overlaps', () {
        final xml = entry.value.readAsStringSync();
        // The name, description and measurements are the pieces that must
        // degrade gracefully rather than being cut through the middle.
        expect(xml, contains('android:ellipsize="end"'));
        expect(xml, contains('android:maxLines="1"'));
      });
    }

    test('the four layouts are well-formed XML', () {
      for (final file in layouts.values) {
        final xml = file.readAsStringSync();
        expect(xml, contains('<?xml version="1.0" encoding="utf-8"?>'));
        // A crude but effective structural check: opening tags balance.
        final opens = RegExp('<[A-Za-z]').allMatches(xml).length;
        final closes = '</'.allMatches(xml).length;
        final selfClosing = '/>'.allMatches(xml).length;
        expect(
          closes + selfClosing,
          opens,
          reason: '${file.path} has unbalanced tags',
        );
      }
    });

    test('the launcher metadata points at layouts that exist', () {
      final info = File(
        '${res.path}/xml/specimen_widget_info.xml',
      ).readAsStringSync();
      final referenced = RegExp(
        r'android:\w*[Ll]ayout="@layout/(\w+)"',
      ).allMatches(info).map((m) => m.group(1)!).toSet();
      expect(referenced, isNotEmpty);
      for (final layout in referenced) {
        expect(
          File('${res.path}/layout/$layout.xml').existsSync(),
          isTrue,
          reason: '@layout/$layout is referenced by the widget metadata',
        );
      }
    });

    test('the banner size stays reachable on a one-row launcher', () {
      final info = File(
        '${res.path}/xml/specimen_widget_info.xml',
      ).readAsStringSync();
      final minHeight = int.parse(
        RegExp(r'android:minHeight="(\d+)dp"').firstMatch(info)!.group(1)!,
      );
      // Under ~96dp of height the provider falls back to the compact banner;
      // the metadata must allow widgets to be resized into that range.
      expect(minHeight, lessThan(96));
    });
  });

  group('provider <-> keys contract', () {
    test('the Kotlin provider only reads keys Dart writes', () {
      final kotlinSource = kotlin.readAsStringSync();
      final dartSource = dart.readAsStringSync();

      final kotlinKeys = RegExp(
        r'"(pokepod\.widget\.[A-Za-z]+)"',
      ).allMatches(kotlinSource).map((m) => m.group(1)!).toSet();
      final dartKeys = RegExp(
        "static const \\w+ = '(pokepod\\.widget\\.[A-Za-z]+)';",
      ).allMatches(dartSource).map((m) => m.group(1)!).toSet();

      expect(kotlinKeys, isNotEmpty);
      expect(dartKeys, isNotEmpty);
      expect(
        kotlinKeys.difference(dartKeys),
        isEmpty,
        reason: 'the Kotlin provider reads keys Dart never writes',
      );
      // Exactly the fields the card renders come from the native side; the
      // remaining two (dexId, date) are payload the app keeps for its own
      // record and for the midnight comparison, never rendered natively.
      expect(kotlinKeys, {
        'pokepod.widget.name',
        'pokepod.widget.dex',
        'pokepod.widget.types',
        'pokepod.widget.typeColors',
        'pokepod.widget.generation',
        'pokepod.widget.description',
        'pokepod.widget.height',
        'pokepod.widget.weight',
        'pokepod.widget.artPath',
      });
      expect(dartKeys.difference(kotlinKeys), {
        'pokepod.widget.dexId',
        'pokepod.widget.date',
      }, reason: 'the payload-only keys are exactly these two');
    });

    test('every view id the provider binds exists in every layout', () {
      final source = kotlin.readAsStringSync();
      final ids =
          RegExp(
              r'R\.id\.(\w+)',
            ).allMatches(source).map((m) => m.group(1)!).toSet()
            // The provider also reads `R.id.widget_*` through helper ids; keep
            // only view ids so string keys never leak in.
            ..removeWhere((id) => id.startsWith('pokepod'));

      expect(ids, isNotEmpty);
      for (final file in layouts.values) {
        final xml = file.readAsStringSync();
        for (final id in ids) {
          expect(
            '@+id/$id"'.allMatches(xml).length,
            1,
            reason:
                'the provider binds R.id.$id but ${file.path} '
                'declares it ${'@+id/$id"'.allMatches(xml).length} times',
          );
        }
      }
    });

    test('the drawable and strings the provider needs exist', () {
      final source = kotlin.readAsStringSync();
      final strings = RegExp(
        r'R\.string\.(\w+)',
      ).allMatches(source).map((m) => m.group(1)!).toSet();
      final stringsXml = File(
        '${res.path}/values/widget_labels.xml',
      ).readAsStringSync();
      for (final name in strings) {
        expect(
          stringsXml,
          contains('name="$name"'),
          reason: 'R.string.$name is referenced but never declared',
        );
      }
      // Layouts reference these too.
      final layoutStrings = <String>{};
      for (final file in layouts.values) {
        layoutStrings.addAll(
          RegExp(
            r'@string/(\w+)',
          ).allMatches(file.readAsStringSync()).map((m) => m.group(1)!),
        );
      }
      for (final name in layoutStrings) {
        expect(stringsXml, contains('name="$name"'));
      }
    });

    test('the layouts reference resources that exist', () {
      final drawables = Directory('${res.path}/drawable')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last.split('.').first)
          .toSet();
      for (final file in layouts.values) {
        final xml = file.readAsStringSync();
        final referenced = RegExp(
          r'@drawable/(\w+)',
        ).allMatches(xml).map((m) => m.group(1)!).toSet();
        for (final name in referenced) {
          expect(
            drawables,
            contains(name),
            reason: '${file.path} references @drawable/$name',
          );
        }
      }
    });
  });
}
