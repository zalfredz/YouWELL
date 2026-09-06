import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:youwell/core/config/app_environment.dart';
import 'package:youwell/core/platform/platform.dart' as platform;
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';

/// Public product page. It intentionally works on phones, tablets and desktop.
class WebLandingPage extends StatefulWidget {
  const WebLandingPage({super.key});

  @override
  State<WebLandingPage> createState() => _WebLandingPageState();
}

class _WebLandingPageState extends State<WebLandingPage> {
  final productKey = GlobalKey();
  final wellbeingKey = GlobalKey();

  void _scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 500),
      );
    }
  }

  void _download() {
    final isApple = defaultTargetPlatform == TargetPlatform.iOS;
    final store =
        isApple ? AppEnvironment.appStoreUrl : AppEnvironment.playStoreUrl;
    if (store.isNotEmpty) {
      platform.openLink(store);
      return;
    }
    toast(context, 'Link aplikasi akan tersedia saat YouWell diterbitkan.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Hero(
                onProduct: () => _scrollTo(productKey),
                onWellbeing: () => _scrollTo(wellbeingKey),
                onDashboard: () => Navigator.pushNamed(context, '/app'),
                onDownload: _download,
              ),
            ),
            SliverToBoxAdapter(
              key: productKey,
              child: _ProductSection(
                onRecap: () => Navigator.pushNamed(context, '/recap'),
              ),
            ),
            SliverToBoxAdapter(
                key: wellbeingKey, child: const _WellbeingSection()),
            SliverToBoxAdapter(child: _ClosingSection(onDownload: _download)),
          ],
        ),
      );
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.onProduct,
    required this.onWellbeing,
    required this.onDashboard,
    required this.onDownload,
  });

  final VoidCallback onProduct;
  final VoidCallback onWellbeing;
  final VoidCallback onDashboard;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 720),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff17392f), Color(0xff285e48), Color(0xff7aa26c)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 62),
                child: Column(
                  children: [
                    _LandingNavigation(
                      onProduct: onProduct,
                      onWellbeing: onWellbeing,
                      onDashboard: onDashboard,
                    ),
                    const SizedBox(height: 66),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 780;
                        final copy = _HeroCopy(
                          onDownload: onDownload,
                          onDashboard: onDashboard,
                        );
                        final preview = const _PhonePreview();
                        return compact
                            ? Column(
                                children: [
                                  copy,
                                  const SizedBox(height: 46),
                                  preview,
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(flex: 11, child: copy),
                                  const SizedBox(width: 46),
                                  const Expanded(
                                      flex: 9, child: _PhonePreview()),
                                ],
                              );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _LandingNavigation extends StatelessWidget {
  const _LandingNavigation({
    required this.onProduct,
    required this.onWellbeing,
    required this.onDashboard,
  });

  final VoidCallback onProduct;
  final VoidCallback onWellbeing;
  final VoidCallback onDashboard;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;
          return Row(
            children: [
              const Icon(Icons.spa_rounded, color: Color(0xffdcebcf)),
              const SizedBox(width: 8),
              const Text(
                'youwell.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const Spacer(),
              if (!compact) ...[
                _NavButton(label: 'Produk', onTap: onProduct),
                _NavButton(label: 'Prinsip kami', onTap: onWellbeing),
                const SizedBox(width: 14),
              ],
              OutlinedButton(
                onPressed: onDashboard,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0x99ffffff)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                ),
                child: Text(compact ? 'Masuk' : 'Masuk / preview'),
              ),
            ],
          );
        },
      );
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: const Color(0xffe8f2e1)),
        child: Text(label),
      );
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.onDownload, required this.onDashboard});
  final VoidCallback onDownload;
  final VoidCallback onDashboard;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUWELL • RUANG TUMBUH HARIAN',
            style: TextStyle(
              color: Color(0xffc5e0ba),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Sedikit lebih baik,\nsetiap hari.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 66,
              height: .98,
              letterSpacing: -3,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 530),
            child: Text(
              'Bukan tentang menjadi sempurna. YouWell membantu kamu menemukan ritme kecil untuk bernapas, bergerak, dan bertumbuh bersama.',
              style: TextStyle(
                color: Color(0xffe0ebe0),
                fontSize: 18,
                height: 1.55,
              ),
            ),
          ),
          const SizedBox(height: 34),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: onDownload,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: ink,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                ),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download aplikasi'),
              ),
              TextButton(
                onPressed: onDashboard,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                ),
                child: const Text('Lihat web dashboard →'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Ruang kecil untuk merawat diri. Bukan layanan medis.',
            style: TextStyle(color: Color(0xffb8cdbb), fontSize: 12),
          ),
        ],
      );
}

class _PhonePreview extends StatelessWidget {
  const _PhonePreview();

