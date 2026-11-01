/// Size of the national Pokédex this app catalogues (species 1..1025).
const int kNationalDexSize = 1025;

String titleCase(String slug) {
  return slug
      .split(RegExp(r'[-_ ]'))
      .where((p) => p.isNotEmpty)
      .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
}

String dexNumber(int id) => '#${id.toString().padLeft(4, '0')}';

/// Extracts the trailing numeric id from a PokéAPI resource URL.
int? idFromUrl(String? url) {
  if (url == null || url.isEmpty) {
    return null;
  }
  final segments = url.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) {
    return null;
  }
  return int.tryParse(segments.last);
}

const _artBase =
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon';

String artworkUrl(int id) => '$_artBase/other/official-artwork/$id.png';
String shinyArtworkUrl(int id) =>
    '$_artBase/other/official-artwork/shiny/$id.png';
String spriteUrl(int id) => '$_artBase/$id.png';

String _two(int n) => n.toString().padLeft(2, '0');

/// Calendar date in UTC as `YYYY-MM-DD`. The whole app uses UTC dates for the
/// daily challenge so every device agrees on "today".
String utcDateKey(DateTime moment) {
  final u = moment.toUtc();
  return '${u.year.toString().padLeft(4, '0')}-${_two(u.month)}-${_two(u.day)}';
}

/// Calendar date in the device's local time zone as `YYYY-MM-DD`. The daily
/// challenge and specimen change at local midnight.
String localDateKey(DateTime moment) {
  final l = moment.toLocal();
  return '${l.year.toString().padLeft(4, '0')}-${_two(l.month)}-${_two(l.day)}';
}

DateTime? parseDateKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) {
    return null;
  }
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) {
    return null;
  }
  return DateTime.utc(y, m, d);
}
