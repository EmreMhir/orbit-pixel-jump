import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/app_config.dart';
import '../../screens/gdpr_screen.dart';
import '../orbit_game.dart';
import 'theme.dart';

class MainMenuOverlay extends StatelessWidget {
  const MainMenuOverlay({super.key, required this.game});
  final OrbitGame game;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          const Eyebrow('ONE-TAP ARCADE'),
                          const SizedBox(height: 20),
                          Text('ORBIT', style: OrbitTheme.pixel(38)),
                          Text(
                            'PIXEL JUMP',
                            style: OrbitTheme.pixel(17, color: OrbitTheme.mint),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Bir dokunuş. Bir yörünge daha.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      SizedBox(
                        height: (constraints.maxHeight * 0.24).clamp(
                          80.0,
                          210.0,
                        ),
                      ),
                      OrbitPanel(
                        child: Column(
                          children: [
                            const Eyebrow(
                              'EN YÜKSEK SKOR',
                              color: OrbitTheme.muted,
                            ),
                            const SizedBox(height: 8),
                            ValueListenableBuilder(
                              valueListenable: game.ui,
                              builder: (_, value, child) => Text(
                                '${game.best}'.padLeft(3, '0'),
                                style: OrbitTheme.pixel(24),
                              ),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: game.startRun,
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('OYNA'),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Dış yörüngeye atla. Asteroitleri aş.\nBeşinci yörüngede yeni sektöre geç.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: [
                          ListenableBuilder(
                            listenable: game.audio,
                            builder: (context, child) => TextButton.icon(
                              onPressed: () => game.audio.toggleMute(),
                              icon: Icon(
                                game.audio.muted
                                    ? Icons.volume_off_outlined
                                    : Icons.volume_up_outlined,
                                size: 20,
                              ),
                              label: Text(
                                game.audio.muted ? 'Ses kapalı' : 'Ses açık',
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _showSettings(context, game),
                            icon: const Icon(Icons.tune_rounded, size: 20),
                            label: const Text('Tercihler'),
                          ),
                        ],
                      ),
                      BannerSlot(game: game),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class BannerSlot extends StatelessWidget {
  const BannerSlot({super.key, required this.game});
  final OrbitGame game;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: game.ads,
    builder: (context, child) {
      if (!game.ads.allowed) return const SizedBox(height: 12);
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          children: [
            Text(
              AppConfig.testAds ? 'TEST REKLAMI' : 'REKLAM',
              style: const TextStyle(
                fontSize: 9,
                letterSpacing: 2,
                color: OrbitTheme.muted,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 50,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final safeWidth =
                      MediaQuery.sizeOf(context).width -
                      MediaQuery.paddingOf(context).horizontal;
                  if (safeWidth < 320) {
                    return const SizedBox.shrink();
                  }
                  // The menu has 24dp side padding: a 360dp phone leaves only
                  // 312dp here. Let the 320dp banner use 4dp of each gutter.
                  return OverflowBox(
                    minWidth: 320,
                    maxWidth: 320,
                    minHeight: 50,
                    maxHeight: 50,
                    child: game.ads.bannerReady && game.ads.banner != null
                        ? SizedBox(
                            width: 320,
                            height: 50,
                            child: AdWidget(ad: game.ads.banner!),
                          )
                        : const SizedBox(width: 320, height: 50),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class HudOverlay extends StatelessWidget {
  const HudOverlay({super.key, required this.game});
  final OrbitGame game;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Stack(
      children: [
        Positioned(
          top: 20,
          left: 24,
          right: 24,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: IgnorePointer(
                  child: ValueListenableBuilder(
                    valueListenable: game.ui,
                    builder: (context, value, child) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SKOR',
                          style: TextStyle(
                            color: OrbitTheme.muted,
                            fontSize: 11,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${game.run.score}'.padLeft(3, '0'),
                          style: OrbitTheme.pixel(28),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'SEKTÖR ${game.run.level.toString().padLeft(2, '0')}  /  YÖRÜNGE ${game.run.ring + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: OrbitTheme.mint,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Material(
                color: OrbitTheme.panel,
                borderRadius: BorderRadius.circular(12),
                child: IconButton(
                  onPressed: game.pauseRun,
                  tooltip: 'Oyunu duraklat',
                  icon: const Icon(Icons.pause_rounded),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 30,
          left: 24,
          right: 24,
          child: IgnorePointer(
            child: ValueListenableBuilder(
              valueListenable: game.ui,
              builder: (context, value, child) => Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 22,
                        height: 4,
                        color: index <= game.run.ring
                            ? OrbitTheme.mint
                            : OrbitTheme.border,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    game.run.score == 0
                        ? 'ZIPLAMAK İÇİN DOKUN'
                        : 'BİR YÖRÜNGE DAHA.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      letterSpacing: 2.5,
                      color: OrbitTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class GameOverOverlay extends StatefulWidget {
  const GameOverOverlay({super.key, required this.game});
  final OrbitGame game;
  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay> {
  bool _busy = false;
  String? _message;
  OrbitGame get game => widget.game;

  Future<void> _revive() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    await game.audio.suspend();
    final earned = await game.ads.showRewarded();
    if (!mounted) return;
    if (earned) {
      game.revive(earned: true);
    } else {
      setState(() {
        _message =
            'Devam hakkı kazanılmadı. Yeniden deneyebilir veya menüye dönebilirsin.';
      });
    }
    await game.audio.resume();
    if (mounted) {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _menu() async {
    if (_busy) return;
    setState(() {
      _busy = true;
    });
    await game.returnToMenu();
    if (mounted) {
      setState(() {
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => _ModalFrame(
    child: Column(
      children: [
        const Eyebrow('SİNYAL KAYBOLDU', color: OrbitTheme.coral),
        const SizedBox(height: 16),
        Text(
          'GÜZEL\nDENEMEYDİ.',
          textAlign: TextAlign.center,
          style: OrbitTheme.pixel(19),
        ),
        const SizedBox(height: 28),
        Text(
          '${game.run.score}'.padLeft(3, '0'),
          style: OrbitTheme.pixel(44, color: OrbitTheme.mint),
        ),
        const SizedBox(height: 8),
        Text(
          'SKORUN  ·  EN İYİ ${game.best}',
          style: const TextStyle(letterSpacing: 1.5, fontSize: 11),
        ),
        const SizedBox(height: 28),
        if (!game.run.reviveUsed)
          ListenableBuilder(
            listenable: game.ads,
            builder: (context, child) => Column(
              children: [
                FilledButton.icon(
                  onPressed: !_busy && game.ads.rewardedReady ? _revive : null,
                  icon: const Icon(Icons.ondemand_video_outlined),
                  label: Text(_busy ? 'Bekleniyor…' : 'Reklam İzle · Devam Et'),
                ),
                const SizedBox(height: 8),
                Text(
                  game.ads.rewardedReady
                      ? '1 devam hakkı + 2,5 saniye kalkan'
                      : game.ads.rewardedLoading
                      ? 'Reklam hazırlanıyor…'
                      : 'Şu anda ödüllü reklam kullanılamıyor.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
                if (!game.ads.rewardedReady &&
                    !game.ads.rewardedLoading &&
                    game.ads.allowed)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () {
                            game.ads.loadRewarded();
                            setState(() {});
                          },
                    child: const Text('Reklamı yeniden yükle'),
                  ),
              ],
            ),
          ),
        if (game.run.reviveUsed)
          const Text(
            'Bu turdaki devam hakkını kullandın.',
            textAlign: TextAlign.center,
          ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _message!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: OrbitTheme.coral, fontSize: 13),
            ),
          ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _busy ? null : _menu,
          child: const Text('Ana Menüye Dön'),
        ),
      ],
    ),
  );
}

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.game});
  final OrbitGame game;
  @override
  Widget build(BuildContext context) => _ModalFrame(
    child: Column(
      children: [
        const Eyebrow('KISA BİR MOLA'),
        const SizedBox(height: 20),
        Text(
          'YÖRÜNGE\nBEKLİYOR.',
          textAlign: TextAlign.center,
          style: OrbitTheme.pixel(20),
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: game.resumeRun,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Devam Et'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: game.returnToMenu,
          child: const Text('Ana Menüye Dön'),
        ),
      ],
    ),
  );
}

class _ModalFrame extends StatelessWidget {
  const _ModalFrame({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: OrbitTheme.background.withValues(alpha: 0.88),
    child: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: OrbitPanel(child: child),
          ),
        ),
      ),
    ),
  );
}

Future<void> _showSettings(BuildContext context, OrbitGame game) async {
  unawaited(game.audio.play('button'));
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Tercihler'),
        content: SizedBox(
          width: 330,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Azaltılmış hareket'),
                  subtitle: const Text(
                    'Ekran sarsıntısını ve yıldız animasyonunu kapatır.',
                  ),
                  value: game.reducedMotion,
                  onChanged: (value) => setState(() {
                    game.reducedMotion = value;
                  }),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.article_outlined),
                  title: const Text('Gizlilik metni'),
                  onTap: () => showPolicy(context),
                ),
                if (game.consent.privacyOptionsRequired)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Reklam gizlilik tercihleri'),
                    onTap: () async {
                      Navigator.pop(dialogContext);
                      game.ads.clearAds();
                      await game.audio.suspend();
                      await game.consent.showPrivacyOptions();
                      await game.ads.configure(
                        canRequestAds: game.consent.canRequestAds,
                        audienceEligible: game.settings.adsEligible,
                      );
                      await game.audio.resume();
                    },
                  ),
                if (game.consent.supported && !game.ads.allowed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.refresh),
                    title: const Text('Reklam bağlantısını yenile'),
                    onTap: () async {
                      Navigator.pop(dialogContext);
                      await game.consent.gather();
                      await game.ads.configure(
                        canRequestAds: game.consent.canRequestAds,
                        audienceEligible: game.settings.adsEligible,
                      );
                    },
                  ),
                const Divider(),
                const Text(
                  'contact@example.com',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  '${AppConfig.title} · ${AppConfig.version}',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Kapat'),
          ),
        ],
      ),
    ),
  );
}
