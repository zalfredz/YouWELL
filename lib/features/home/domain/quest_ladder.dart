import 'package:youwell/core/types/json_map.dart';

/// Graded, rule-based quest ladders (no ML). Each category keeps its own step;
/// the step decides which ladder quest appears on every daily card.
class LadderRung {
  const LadderRung({
    required this.title,
    required this.description,
    required this.durationMinutes,
    this.activityKind,
    this.targetMeters,
    this.delayMinutes,
    this.waterMl,
    this.strenuous = false,
  });
  final String title, description;
  final int durationMinutes;
  final String? activityKind;
  final int? targetMeters, delayMinutes, waterMl;

  /// Shows "berhenti jika pusing atau nyeri" on the quest.
  final bool strenuous;
}

const ladderLabels = {
  'Body': 'Gerak',
  'Energy': 'Istirahat',
  'Reduction': 'Jeda rokok/vape',
  'Lifestyle': 'Hidrasi',
};

/// Low-impact users never enter the running part of the Body ladder.
const lowImpactBodyMax = 4;

const ladders = <String, List<LadderRung>>{
  'Body': [
    LadderRung(
      title: 'Jalan santai 5 menit',
      description: 'Berjalan dengan ritmemu sendiri.',
      durationMinutes: 5,
      activityKind: 'walk',
    ),
    LadderRung(
      title: 'Jalan 10 menit',
      description: 'Pilih rute yang aman dan nyaman.',
      durationMinutes: 10,
      activityKind: 'walk',
    ),
    LadderRung(
      title: 'Jalan cepat 15 menit',
      description: 'Sedikit lebih cepat, masih bisa bicara.',
      durationMinutes: 15,
      activityKind: 'walk',
      strenuous: true,
    ),
    LadderRung(
      title: 'Jalan 1,5 km',
      description: 'Sekitar 20 menit. Tanpa GPS, dihitung dari waktu.',
      durationMinutes: 20,
      activityKind: 'walk',
      targetMeters: 1500,
      strenuous: true,
    ),
    LadderRung(
      title: 'Interval jalan-lari × 5',
      description: '1 menit lari pelan, 2 menit jalan. Ulangi 5 kali.',
      durationMinutes: 15,
      activityKind: 'run',
      strenuous: true,
    ),
    LadderRung(
      title: 'Interval jalan-lari × 8',
      description: '1 menit lari pelan, 2 menit jalan. Ulangi 8 kali.',
      durationMinutes: 24,
      activityKind: 'run',
      strenuous: true,
    ),
    LadderRung(
      title: 'Lari santai 2 km',
      description: 'Pelan saja, boleh selingi jalan.',
      durationMinutes: 16,
      activityKind: 'run',
      targetMeters: 2000,
      strenuous: true,
    ),
    LadderRung(
      title: 'Lari 3 km',
      description: 'Jaga napas tetap nyaman.',
      durationMinutes: 24,
      activityKind: 'run',
      targetMeters: 3000,
      strenuous: true,
    ),
    LadderRung(
      title: 'Lari 4 km',
      description: 'Jaga napas tetap nyaman.',
      durationMinutes: 30,
      activityKind: 'run',
      targetMeters: 4000,
      strenuous: true,
    ),
    LadderRung(
      title: 'Lari 5 km',
      description: 'Ritme stabil, tidak perlu cepat.',
      durationMinutes: 38,
      activityKind: 'run',
      targetMeters: 5000,
      strenuous: true,
    ),
  ],
  'Energy': [
    LadderRung(
      title: 'Layar off 10 menit sebelum tidur',
      description: 'Taruh HP sebentar sebelum memejamkan mata.',
      durationMinutes: 10,
    ),
    LadderRung(
      title: 'Layar off 15 menit sebelum tidur',
      description: 'Ganti scroll dengan hal yang menenangkan.',
      durationMinutes: 15,
    ),
    LadderRung(
      title: 'Layar off 20 menit sebelum tidur',
      description: 'Redupkan lampu dan beri tubuh tanda istirahat.',
      durationMinutes: 20,
    ),
    LadderRung(
      title: 'Layar off 30 menit sebelum tidur',
      description: 'Isi dengan stretching, baca, atau musik pelan.',
      durationMinutes: 30,
    ),
    LadderRung(
      title: 'Layar off 45 menit sebelum tidur',
      description: 'Taruh HP di luar jangkauan tempat tidur.',
      durationMinutes: 45,
    ),
    LadderRung(
      title: 'Layar off 60 menit & jam tidur tetap',
      description: 'Tidur di jam yang kurang lebih sama seperti kemarin.',
      durationMinutes: 60,
    ),
  ],
  'Reduction': [
    LadderRung(
      title: 'Delay Craving 2 menit',
      description: 'Saat ingin merokok atau vape, mulai timer dulu.',
      durationMinutes: 2,
      activityKind: 'delay',
      delayMinutes: 2,
    ),
    LadderRung(
      title: 'Delay Craving 5 menit',
      description: 'Saat ingin merokok atau vape, mulai timer dulu.',
      durationMinutes: 5,
      activityKind: 'delay',
      delayMinutes: 5,
    ),
    LadderRung(
      title: 'Delay Craving 10 menit',
      description: 'Tunda dan isi dengan Habit Swap.',
      durationMinutes: 10,
      activityKind: 'delay',
      delayMinutes: 10,
    ),
    LadderRung(
      title: 'Delay Craving 15 menit',
      description: 'Tunda dan isi dengan Habit Swap.',
      durationMinutes: 15,
      activityKind: 'delay',
      delayMinutes: 15,
    ),
    LadderRung(
      title: 'Tunda yang pertama hari ini 30 menit',
      description: 'Mundurkan rokok/vape pertama 30 menit dari biasanya.',
      durationMinutes: 30,
    ),
    LadderRung(
      title: 'Tunda yang pertama hari ini 1 jam',
      description: 'Mundurkan rokok/vape pertama 1 jam dari biasanya.',
      durationMinutes: 60,
    ),
  ],
  'Lifestyle': [
    LadderRung(
      title: 'Minum 1.000 ml hari ini',
      description: 'Catat setiap gelas di Aktivitas.',
      durationMinutes: 1,
      activityKind: 'water',
      waterMl: 1000,
    ),
    LadderRung(
      title: 'Minum 1.250 ml hari ini',
      description: 'Catat setiap gelas di Aktivitas.',
      durationMinutes: 1,
      activityKind: 'water',
      waterMl: 1250,
    ),
    LadderRung(
      title: 'Minum 1.500 ml hari ini',
      description: 'Catat setiap gelas di Aktivitas.',
      durationMinutes: 1,
      activityKind: 'water',
      waterMl: 1500,
    ),
    LadderRung(
      title: 'Minum 1.750 ml hari ini',
      description: 'Catat setiap gelas di Aktivitas.',
      durationMinutes: 1,
      activityKind: 'water',
      waterMl: 1750,
    ),
    LadderRung(
      title: 'Minum 2.000 ml hari ini',
      description: 'Catat setiap gelas di Aktivitas.',
      durationMinutes: 1,
      activityKind: 'water',
      waterMl: 2000,
    ),
  ],
};

