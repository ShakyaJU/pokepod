import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokepod/app/theme/tokens.dart';
import 'package:pokepod/core/utils/formatters.dart';
import 'package:pokepod/data/models/pokemon.dart';
import 'package:pokepod/data/providers.dart';
import 'package:pokepod/domain/generations.dart';
import 'package:pokepod/domain/mystery_logic.dart';
import 'package:pokepod/features/mystery/mystery_controller.dart';
import 'package:pokepod/features/widgets/specimen_widget_sync.dart';

import 'support/support.dart';

const String kDay = '2026-10-30';
const String kNextDay = '2026-10-31';

/// A clock a test can move forward by hand. `clockProvider` reads it live, so
/// shifting [now] plus a day tick reproduces midnight exactly the way the app
/// sees it.
class Clock {
  Clock(this.now);

  DateTime now;
}

/// Records what the app hands to the home-screen widgets.
class FakeSink implements SpecimenWidgetDataSink {
  final List<SpecimenWidgetData> writes = [];
  int updates = 0;
  bool failWrites = false;

  @override
  Future<void> writeSpecimen(SpecimenWidgetData data) async {
    if (failWrites) {
      throw StateError('the widget store is unavailable');
    }
    writes.add(data);
  }

  @override
  Future<void> requestUpdate() async => updates++;
}

/// Serves artwork without any network access.
class FakeArtCache extends SpecimenArtCache {
  FakeArtCache({this.artPath});

  final String? artPath;

  @override
  Future<String?> ensureArtwork(int id) async => artPath;
}

