import 'dart:math';
import 'package:youwell/core/types/json_map.dart';

/// Daily mission catalog and path filtering. No UI or persistence dependencies.
class QuestGenerator {
  const QuestGenerator();
  List<JsonMap> generate(
      {required String today,
      required int difficulty,
      required bool lowImpact,
      required bool reduction}) {
    final d = difficulty;
    final gentle = lowImpact;
    final rng = Random();
    JsonMap pick(String category, List<String> titles) => {
          'id': '$today-$category',
          'category': category,
          'title': titles[rng.nextInt(titles.length)],
          'done': false,
        };
    final list = [
      pick(
        'Gerak',
        gentle
            ? [
                'Istirahat nyaman dan ubah posisi perlahan',
                'Ambil jeda layar 5 menit sambil duduk nyaman',
              ]
            : [
                'Jalan santai ${d * 5} menit',
                'Gerak ringan ${d * 3} menit sesuai kemampuan',
              ],
      ),
      pick('Nutrisi', ['Minum satu gelas air', 'Catat satu makanan hari ini']),
      pick('Mental', [
        'Check-in suasana hati hari ini',
        'Ambil jeda napas selama 1 menit',
      ]),
      if (reduction)
        pick('Habit swap', [
          'Tunda impuls 5 menit dengan timer',
          'Saat ingin merokok, coba jeda dan minum air',
        ]),
      if (d >= 2)
        pick('Sosial', [
          'Kirim dukungan di encouragement wall',
          'Sapa teman dengan satu kalimat baik',
        ]),
    ];
    return list;
  }
}