List<String> ladderCategories({required bool reduction}) => reduction
    ? const ['Body', 'Energy', 'Reduction']
    : const ['Body', 'Energy', 'Lifestyle'];

int ladderMax(String category, {required bool lowImpact}) {
  final length = ladders[category]!.length;
  return category == 'Body' && lowImpact ? lowImpactBodyMax : length;
}

/// The rule from the proposal (§4), evaluated per category every 7 days.
int nextStep(
  int current,
  int maxStep, {
  required double completion,
  required int heavyCount,
  required int inactiveDays,
}) {
  if (inactiveDays >= 5) return (current - 1).clamp(1, maxStep);
  if (completion >= .8 && heavyCount == 0) {
    return (current + 1).clamp(1, maxStep);
  }
  if (completion < .5 || heavyCount >= 2) {
    return (current - 1).clamp(1, maxStep);
  }
  return current;
}

class LadderReview {
  const LadderReview({
    required this.step,
    required this.change,
    required this.reason,
  });
  final int step;

  /// up (offered, not yet applied), down, hold, or rest (after inactivity).
  final String change;
  final String reason;
}

/// Turns one category's last 7 days of ladder quests into an explained step.
LadderReview reviewLadder({
  required String category,
  required int current,
  required int maxStep,
  required List<JsonMap> weekQuests,
  required int inactiveDays,
}) {
  final label = ladderLabels[category] ?? category;
  if (inactiveDays >= 5) {
    final step = nextStep(
      current,
      maxStep,
      completion: 0,
      heavyCount: 0,
      inactiveDays: inactiveDays,
    );
    return LadderReview(
      step: step,
      change: 'rest',
      reason: step < current
          ? 'Selamat datang lagi. $label turun satu anak tangga supaya mulai '
                'lagi terasa ringan.'
          : 'Selamat datang lagi. Mulai lagi dari langkah yang ringan.',
    );
  }
  if (weekQuests.isEmpty) {
    return LadderReview(
      step: current,
      change: 'hold',
      reason: 'Belum ada quest $label minggu ini, jadi anak tangga tetap.',
    );
  }
  final total = weekQuests.length;
  final done = weekQuests.where((task) => task['status'] == 'completed').length;
  final score = weekQuests.fold<double>(
    0,
    (sum, task) => task['status'] == 'completed'
        ? sum + 1
        : sum + ((task['partial'] as num?)?.toDouble() ?? 0),
  );
  final completion = score / total;
  final heavy = weekQuests.where((task) => task['effort'] == 'berat').length;
  final step = nextStep(
    current,
    maxStep,
    completion: completion,
    heavyCount: heavy,
    inactiveDays: inactiveDays,
  );
  final summary = '$done dari $total quest $label selesai';
  if (step > current) {
    return LadderReview(
      step: step,
      change: 'up',
      reason: 'Naik karena $summary dan tidak ada yang terasa berat.',
    );
  }
  if (step < current) {
    return LadderReview(
      step: step,
      change: 'down',
      reason: heavy >= 2
          ? 'Turun satu anak tangga karena $heavy quest terasa berat. '
                'Biar lebih pas dulu.'
          : 'Turun satu anak tangga karena $summary. Biar lebih pas dulu.',
    );
  }
  return LadderReview(
    step: current,
    change: 'hold',
    reason: current == maxStep && completion >= .8 && heavy == 0
        ? 'Kamu sudah di anak tangga teratas. $summary.'
        : 'Tetap di anak tangga ini: $summary.',
  );
}
