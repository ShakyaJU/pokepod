import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/theme/tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/pokemon.dart';
import '../../data/providers.dart';
import '../../domain/generations.dart';
import '../../domain/mystery_logic.dart';
import '../mystery/mystery_controller.dart';

/// SharedPreferences keys shared with the native widget provider. The values
/// are written as strings so the Kotlin side can read them unambiguously from
/// `FlutterSharedPreferences`.
abstract final class WidgetKeys {
  static const dexId = 'pokepod.widget.dexId';
  static const name = 'pokepod.widget.name';
  static const dex = 'pokepod.widget.dex';
  static const types = 'pokepod.widget.types';
  static const typeColors = 'pokepod.widget.typeColors';
  static const generation = 'pokepod.widget.generation';
  static const description = 'pokepod.widget.description';
  static const height = 'pokepod.widget.height';
  static const weight = 'pokepod.widget.weight';
  static const date = 'pokepod.widget.date';
  static const artPath = 'pokepod.widget.artPath';
}

/// Everything the native widget renders, computed from the app's own daily
/// selection and locally available data. The size tiers stack up on these
/// fields: small shows identity (artwork, name, number, types, generation),
/// medium adds [description], large adds [height] and [weight]. Missing
/// pieces degrade gracefully: unknown name falls back to the Pokédex number,
/// unknown types render as an empty list, unknown measurements stay null so
/// the native side hides those rows, and a missing artwork path makes it show
/// its bundled placeholder.
class SpecimenWidgetData {
  const SpecimenWidgetData({
    required this.id,
    required this.name,
    required this.dex,
    required this.types,
    required this.dateKey,
    this.typeColors = const [],
    this.generation,
    this.description,
    this.height,
    this.weight,
    this.artPath,
  });

  final int id;
  final String name;
  final String dex;
  final List<String> types;

  /// [types] colours from the app's own `kTypeColors` palette, aligned with
  /// [typeLabel] segment by segment (may be shorter if types are unknown).
  final List<Color> typeColors;

  /// Compact generation, e.g. `Gen I`, from the same Roman numerals the app
  /// uses everywhere else.
  final String? generation;

  /// The species' Pokédex flavour text, exactly as the dossier shows it.
  final String? description;

  /// Physical measurements, already formatted the way the dossier formats
  /// them (`1.7 m` / `90.5 kg`), or null when the data is unavailable.
  final String? height;
  final String? weight;

  final String dateKey;
  final String? artPath;

  String get typeLabel => types.map((t) => titleCase(t)).join(' · ');

  /// Type colours as `#AARRGGBB`, in the same order as the segments of
  /// [typeLabel], so the native side can tint each badge without knowing
  /// anything about the palette.
  String get typeColorHex => typeColors
      .map(
        (c) =>
            '#${c.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0')}',
      )
      .join(',');
}

/// Sink abstraction (mirrors [SoundBackend]) so widget data flow is testable
/// without platform channels.
abstract class SpecimenWidgetDataSink {
  Future<void> writeSpecimen(SpecimenWidgetData data);

  /// Asks Android to re-render every Specimen widget instance.
  Future<void> requestUpdate();
}

/// Real sink backed by home_widget.
class HomeWidgetDataSink implements SpecimenWidgetDataSink {
  const HomeWidgetDataSink();

  /// Must match the native receiver class name. `qualifiedAndroidName` is
  /// used because it is already fully qualified: `androidName` would be
  /// resolved against the application id a second time.
  static const String _androidReceiver =
      'com.shakyaju.pokepod.SpecimenWidgetProvider';

  @override
  Future<void> writeSpecimen(SpecimenWidgetData data) async {
    await HomeWidget.saveWidgetData<String>(WidgetKeys.dexId, '${data.id}');
    await HomeWidget.saveWidgetData<String>(WidgetKeys.name, data.name);
    await HomeWidget.saveWidgetData<String>(WidgetKeys.dex, data.dex);
    await HomeWidget.saveWidgetData<String>(WidgetKeys.types, data.typeLabel);
    await HomeWidget.saveWidgetData<String>(
      WidgetKeys.typeColors,
      data.typeColorHex,
    );
    await HomeWidget.saveWidgetData<String>(
      WidgetKeys.generation,
      data.generation ?? '',
    );
    await HomeWidget.saveWidgetData<String>(
      WidgetKeys.description,
      data.description ?? '',
    );
    await HomeWidget.saveWidgetData<String>(
      WidgetKeys.height,
      data.height ?? '',
    );
    await HomeWidget.saveWidgetData<String>(
      WidgetKeys.weight,
      data.weight ?? '',
    );
    await HomeWidget.saveWidgetData<String>(WidgetKeys.date, data.dateKey);
    await HomeWidget.saveWidgetData<String>(
      WidgetKeys.artPath,
      data.artPath ?? '',
    );
  }

  @override
  Future<void> requestUpdate() =>
      HomeWidget.updateWidget(qualifiedAndroidName: _androidReceiver);
}