/// Scripted HTTP layer for the real [SpecimenArtCache].
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter({this.bytes, this.fail = false});

  final List<int>? bytes;
  final bool fail;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (fail) {
      throw StateError('offline in tests');
    }
    return ResponseBody.fromBytes(
      Uint8List.fromList(bytes ?? const []),
      200,
      headers: {
        Headers.contentTypeHeader: ['image/png'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  /// Builds a container that already knows today's Pokémon, with everything
  /// platform-facing replaced by a fake and every async provider settled, so
  /// the sync never sees a half-loaded catalogue. Detail providers are
  /// overridden for every id the file can reach: a catalogue entry, plus the
  /// ids selected today and tomorrow, so nothing ever falls through to the
  /// real repository and its network calls.
  Future<ProviderContainer> buildContainer({
    required FakeSink sink,
    String? artPath,
    List<PokemonSummary> catalog = const [],
    Clock? clock,
    int heightDm = 10,
    int weightHg = 100,
  }) async {
    final time = clock ?? Clock(DateTime(2026, 10, 30, 14, 30));
    final prefs = await mockPrefs();
    final reachableIds = <int>{
      specimenOfDayId(localDateKey(time.now)),
      specimenOfDayId(localDateKey(time.now.add(const Duration(days: 1)))),
      for (final summary in catalog) summary.id,
    };

    final overrides = <Override>[
      clockProvider.overrideWithValue(() => time.now),
      widgetDataSinkProvider.overrideWithValue(sink),
      specimenArtCacheProvider.overrideWithValue(
        FakeArtCache(artPath: artPath),
      ),
      catalogProvider.overrideWith((ref) async => catalog),
      for (final summary in catalog)
        pokemonDetailProvider(summary.id).overrideWith(
          (ref) async => makeDetail(
            summary.id,
            summary.name,
            const ['fire', 'flying'],
            heightDm: heightDm,
            weightHg: weightHg,
          ),
        ),
      // Species mirror the catalogue too, so the description the widget shows
      // is the very text the dossier would show, with no network involved.
      for (final summary in catalog)
        speciesProvider(summary.id).overrideWith(
          (ref) async => PokemonSpecies(
            id: summary.id,
            flavorText: 'Pokédex entry for ${summary.name}.',
            generationId: generationOf(summary.id),
          ),
        ),
      for (final id in reachableIds)
        if (!catalog.any((p) => p.id == id))
          pokemonDetailProvider(id).overrideWith(
            (ref) => Future<PokemonDetail>.error(
              StateError('this test has no detail for #$id'),
            ),
          ),
      for (final id in reachableIds)
        if (!catalog.any((p) => p.id == id))
          speciesProvider(id).overrideWith(
            (ref) => Future<PokemonSpecies>.error(
              StateError('this test has no species for #$id'),
            ),
          ),
    ];

    final container = makeContainer(prefs, overrides: overrides);
    await container.read(catalogProvider.future);
    for (final summary in catalog) {
      await container.read(pokemonDetailProvider(summary.id).future);
    }
    return container;
  }

  group('native contract', () {
    test('the stored keys are exactly what the Kotlin side reads', () {
      expect(WidgetKeys.dexId, 'pokepod.widget.dexId');
      expect(WidgetKeys.name, 'pokepod.widget.name');
      expect(WidgetKeys.dex, 'pokepod.widget.dex');
      expect(WidgetKeys.types, 'pokepod.widget.types');
      expect(WidgetKeys.typeColors, 'pokepod.widget.typeColors');
      expect(WidgetKeys.generation, 'pokepod.widget.generation');
      expect(WidgetKeys.description, 'pokepod.widget.description');
      expect(WidgetKeys.height, 'pokepod.widget.height');
      expect(WidgetKeys.weight, 'pokepod.widget.weight');
      expect(WidgetKeys.date, 'pokepod.widget.date');
      expect(WidgetKeys.artPath, 'pokepod.widget.artPath');
    });

    test('the type list is rendered the way the widget layouts show it', () {
      const data = SpecimenWidgetData(
        id: 6,
        name: 'Charizard',
        dex: '#0006',
        types: ['fire', 'flying'],
        dateKey: kDay,
      );
      expect(data.typeLabel, 'Fire · Flying');
      expect(
        const SpecimenWidgetData(
          id: 6,
          name: 'Charizard',
          dex: '#0006',
          types: [],
          dateKey: kDay,
        ).typeLabel,
        isEmpty,
      );
    });

    test('the colours travel in the same order as the labels', () {
      const data = SpecimenWidgetData(
        id: 6,
        name: 'Charizard',
        dex: '#0006',
        types: ['fire', 'flying'],
        typeColors: [Color(0xFFEE8130), Color(0xFFA0A0FF)],
        dateKey: kDay,
      );
      // #AARRGGBB per segment, comma separated — the palette's own values.
      expect(data.typeColorHex, '#FFEE8130,#FFA0A0FF');
      expect(
        const SpecimenWidgetData(
          id: 6,
          name: 'Charizard',
          dex: '#0006',
          types: [],
          dateKey: kDay,
        ).typeColorHex,
        isEmpty,
      );
    });
  });

  group('refreshSpecimenWidget', () {
    test('writes the very Pokémon Discover shows today', () async {
      final sink = FakeSink();
      final expectedId = specimenOfDayId(kDay);
      final container = await buildContainer(
        sink: sink,
        artPath: '/tmp/specimen_art.png',
        catalog: [PokemonSummary(id: expectedId, name: 'charmander')],
      );

      await container.read(specimenWidgetProvider.notifier).refresh();

      expect(sink.writes, hasLength(1));
      final written = sink.writes.single;
      expect(written.id, expectedId, reason: 'the app\'s own selection');
      expect(written.name, 'Charmander', reason: 'from the catalogue entry');
      expect(written.dex, dexNumber(expectedId));
      expect(written.types, const ['fire', 'flying']);
      expect(written.dateKey, kDay);
      expect(written.artPath, '/tmp/specimen_art.png');
      expect(sink.updates, 1, reason: 'the launcher is asked to redraw');

      // The progressive pieces: generation comes from the app's own ranges,
      // the description is the species entry, and the measurements use the
      // dossier's formatting — all for the same specimen.
      expect(
        written.generation,
        'Gen ${kRomanNumerals[generationOf(expectedId)! - 1]}',
      );
      expect(written.description, 'Pokédex entry for charmander.');
      expect(written.height, '1.0 m');
      expect(written.weight, '10.0 kg');
      expect(written.typeColors, [
        kTypeColors['fire'],
        kTypeColors['flying'],
      ], reason: 'the app\'s own type palette, in order');
    });

    test('follows the day across midnight', () async {
      final sink = FakeSink();
      final clock = Clock(DateTime(2026, 10, 30, 14, 30));
      final container = await buildContainer(
        sink: sink,
        clock: clock,
        catalog: [
          for (final id in {specimenOfDayId(kDay), specimenOfDayId(kNextDay)})
            PokemonSummary(id: id, name: 'p$id'),
        ],
      );

      await container.read(specimenWidgetProvider.notifier).refresh();
      final first = sink.writes.single;

      // Midnight: the clock moves and the shell bumps the day tick, which is
      // what makes the app re-read the date instead of trusting a stale one.
      clock.now = DateTime(2026, 10, 31, 0, 10);
      container.read(dayTickProvider.notifier).state++;
      await container.read(specimenWidgetProvider.notifier).refresh();

      expect(sink.writes, hasLength(2));
      final second = sink.writes.last;
      expect(first.dateKey, kDay);
      expect(second.dateKey, kNextDay);
      expect(second.id, specimenOfDayId(kNextDay));
      expect(sink.updates, 2);
    });

    test('never invents a name it does not have', () async {
      final sink = FakeSink();
      final container = await buildContainer(sink: sink);

      await container.read(specimenWidgetProvider.notifier).refresh();

      final written = sink.writes.single;
      expect(written.id, specimenOfDayId(kDay));
      expect(written.name, dexNumber(written.id));
      expect(written.types, isEmpty);
      expect(written.typeColors, isEmpty);
      expect(written.description, isNull);
      expect(written.height, isNull);
      expect(written.weight, isNull);
      expect(
        written.generation,
        isNotNull,
        reason: 'the generation comes from the offline dex ranges',
      );
      expect(written.artPath, isNull);
      expect(sink.updates, 1);
    });

    test(
      'unknown measurements are left out instead of shown as zero',
      () async {
        final sink = FakeSink();
        final container = await buildContainer(
          sink: sink,
          heightDm: 0,
          weightHg: 0,
          catalog: [
            PokemonSummary(id: specimenOfDayId(kDay), name: 'charmander'),
          ],
        );

        await container.read(specimenWidgetProvider.notifier).refresh();

        final written = sink.writes.single;
        expect(written.height, isNull);
        expect(written.weight, isNull);
        expect(written.types, isNotEmpty, reason: 'the types are still known');
      },
    );

    test('a broken widget store cannot disturb the app', () async {
      final sink = FakeSink()..failWrites = true;
      final container = await buildContainer(sink: sink);

      await container.read(specimenWidgetProvider.notifier).refresh();

      expect(sink.writes, isEmpty);
      expect(sink.updates, 0);
    });
  });

  group('SpecimenArtCache', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('pokepod_art_test');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('an already downloaded file is reused without a request', () async {
      final existing = File('${tempDir.path}/specimen_25.png')
        ..writeAsBytesSync(kTestPixel);
      final adapter = _ScriptedAdapter(bytes: kTestPixel);
      final cache = SpecimenArtCache(
        dio: Dio()..httpClientAdapter = adapter,
        directoryPath: () async => tempDir.path,
      );

      final path = await cache.ensureArtwork(25);

      expect(path, existing.path);
      expect(adapter.requests, isEmpty);
    });

    test(
      'the first request downloads the artwork and the second one caches',
      () async {
        final adapter = _ScriptedAdapter(bytes: kTestPixel);
        final cache = SpecimenArtCache(
          dio: Dio()..httpClientAdapter = adapter,
          directoryPath: () async => tempDir.path,
        );

        final path = await cache.ensureArtwork(6);
        expect(path, isNotNull);
        expect(File(path!).readAsBytesSync(), kTestPixel);
        expect(adapter.requests, hasLength(1));
        expect(adapter.requests.single.uri.toString(), contains('/6'));

        final again = await cache.ensureArtwork(6);
        expect(again, path);
        expect(adapter.requests, hasLength(1), reason: 'no second download');
      },
    );

    test('offline artwork leaves the widget on its placeholder', () async {
      final adapter = _ScriptedAdapter(fail: true);
      final cache = SpecimenArtCache(
        dio: Dio()..httpClientAdapter = adapter,
        directoryPath: () async => tempDir.path,
      );

      expect(await cache.ensureArtwork(150), isNull);
    });
  });
}
