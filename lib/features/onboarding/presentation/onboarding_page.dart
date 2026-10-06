import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/theme/appearance_scope.dart';
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
  String? _ageGroup;
  bool _guardianConsent = false;
  bool _reductionConsent = false;
  String? _error;

  static const _lastStep = 3;
  bool get _underTwentyOne => _ageGroup == 'under18' || _ageGroup == '18-20';

  /// Blocks "Lanjut" until the current step has what the rules require.
  String? _stepError() => switch (_step) {
    0 when _ageGroup == null => 'Pilih rentang usiamu dulu.',
    0 when _ageGroup == 'under18' && !_guardianConsent =>
      'Di bawah 18 tahun perlu izin orang tua/wali.',
    1 when _path == 'reduction' && !_reductionConsent =>
      'Centang persetujuan untuk memakai jalur ini.',
    _ => null,
  };
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
              const Row(
                children: [
                  Text(
                    'youwell',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  Spacer(),
                  ThemeModeButton(),
                ],
              ),
              const SizedBox(height: 24),
              LinearProgressIndicator(
                value: (_step + 1) / (_lastStep + 1),
                color: context.colors.accent,
                backgroundColor: context.colors.raised,
              ),
              const SizedBox(height: 28),
              if (_step == 0) ...[
                const Text(
                  'Berapa usiamu?',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'Dipakai untuk menyesuaikan isi. Yang disimpan hanya rentang usia.',
                  style: TextStyle(color: context.colors.muted),
                ),
                const SizedBox(height: 22),
                for (final (value, title) in const [
                  ('under18', 'Di bawah 18 tahun'),
                  ('18-20', '18–20 tahun'),
                  ('21plus', '21 tahun ke atas'),
                ])
                  _Choice(
                    title: title,
                    detail: '',
                    value: value,
                    selected: _ageGroup ?? '',
                    onTap: (value) => setState(() {
                      _ageGroup = value;
                      _error = null;
                    }),
                  ),
                if (_ageGroup == 'under18')
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _guardianConsent,
                    onChanged: (value) =>
                        setState(() => _guardianConsent = value == true),
                    title: const Text(
                      'Orang tua/wali sudah mengizinkan aku memakai YouWell.',
                    ),
                  ),
              ] else if (_step == 1) ...[
                const Text(
                  'Apa yang ingin kamu bangun?',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pilih arah awal. Bisa diubah kapan saja.',
                  style: TextStyle(color: context.colors.muted),
                ),
                const SizedBox(height: 22),
                _Choice(
                  title: 'Better Daily Rhythm',
                  detail: 'Energi, gerak, tidur, hidrasi, dan kebiasaan kecil.',
                  value: 'wellness',
                  selected: _path,
                  onTap: (value) => setState(() => _path = value),
                ),
                _Choice(
                  title: _underTwentyOne
                      ? 'Berhenti rokok / vape'
                      : 'Kurangi rokok / vape',
                  detail: _underTwentyOne
                      ? 'Dukungan untuk berhenti lewat Delay Craving dan Habit Swap, tanpa menghakimi.'
                      : 'Bangun jeda lewat Delay Craving dan Habit Swap, tanpa menghakimi.',
                  value: 'reduction',
                  selected: _path,
                  onTap: (value) => setState(() => _path = value),
                ),
                if (_path == 'reduction')
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _reductionConsent,
                    onChanged: (value) =>
                        setState(() => _reductionConsent = value == true),
                    title: const Text(
                      'Aku setuju catatan Delay Craving & Habit Swap disimpan '
                      'untuk fitur ini.',
                    ),
                    subtitle: const Text(
                      'Ini data pribadi yang sensitif. Bisa dihapus kapan saja '
                      'dari Profil.',
                    ),
                  ),
              ] else if (_step == 2) ...[
                const Text(
                  'Atur ritmemu',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'Kami mulai ringan dan menyesuaikan dari progresmu.',
                  style: TextStyle(color: context.colors.muted),
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
                  detail: 'Tantangan naik bertahap sesuai konsistensimu.',
                  value: '3',
                  selected: '$_pace',
                  onTap: (value) => setState(() => _pace = int.parse(value)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mode aktivitas ringan (low-impact)'),
                  subtitle: const Text(
                    'Utamakan gerakan lembut. Quest lari tidak akan muncul.',
                  ),
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
                      onPressed: () => setState(() {
                        _step--;
                        _error = null;
                      }),
                      child: const Text('Kembali'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () async {
                      final blocked = _stepError();
                      if (blocked != null) {
                        setState(() => _error = blocked);
                        return;
                      }
                      if (_step < _lastStep) {
                        setState(() {
                          _step++;
                          _error = null;
                        });
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
                          'ageGroup': _ageGroup,
                          if (_ageGroup == 'under18') 'guardianConsent': true,
                          if (_path == 'reduction') 'reductionConsent': true,
                        });
                      } catch (_) {
                        setState(
                          () => _error =
                              'Alias harus 3–20 karakter dan diawali huruf.',
                        );
                      }
                    },
                    child: Text(_step == _lastStep ? 'Mulai' : 'Lanjut'),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Data masih disimpan lokal selama fase pengembangan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.muted, fontSize: 12),
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: selected == value
          ? context.colors.selected
          : context.colors.raised,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected == value
              ? context.colors.accent
              : context.colors.border,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: detail.isEmpty ? null : Text(detail),
        trailing: Icon(
          selected == value
              ? Icons.check_circle_rounded
              : Icons.circle_outlined,
          color: context.colors.accent,
        ),
        onTap: () => onTap(value),
      ),
    ),
  );
}
