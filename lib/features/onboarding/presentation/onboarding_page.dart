import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/shared/widgets/wellness_companion.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.controller});
  final WellnessController controller;
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _step = 0;
  int _pace = 1;
  String _path = 'wellness';
  String _companion = 'plant';
  bool _lowImpact = false;
  String? _error;
  final _alias = TextEditingController();

  @override
  void dispose() {
    _alias.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(28),
            children: [
              const Text(
                'youwell.',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 24),
              LinearProgressIndicator(
                value: (_step + 1) / 3,
                color: appAccent,
                backgroundColor: appRaised,
              ),
              const SizedBox(height: 28),
              if (_step == 0) ...[
                const Text(
                  'Apa yang ingin kamu bangun?',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pilih arah awal. Bisa diubah kapan saja.',
                  style: TextStyle(color: appMuted),
                ),
                const SizedBox(height: 22),
                _Choice(
                  title: 'Better daily rhythm',
                  detail: 'Energi, gerak, fokus, dan kebiasaan kecil.',
                  value: 'wellness',
                  selected: _path,
                  onTap: (value) => setState(() => _path = value),
                ),
                _Choice(
                  title: 'Kurangi rokok / vape',
                  detail: 'Bangun jeda dan habit swap tanpa menghakimi.',
                  value: 'reduction',
                  selected: _path,
                  onTap: (value) => setState(() => _path = value),
                ),
              ] else if (_step == 1) ...[
                const Text(
                  'Atur ritmemu',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Kami mulai ringan dan menyesuaikan dari progresmu.',
                  style: TextStyle(color: appMuted),
                ),
                const SizedBox(height: 22),
                _Choice(
                  title: 'Pelan dulu',
                  detail: 'Tugas sangat ringan dan singkat.',
                  value: '1',
                  selected: '$_pace',
                  onTap: (value) => setState(() => _pace = int.parse(value)),
                ),
                _Choice(
                  title: 'Seimbang',
                  detail: 'Tantangan ringan dengan sedikit variasi.',
                  value: '2',
                  selected: '$_pace',
                  onTap: (value) => setState(() => _pace = int.parse(value)),
                ),
                _Choice(
                  title: 'Lebih aktif',
                  detail: 'Progressive challenge sesuai konsistensi.',
                  value: '3',
                  selected: '$_pace',
                  onTap: (value) => setState(() => _pace = int.parse(value)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mode low-impact'),
                  subtitle: const Text('Utamakan gerakan lembut.'),
                  value: _lowImpact,
                  onChanged: (value) => setState(() => _lowImpact = value),
                ),
              ] else ...[
                Center(
                  child: WellnessCompanion(
                    kind: _companion,
                    level: 1,
                    size: 210,
                  ),
                ),
                const Text(
                  'Pilih teman tumbuh',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _alias,
                  maxLength: 20,
                  decoration: const InputDecoration(
                    labelText: 'Alias',
                    hintText: 'misalnya: daunpagi',
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'plant', label: Text('Mori')),
                    ButtonSegment(value: 'cat', label: Text('Milo')),
                    ButtonSegment(value: 'cloud', label: Text('Awan')),
                  ],
                  selected: {_companion},
                  onSelectionChanged: (value) =>
                      setState(() => _companion = value.first),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 28),
              Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: () => setState(() => _step--),
                      child: const Text('Kembali'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () async {
                      if (_step < 2) {
                        setState(() => _step++);
                        return;
                      }
                      try {
                        await widget.controller.setup({
                          'alias': _alias.text,
                          'path': _path,
                          'pace': _pace,
                          'lowImpact': _lowImpact,
                          'companion': _companion,
                          'waterGoal': 2000,
                        });
                      } catch (_) {
                        setState(
                          () => _error =
                              'Alias harus 3–20 karakter dan diawali huruf.',
                        );
                      }
                    },
                    child: Text(_step == 2 ? 'Mulai' : 'Lanjut'),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'Data masih disimpan lokal selama fase pengembangan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: appMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.title,
    required this.detail,
    required this.value,
    required this.selected,
    required this.onTap,
  });
  final String title, detail, value, selected;
  final ValueChanged<String> onTap;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: selected == value ? const Color(0xff203a32) : appRaised,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: selected == value ? appAccent : appBorder),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(detail),
      trailing: Icon(
        selected == value ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: appAccent,
      ),
      onTap: () => onTap(value),
    ),
  );
}
