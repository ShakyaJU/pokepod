/// National-dex id ranges for each main-series generation (inclusive).
const List<(int, int)> kGenerationRanges = [
  (1, 151),
  (152, 251),
  (252, 386),
  (387, 493),
  (494, 649),
  (650, 721),
  (722, 809),
  (810, 905),
  (906, 1025),
];

const List<String> kRomanNumerals = [
  'I',
  'II',
  'III',
  'IV',
  'V',
  'VI',
  'VII',
  'VIII',
  'IX',
];

/// Generation number (1-9) whose range contains [id], or null if out of range.
int? generationOf(int id) {
  for (var i = 0; i < kGenerationRanges.length; i++) {
    final (lo, hi) = kGenerationRanges[i];
    if (id >= lo && id <= hi) {
      return i + 1;
    }
  }
  return null;
}

String generationLabel(int generation) =>
    'Generation ${kRomanNumerals[generation - 1]}';

int generationSize(int generation) {
  final (lo, hi) = kGenerationRanges[generation - 1];
  return hi - lo + 1;
}

bool inGeneration(int id, int generation) {
  final (lo, hi) = kGenerationRanges[generation - 1];
  return id >= lo && id <= hi;
}
