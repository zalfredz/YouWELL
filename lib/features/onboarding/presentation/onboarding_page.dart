import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';
import 'package:youwell/shared/widgets/wellness_companion.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.controller});
  final WellnessController controller;
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int slide = 0, step = -1, fitness = 1;
  String path = 'wellness', companion = 'plant';
  bool low = false;
  final alias = TextEditingController(),
      cost = TextEditingController(text: '2500');
  String? error;
  @override
  void dispose() {
    alias.dispose();
    cost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.spa_rounded, color: green),
                        const SizedBox(width: 8),
                        title('youwell.', size: 26),
                        const Spacer(),
                        tag('YOUWELL ACCOUNT'),
                      ],
                    ),
                    gap(34),
                    if (step == -1) ...[
                      Center(child: WellnessCompanion(kind: 'plant', level: 1)),
                      gap(24),
                      title(
                        [
                          'Little steps.\nBetter days.',
                          'Perasaanmu punya\ntempat di sini.',
                          'Tumbuh bareng,\ntanpa menghakimi.',
                        ][slide],
                        size: 42,
                      ),
                      gap(),
                      Text(
                        [
                          'Mulai dari hal kecil yang bikin hari terasa lebih baik. Satu misi, satu napas, satu langkah.',
                          'Check-in singkat, jeda yang tenang, dan teman tumbuh untuk perjalananmu.',
                          'Rayakan progres dengan dukungan teman. Kamu boleh berjalan dengan ritmemu sendiri.',
                        ][slide],
                      ),
                      gap(24),
                      Row(
                        children: List.generate(
                          3,
                          (i) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () => setState(() => slide = i),
                              child: Container(
                                width: slide == i ? 32 : 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: slide == i
                                      ? green
                                      : green.withValues(alpha: .15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      gap(30),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => setState(() => step = 0),
                          child: const Text('Mulai perjalanan'),
                        ),
                      ),
                      gap(8),
                    ] else ...[
                      LinearProgressIndicator(
                        value: (step + 1) / 3,
                        color: green,
                        backgroundColor: cream,
                      ),
                      gap(24),
                      title(
                        [
                          'Gaya hidupmu sekarang?',
                          'Cari ritme yang nyaman.',
                          'Kenalan dengan teman tumbuh.',
                        ][step],
                        size: 30,
                      ),
                      gap(),
                      if (step == 0) ...[
                        caption(
                          'Pilih jalur awal. Kamu bisa menggantinya kapan saja.',
                        ),
                        gap(),
                        choice(
                          'wellness',
                          'Bangun kebiasaan baik',
                          'Gerak, makan, dan pikiran yang lebih seimbang.',
                          path,
                          (v) => setState(() => path = v),
                        ),
                        choice(
                          'reduction',
                          'Kurangi rokok / vape',
                          'Jeda kecil dan habit swap tanpa penghakiman.',
                          path,
                          (v) => setState(() => path = v),
                        ),
                        if (path == 'reduction')
                          TextField(
                            controller: cost,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Estimasi biaya per pemakaian (Rp)',
                            ),
                          ),
                      ],
                      if (step == 1) ...[
                        ...[1, 2, 3].map(
                          (n) => choice(
                            '$n',
                            [
                              'Baru mulai',
                              'Kadang bergerak',
                              'Sudah cukup aktif',
                            ][n - 1],
                            [
                              'Mulai dari misi paling ringan.',
                              'Sedikit tantangan, tetap santai.',
                              'Progresif sesuai kemampuanmu.',
                            ][n - 1],
                            '$fitness',
                            (v) => setState(() => fitness = int.parse(v)),
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: low,
                          onChanged: (v) => setState(() => low = v),
                          title: const Text('Sedang sakit / cedera'),
                          subtitle: const Text(
                            'Prioritaskan istirahat dan misi low-impact.',
                          ),
                        ),
                      ],
                      if (step == 2) ...[
                        TextField(
                          controller: alias,
                          maxLength: 20,
                          decoration: const InputDecoration(
                            labelText: 'Alias pilihanmu',
                            hintText: 'misalnya: daunpagi',
                            helperText:
                                '3–20 huruf/angka/underscore. Hindari nama asli.',
                          ),
                        ),
                        gap(),
                        Wrap(
                          spacing: 12,
                          children: ['plant', 'cat', 'cloud']
                              .map(
                                (c) => ChoiceChip(
                                  label: Text(
                                    '${{
                                      'plant': '🌱',
                                      'cat': '🐱',
                                      'cloud': '☁️'
                                    }[c]}  ${{
                                      'plant': 'Mori',
                                      'cat': 'Milo',
                                      'cloud': 'Awan'
                                    }[c]}',
                                  ),
                                  selected: companion == c,
                                  onSelected: (_) =>
                                      setState(() => companion = c),
                                ),
                              )
                              .toList(),
                        ),
                        gap(),
                        caption(
                          'Profil dan progres disimpan pada browser ini selama fase preview web.',
                        ),
                      ],
                      if (error != null)
                        Text(error!, style: const TextStyle(color: Colors.red)),
                      gap(24),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => setState(() => step--),
                            child: const Text('Kembali'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () async {
                              if (step == 0 &&
                                  path == 'reduction' &&
                                  (double.tryParse(cost.text) == null ||
                                      !double.parse(cost.text).isFinite ||
                                      double.parse(cost.text) < 0 ||
                                      double.parse(cost.text) > 1000000)) {
                                setState(
                                    () => error = 'Isi biaya 0–1.000.000.');
                                return;
                              }
                              if (step < 2) {
                                setState(() {
                                  step++;
                                  error = null;
                                });
                                return;
                              }
                              try {
                                await widget.controller.setup({
                                  'alias': alias.text,
                                  'path': path,
                                  'fitness': fitness,
                                  'lowImpact': low,
                                  'companion': companion,
                                  'cost': double.tryParse(cost.text) ?? 0,
                                  'waterGoal': 2000,
                                  'kcalGoal': 2000,
                                  'proteinGoal': 60,
                                });
                              } catch (_) {
                                setState(
                                  () => error =
                                      'Alias harus 3–20 karakter, diawali huruf.',
                                );
                              }
                            },
                            child:
                                Text(step == 2 ? 'Masuk ke YouWell' : 'Lanjut'),
                          ),
                        ],
                      ),
                    ],
                    gap(28),
                    caption(
                        'Ruang kecil untuk merawat diri. Bukan layanan medis.'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  Widget choice(
    String value,
    String name,
    String sub,
    String selected,
    ValueChanged<String> onTap,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: selected == value ? const Color(0xffe5eddf) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: ListTile(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title:
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(sub),
            trailing: Icon(
              selected == value ? Icons.check_circle : Icons.circle_outlined,
              color: green,
            ),
            onTap: () => onTap(value),
          ),
        ),
      );
}