/// Keeps one downloaded official-artwork PNG per Pokédex number under the
/// app's documents directory, so the widget can render offline. A repeat day
/// never downloads again; a failed download leaves the previous state intact.
class SpecimenArtCache {
  SpecimenArtCache({Dio? dio, Future<String> Function()? directoryPath})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
            ),
          ),
      _directoryPath = directoryPath ?? _defaultDirectoryPath;

  final Dio _dio;
  final Future<String> Function() _directoryPath;

  static Future<String> _defaultDirectoryPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final widgetDir = Directory('${dir.path}/widget_art');
    if (!await widgetDir.exists()) {
      await widgetDir.create(recursive: true);
    }
    return widgetDir.path;
  }

  /// Returns the on-disk path of the artwork for [id], downloading it if it
  /// has never been cached. Null when it cannot be fetched right now.
  Future<String?> ensureArtwork(int id) async {
    try {
      final dirPath = await _directoryPath();
      final file = File('$dirPath/specimen_$id.png');
      if (await file.exists()) {
        return file.path;
      }
      final response = await _dio.get<List<int>>(
        artworkUrl(id),
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        return null;
      }
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}

final widgetDataSinkProvider = Provider<SpecimenWidgetDataSink>(
  (ref) => const HomeWidgetDataSink(),
);

final specimenArtCacheProvider = Provider<SpecimenArtCache>(
  (ref) => SpecimenArtCache(),
);

/// How long a refresh waits for data that is not cached yet. Cached values
/// (the normal case) short-circuit immediately; a cold or offline fetch is
/// cut off after this so a slow network can never hold a widget update
/// hostage — the midnight headless run only has a few seconds anyway.
const Duration kSpecimenWidgetDataTimeout = Duration(seconds: 6);

/// Waits for [read] unless [cached] already holds a value, falling back to
/// "nothing" on error or [timeout]. Widgets only ever show data the app
/// itself has, so an absent answer simply hides that part of the card.
Future<T?> _settled<T>(
  Future<T> Function() read,
  T? cached, {
  Duration timeout = kSpecimenWidgetDataTimeout,
}) async {
  if (cached != null) {
    return cached;
  }
  try {
    return await read().timeout(timeout);
  } catch (_) {
    return null;
  }
}

/// Widget text is optional: blank must read as "unknown", not as content.
String? _textOrNull(String? value) {
  if (value == null) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Writes today's Specimen of the Day into the widget data and asks Android
/// to re-render. The specimen id comes from the app's own selection function,
/// so the widget can never disagree with Discover. The catalogue, Pokédex
/// detail and species entry are all started together and awaited briefly, so
/// one app open writes the complete card (name, types, generation, Pokédex
/// description and measurements) instead of dribbling it in over refreshes.
/// Best-effort by design: any failure is swallowed so widgets can never
/// disturb the app.
Future<void> refreshSpecimenWidget(Ref ref) async {
  try {
    final today = ref.read(todayKeyProvider);
    final id = specimenOfDayId(today);

    // Read first, then await: every provider is touched synchronously before
    // the first suspension, so nothing depends on a later `ref`.
    final catalogState = ref.read(catalogProvider);
    final detailState = ref.read(pokemonDetailProvider(id));
    final speciesState = ref.read(speciesProvider(id));
    final sink = ref.read(widgetDataSinkProvider);

    final catalogFuture = _settled(
      () => ref.read(catalogProvider.future),
      catalogState.valueOrNull,
    );
    final detailFuture = _settled(
      () => ref.read(pokemonDetailProvider(id).future),
      detailState.valueOrNull,
    );
    final speciesFuture = _settled(
      () => ref.read(speciesProvider(id).future),
      speciesState.valueOrNull,
    );
    final artFuture = ref.read(specimenArtCacheProvider).ensureArtwork(id);

    final catalog = await catalogFuture;
    final detail = await detailFuture;
    final species = await speciesFuture;
    final artPath = await artFuture;

    final names = <int, PokemonSummary>{
      for (final summary in catalog ?? const <PokemonSummary>[])
        summary.id: summary,
    };
    final types = detail?.types ?? const <String>[];
    final generation = generationOf(id);

    await sink.writeSpecimen(
      SpecimenWidgetData(
        id: id,
        name: names[id]?.displayName ?? detail?.displayName ?? dexNumber(id),
        dex: dexNumber(id),
        types: types,
        typeColors: [for (final type in types) typeColor(type)],
        generation: generation == null
            ? null
            : 'Gen ${kRomanNumerals[generation - 1]}',
        description: _textOrNull(species?.flavorText),
        height: detail == null || detail.heightDm <= 0
            ? null
            : '${detail.heightM.toStringAsFixed(1)} m',
        weight: detail == null || detail.weightHg <= 0
            ? null
            : '${detail.weightKg.toStringAsFixed(1)} kg',
        dateKey: today,
        artPath: artPath,
      ),
    );
    await sink.requestUpdate();
  } catch (_) {
    // Widgets are an optional window into the app, never a requirement.
  }
}

/// Coordinator so UI code (which holds a WidgetRef) can trigger the sync
/// through Riverpod, with the real [Ref] the helper needs.
class SpecimenWidgetNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> refresh() => refreshSpecimenWidget(ref);
}

final specimenWidgetProvider = NotifierProvider<SpecimenWidgetNotifier, void>(
  SpecimenWidgetNotifier.new,
);
