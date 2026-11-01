import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// What a backup contains, in plain counts for the confirmation screen.
class BackupSummary {
  const BackupSummary({
    this.discovered = 0,
    this.favourites = 0,
    this.collections = 0,
    this.teams = 0,
    this.notes = 0,
    this.challengeDays = 0,
    this.hasProfile = false,
  });

  final int discovered;
  final int favourites;
  final int collections;
  final int teams;
  final int notes;
  final int challengeDays;
  final bool hasProfile;

  List<String> get lines => [
    if (discovered > 0) '$discovered discovered Pokémon',
    if (favourites > 0) '$favourites favourite${favourites == 1 ? '' : 's'}',
    if (collections > 0)
      '$collections collection${collections == 1 ? '' : 's'}',
    if (teams > 0) '$teams team${teams == 1 ? '' : 's'}',
    if (notes > 0) '$notes note${notes == 1 ? '' : 's'}',
    if (challengeDays > 0)
      '$challengeDays day${challengeDays == 1 ? '' : 's'} of Who\'s That Pokémon? history',
    if (hasProfile) 'Trainer profile and settings',
  ];
}

class ParsedBackup {
  const ParsedBackup({
    required this.data,
    required this.summary,
    this.exportedAt,
  });

  /// Decoded values keyed by storage key; every entry has been validated.
  final Map<String, Object> data;
  final BackupSummary summary;
  final DateTime? exportedAt;
}

/// Local-only backup of the user's own progress as text. Nothing is uploaded.
/// Cached PokéAPI data is deliberately not included; it is re-downloaded on demand.
class BackupService {
  const BackupService._();

  static const String appId = 'pokepod';
  static const int formatVersion = 1;

  /// Storage keys that make up the user's progress.
  static const List<String> keys = [
    'research.v1',
    'favourites.v1',
    'recent.v1',
    'notes.v1',
    'collections.v1',
    'teams.v1',
    'profile.v1',
    'mystery.v1',
  ];

  static String export(SharedPreferences prefs, {DateTime? now}) {
    final data = <String, Object>{};
    for (final key in keys) {
      final raw = prefs.getString(key);
      if (raw == null) {
        continue;
      }
      try {
        final decoded = jsonDecode(raw);
        if (decoded != null) {
          data[key] = decoded as Object;
        }
      } catch (_) {
        // Unreadable stored data is left out of the backup rather than copied.
      }
    }
    return jsonEncode({
      'app': appId,
      'format': formatVersion,
      'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'data': data,
    });
  }

  /// Validates [text]. Throws [BackupException] with a user-readable message
  /// and changes nothing.
  static ParsedBackup parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const BackupException('Paste a backup first.');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      throw const BackupException(
        'That is not a PokéPod backup. Copy the whole backup text and try again.',
      );
    }
    if (decoded is! Map<String, dynamic> || decoded['app'] != appId) {
      throw const BackupException('That text is not a PokéPod backup.');
    }
    final format = decoded['format'];
    if (format is! int) {
      throw const BackupException(
        'This backup has no version number, so it cannot be checked.',
      );
    }
    if (format > formatVersion) {
      throw const BackupException(
        'This backup was made by a newer version of PokéPod. Update the app and try again.',
      );
    }
    final rawData = decoded['data'];
    if (rawData is! Map<String, dynamic>) {
      throw const BackupException('This backup has no progress data.');
    }

    final data = <String, Object>{};
    for (final key in keys) {
      final value = rawData[key];
      if (value == null) {
        continue;
      }
      if (!_isValid(key, value)) {
        throw BackupException(
          'The backup is damaged (problem in "$key"). Nothing was changed.',
        );
      }
      data[key] = value;
    }
    if (data.isEmpty) {
      throw const BackupException(
        'This backup does not contain any PokéPod progress.',
      );
    }

    final exported = decoded['exportedAt'];
    return ParsedBackup(
      data: data,
      summary: _summarise(data),
      exportedAt: exported is String ? DateTime.tryParse(exported) : null,
    );
  }

  /// Replaces the stored value of every key present in [backup]. Keys that are
  /// not in the backup are left untouched.
  static Future<void> apply(
    SharedPreferences prefs,
    ParsedBackup backup,
  ) async {
    for (final entry in backup.data.entries) {
      await prefs.setString(entry.key, jsonEncode(entry.value));
    }
  }

  static bool _isValid(String key, Object value) {
    switch (key) {
      case 'research.v1':
        return value is Map<String, dynamic> &&
            value.entries.every(
              (e) => int.tryParse(e.key) != null && e.value is int,
            );
      case 'favourites.v1':
      case 'recent.v1':
        return value is List<dynamic> && value.every((v) => v is int);
      case 'notes.v1':
        return value is Map<String, dynamic> &&
            value.entries.every(
              (e) => int.tryParse(e.key) != null && e.value is String,
            );
      case 'collections.v1':
      case 'teams.v1':
        return value is List<dynamic> &&
            value.every((v) => v is Map<String, dynamic>);
      case 'profile.v1':
      case 'mystery.v1':
        return value is Map<String, dynamic>;
    }
    return false;
  }

  static BackupSummary _summarise(Map<String, Object> data) {
    int countOf(String key) {
      final v = data[key];
      if (v is List<dynamic>) {
        return v.length;
      }
      if (v is Map<String, dynamic>) {
        return v.length;
      }
      return 0;
    }

    var challengeDays = 0;
    final mystery = data['mystery.v1'];
    if (mystery is Map<String, dynamic> &&
        mystery['history'] is Map<String, dynamic>) {
      challengeDays = (mystery['history'] as Map<String, dynamic>).length;
    }
    return BackupSummary(
      discovered: countOf('research.v1'),
      favourites: countOf('favourites.v1'),
      collections: countOf('collections.v1'),
      teams: countOf('teams.v1'),
      notes: countOf('notes.v1'),
      challengeDays: challengeDays,
      hasProfile: data.containsKey('profile.v1'),
    );
  }
}