  @override
  Widget build(BuildContext context) => Center(
        child: Transform.rotate(
          angle: .045,
          child: Container(
            width: 300,
            height: 560,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xff0e211b),
              borderRadius: BorderRadius.circular(42),
              border: Border.all(color: const Color(0x55ffffff)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 48,
                  offset: Offset(0, 28),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(33),
              child: ColoredBox(
                color: cream,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Selamat sore,',
                            style: TextStyle(color: muted),
                          ),
                          const Spacer(),
                          Container(
                            width: 22,
                            height: 7,
                            decoration: BoxDecoration(
                              color: ink,
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'pelan-pelan.',
                        style: TextStyle(
                          color: ink,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xffe2edda),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.spa_rounded, color: green, size: 48),
                            SizedBox(height: 8),
                            Text(
                              '1 langkah kecil\nhari ini',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: ink,
                                fontWeight: FontWeight.w800,
                                fontSize: 19,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Misi hari ini',
                        style:
                            TextStyle(color: ink, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      ...[
                        'Check-in perasaan',
                        'Minum air',
                        'Ambil jeda napas',
                      ].asMap().entries.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    entry.key == 0
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    color: entry.key == 0 ? green : muted,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 9),
                                  Text(
                                    entry.value,
                                    style: const TextStyle(
                                        color: ink, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      const Spacer(),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: ink,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.air_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Ambil jeda',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _ProductSection extends StatelessWidget {
  const _ProductSection({required this.onRecap});
  final VoidCallback onRecap;

  @override
  Widget build(BuildContext context) => Container(
        color: cream,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 110),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SEBUAH RITME, BUKAN TARGET SEMPURNA',
                  style: TextStyle(
                    color: green,
                    fontSize: 12,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Temukan hal kecil yang\nbisa kamu lakukan hari ini.',
                  style: TextStyle(
                    color: ink,
                    fontSize: 48,
                    height: 1.03,
                    letterSpacing: -2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 48),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 840;
                    final cards = const [
                      _FeatureCard(
                        icon: Icons.auto_awesome_rounded,
                        title: 'Misi yang terasa mungkin',
                        body:
                            'Gacha Task membagi tujuan besar menjadi langkah kecil yang dapat kamu pilih sesuai kondisi hari ini.',
                      ),
                      _FeatureCard(
                        icon: Icons.air_rounded,
                        title: 'Jeda saat butuh ruang',
                        body:
                            'Delay timer, breathing circle, dan suara tenang membantu kamu melewati satu gelombang tanpa menghakimi diri.',
                      ),
                      _FeatureCard(
                        icon: Icons.bar_chart_rounded,
                        title: 'Lihat pola, rayakan progres',
                        body:
                            'Wrapped mingguan mengubah catatan kecil menjadi gambaran perjalanan yang bisa kamu pahami.',
                      ),
                    ];
                    return wide
                        ? Row(
                            children: cards
                                .map(
                                  (card) => Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 14),
                                      child: card,
                                    ),
                                  ),
                                )
                                .toList(),
                          )
                        : Column(
                            children: cards
                                .map(
                                  (card) => Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: card,
                                  ),
                                )
                                .toList(),
                          );
                  },
                ),
                const SizedBox(height: 26),
                TextButton.icon(
                  onPressed: onRecap,
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Lihat contoh Weekly Wrapped'),
                ),
              ],
            ),
          ),
        ),
      );
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 240),
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: const BoxDecoration(
                color: Color(0xffe2edda),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: green),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                color: ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(body, style: const TextStyle(color: muted, height: 1.55)),
          ],
        ),
      );
}

class _WellbeingSection extends StatelessWidget {
  const _WellbeingSection();

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xffe0eadb),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 100),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                final copy = const _WellbeingCopy();
                final principles = const _PrinciplePanel();
                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: copy),
                          const SizedBox(width: 76),
                          Expanded(child: principles),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          copy,
                          const SizedBox(height: 34),
                          principles
                        ],
                      );
              },
            ),
          ),
        ),
      );
}

class _WellbeingCopy extends StatelessWidget {
  const _WellbeingCopy();

  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BERTUMBUH TANPA DIHAKIMI',
            style: TextStyle(
              color: green,
              fontSize: 12,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Kamu tidak perlu\nmelakukannya sendiri.',
            style: TextStyle(
              color: ink,
              fontSize: 44,
              height: 1.04,
              letterSpacing: -2,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 18),
          Text(
            'YouWell dibuat untuk menemani, bukan mendorong dengan angka. Kami menyimpan ruang untuk langkah yang kecil, hari yang rumit, dan progres yang tidak selalu lurus.',
            style: TextStyle(color: muted, fontSize: 16, height: 1.65),
          ),
          SizedBox(height: 18),
          Text(
            'Cerita pengguna pertama akan hadir bersama program beta—dengan izin mereka.',
            style: TextStyle(
              color: green,
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}

class _PrinciplePanel extends StatelessWidget {
  const _PrinciplePanel();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.favorite_outline_rounded,
              color: Color(0xffb9d7a8),
              size: 31,
            ),
            SizedBox(height: 20),
            Text(
              'Yang kami jaga',
              style: TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 20),
            _Principle(
              number: '01',
              text: 'Tidak ada streak yang mengukur harga dirimu.',
            ),
            _Principle(
              number: '02',
              text: 'Kontrol data dan berbagi ada di tanganmu.',
            ),
            _Principle(
              number: '03',
              text: 'Komunitas yang aman lebih penting dari engagement.',
            ),
          ],
        ),
      );
}

class _Principle extends StatelessWidget {
  const _Principle({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              number,
              style: const TextStyle(
                color: Color(0xffa8c798),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Color(0xffe8f0e4), height: 1.45),
              ),
            ),
          ],
        ),
      );
}

class _ClosingSection extends StatelessWidget {
  const _ClosingSection({required this.onDownload});
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xfff4b990),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 88),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              children: [
                const Icon(Icons.spa_rounded, color: ink, size: 42),
                const SizedBox(height: 18),
                const Text(
                  'Satu langkah kecil\nboleh dimulai sekarang.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ink,
                    fontSize: 48,
                    height: 1.04,
                    letterSpacing: -2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Aplikasi mobile dibuat untuk menemani harimu. Web hadir untuk melihat progres, mengambil jeda, dan berbagi Wrapped.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ink, fontSize: 16, height: 1.55),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: onDownload,
                  style: FilledButton.styleFrom(
                    backgroundColor: ink,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Dapatkan YouWell'),
                ),
                const SizedBox(height: 54),
                const Text(
                  'youwell.  •  ruang kecil untuk merawat diri',
                  style: TextStyle(color: Color(0xaa203d34), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
}
